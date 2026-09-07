#!/usr/bin/env bash
# Shared provenance check for Stop and SubagentStop (the rigor done-gate).
# `--integration` is a rig-specific preflight that reads files most machines do not have;
# `rigor install` never wires it.
# Tags are data. Never execute a command or open a path supplied in a claim.
set -uo pipefail
CLAIM_GATE_FAMILY=claims
[ "${1:-}" = --integration ] && CLAIM_GATE_FAMILY=integration
if [ -f "$HOME/.claude/state/$CLAIM_GATE_FAMILY-gate.disabled" ]; then
  printf '[%s] global override is set\n' "$CLAIM_GATE_FAMILY" >&2
  exit 0
fi
source "${BASH_SOURCE[0]%/*}/modules/claims-regex.sh" || exit 2
INPUT=$(cat)
INPUT="$INPUT" python3 - "${1:-}" <<'PY'
import hashlib, json, os, re, shlex, sys
from pathlib import Path
from urllib.parse import urlparse, unquote


def deny(reason, family="claims"):
    canon = os.environ.get("RIGOR_CANON", "~/.agents/RIGOR-ALGORITHM.md")
    print(f"[{family}] {reason}\n  → label each inference [inferred], or cite completed tool evidence on the named object\n  Canon: {canon} § Before the word done", file=sys.stderr)
    raise SystemExit(2)


def text(value):
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return "\n".join(text(b.get("text", "")) for b in value if isinstance(b, dict) and b.get("type") in ("text", "Text", "input_text", "output_text"))
    return ""


def decode(value):
    return json.loads(value) if isinstance(value, str) else value


def canonical(value, cwd):
    value = value.strip().strip('`"\'')
    if value.startswith(("https://", "http://")):
        return value.rstrip("/")
    value = value.replace("${HOME}", str(Path.home())).replace("$HOME", str(Path.home()))
    return os.path.normpath(os.path.join(cwd, os.path.expanduser(value)))


def shell_info(command, cwd):
    # ponytail: static shell words only; dynamic/eval/script-body reads require a
    # direct read or an inferred tag. This is not a shell interpreter.
    lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    words = list(lexer)
    objects, reads, inspected = set(), set(), set()
    for group in re.split(r"\x00(?:&&|;|\|\||\|)\x00", "\x00".join(words)):
        args = group.split("\x00")
        while args and args[0] in ("rtk", "proxy", "command"):
            args.pop(0)
        if not args:
            continue
        name = os.path.basename(args[0])
        if name == "ssh" and len(args) >= 3:
            _, remote_objects, _, _ = shell_info(args[-1], cwd)
            objects.update(remote_objects)
        if name in ("docker", "kubectl") and len(args) >= 3 and any(w in args for w in ("inspect", "logs", "exec", "get", "describe")):
            objects.update(w for w in args[2:] if not w.startswith("-") and "/" not in w and " " not in w)
        if name == "git":
            objects.add(cwd)
        if name == "cd" and len(args) == 2:
            cwd = canonical(args[1], cwd)
            continue
        candidates = []
        for word in args[1:]:
            word = word.replace("${HOME}", str(Path.home())).replace("$HOME", str(Path.home()))
            if not word.startswith("-") and (word.startswith(("/", "~", "./", "../")) or "/" in word or re.search(r"\.[A-Za-z0-9]{1,10}$", word)) and not any(c in word for c in "\n\x00$(`"):
                candidates.append(word)
        paths = {canonical(w, cwd) for w in candidates}
        objects.update(paths)
        simple = not any(w in words for w in ("&&", ";", "||", "|", ">", ">>", "<", "<<", "&", "(", ")"))
        if simple and name in ("ls", "stat"):
            inspected.update(paths)
        if simple and (name in ("cat", "read", "head", "tail") or (name == "sed" and not any(w.startswith("-i") for w in args[1:]))):
            reads.update(paths)
    return words, objects, reads, inspected


def normalize(events):
    """Only host event roles confer trust; assistant-pasted tool_result is prose."""
    out = []
    for ev in events:
        e = ev.get("payload", {}) if ev.get("type") in ("response_item", "event_msg") else ev
        typ = e.get("type")
        if ev.get("type") == "event_msg" and typ == "item_completed":
            item = e.get("item") or {}
            if item.get("type") == "UserMessage":
                out.append(("user", text(item.get("content", []))))
            elif item.get("type") == "AgentMessage":
                out.append(("assistant", text(item.get("content", []))))
            elif item.get("type") == "CommandExecution" and item.get("status") in ("completed", "failed") and isinstance(item.get("exit_code"), int):
                argv = item.get("command") or []
                if isinstance(argv, list):
                    command = argv[-1] if len(argv) >= 3 and argv[-2] in ("-c", "-lc", "-ic") else shlex.join(argv)
                else:
                    command = argv
                cwd = item.get("cwd") or os.getcwd()
                if cwd.startswith("file://"):
                    cwd = unquote(urlparse(cwd).path)
                out.append(("call", {"id": item["id"], "name": "exec_command", "input": {"cmd": command, "workdir": cwd}}))
                out.append(("result", {"tool_use_id": item["id"], "content": item.get("aggregated_output", ""), "exit_code": item["exit_code"], "is_error": item["exit_code"] != 0}))
            continue
        if typ == "user_message":
            out.append(("user", text(e.get("message", ""))))
        elif typ in ("function_call", "custom_tool_call"):
            args = e.get("arguments", e.get("input", {}))
            try:
                args = decode(args)
            except (ValueError, TypeError):
                args = {}  # arbitrary functions.exec JavaScript is not executed or guessed
            out.append(("call", {"id": e.get("call_id"), "name": e.get("name", ""), "input": args}))
        elif typ in ("function_call_output", "custom_tool_call_output"):
            out.append(("result", {"tool_use_id": e.get("call_id"), "content": e.get("output", "")}))
        else:
            msg = e.get("message", e)
            role = msg.get("role", typ)
            content = msg.get("content", [])
            # A user image/document also starts a turn. Tool-result envelopes do not.
            tool_results_only = isinstance(content, list) and bool(content) and all(isinstance(b, dict) and b.get("type") == "tool_result" for b in content)
            if role == "user" and not tool_results_only:
                out.append(("user", text(content)))
            if role == "assistant":
                for b in content if isinstance(content, list) else []:
                    if isinstance(b, dict) and b.get("type") == "tool_use":
                        out.append(("call", b))
                if text(content).strip():
                    out.append(("assistant", text(content)))
            if role in ("user", "tool"):
                for b in content if isinstance(content, list) else []:
                    if isinstance(b, dict) and b.get("type") == "tool_result":
                        out.append(("result", b))
    start = max((i for i, (kind, _) in enumerate(out) if kind == "user"), default=-1)
    return out[start:] if start >= 0 else out


def receipts(turn, cwd):
    pending, completed, opened, inspected = {}, [], set(), set()
    for kind, item in turn:
        if kind == "call" and item.get("id"):
            pending[item["id"]] = item
        if kind != "result" or item.get("tool_use_id") not in pending:
            continue
        call = pending.pop(item["tool_use_id"])
        args = call.get("input") or {}
        if not isinstance(args, dict):
            continue
        body = item.get("content", "")
        try:
            structured = decode(body)
        except (ValueError, TypeError):
            structured = {}
        if not isinstance(structured, dict):
            structured = {}
        output = text(body) or text(structured.get("output", ""))
        code = item.get("exit_code", structured.get("exit_code"))
        marker = re.search(r"(?:Process exited with code|[Ee]xit[_ ]code[: ]+)\s*(-?\d+)", output)
        if code is None and marker:
            code = int(marker.group(1))
        failed = item.get("is_error", False) or structured.get("isError", False)
        running = args.get("run_in_background") or structured.get("session_id") or re.search(r"^(?:(?:Script|Process) running with (?:cell ID|session[_ ]id)|Command running in background with ID:)", output, re.I | re.M)
        if code is None and not failed:
            code = 0  # Claude tool_result completion without is_error means success
        if running:
            code = None
        name = call.get("name", "").split(".")[-1]
        workdir = args.get("workdir", args.get("cwd", cwd))
        if name in ("Read", "read_file", "WebFetch", "read_url") and code == 0 and not failed:
            path = args.get("file_path", args.get("path", args.get("url", "")))
            if path:
                opened.add(canonical(path, workdir))
        command = args.get("command", args.get("cmd"))
        if name not in ("Bash", "exec_command", "run_terminal_command") or not isinstance(command, str):
            continue
        try:
            words, objects, reads, dirs = shell_info(command, workdir)
        except ValueError:
            continue  # unknown shell syntax is not a receipt; inferred stays available
        completed.append((words, code, objects, failed, output))
        if code == 0 and not failed:
            opened.update(reads)
            inspected.update(dirs)
    return completed, opened, inspected


def override(family, turn, data):
    state = Path.home() / ".claude/state"
    sid = hashlib.sha256(str(data.get("session_id", "")).encode()).hexdigest()[:24]
    muted = state / family / (sid + ".muted")
    user = "\n".join(value for kind, value in turn if kind == "user")
    if re.search(rf"(?m)^\s*{family}: mute\s*$", user):
        muted.parent.mkdir(parents=True, exist_ok=True)
        muted.touch()
    return (state / (family + "-gate.disabled")).exists() or muted.exists() or bool(re.search(rf"(?m)^\s*{family}: ignore\s*$", user))


PROVIDERS = {
    ".gemini": ("gemini", ("geminicli.com",)),
    ".grok": ("grok", ("docs.x.ai",)),
    ".kimi-code": ("kimi", ("kimi.com", "moonshotai.github.io")),
    ".codex": ("codex", ("developers.openai.com", "platform.openai.com")),
    ".claude.json": ("claude", ("code.claude.com", "docs.anthropic.com")),
    ".config/mcp-brain-router": ("brain-router", ()),
}


def provider_for(path):
    path = str(Path(path).resolve())
    for suffix, value in PROVIDERS.items():
        root = str((Path.home() / suffix).resolve())
        if path == root or (suffix != ".claude.json" and path.startswith(root + "/")):
            return root, value
    return None


def integration_targets(data):
    args = data.get("tool_input") or {}
    cwd = data.get("cwd") or os.getcwd()
    target = args.get("file_path", args.get("notebook_path", ""))
    if target:
        targets = {str(Path(canonical(target, cwd)).resolve())}
    elif data.get("tool_name") == "Bash":
        command = args.get("command", args.get("cmd", ""))
        try:
            words, objects, _, _ = shell_info(command, cwd)
        except ValueError:
            words, objects = [], set()
        plain = [w for w in words if w not in ("rtk", "proxy", "command")]
        readers = ("ls", "cat", "read", "head", "tail", "stat", "rg", "grep", "wc", "sed")
        readonly = plain and os.path.basename(plain[0]) in readers and not any(w in words for w in (">", ">>", ";", "&&", "|", "||")) and not any(w.startswith("-i") for w in words)
        if readonly:
            return []
        # Literal references also cover Python/JS bodies that assemble a path.
        # Arbitrary scripts concealing all target names need host file enforcement.
        targets = {str(Path.home() / suffix) for suffix in PROVIDERS if suffix in command}
        targets.update(str(Path(p).resolve()) for p in objects if not p.startswith("http"))
        targets.add(cwd)
    else:
        return []
    return sorted({provider_for(p)[0] for p in targets if provider_for(p)})


def integration(data, targets, turn, opened, inspected):
    if override("integration", turn, data):
        return
    lookup = str((Path.home() / ".agents/golden-rules/INTEGRATIONS-LOOKUP.md").resolve())
    opened = {p if p.startswith("http") else str(Path(p).resolve()) for p in opened}
    inspected = {p if p.startswith("http") else str(Path(p).resolve()) for p in inspected}
    for root in targets:
        _, (name, domains) = provider_for(root)
        missing = []
        if lookup not in opened:
            missing.append("INTEGRATIONS-LOOKUP.md")
        if not any(p == root or p.startswith(root + "/") or (p.startswith("https://") and urlparse(p).hostname in domains) for p in opened | inspected):
            missing.append(f"{name} current docs or config directory {root}")
        if missing:
            print(f"[integration] missing current-turn read: {'; '.join(missing)}\n  → read the named sources, then retry; override: integration: ignore / integration: mute / ~/.claude/state/integration-gate.disabled", file=sys.stderr)
            raise SystemExit(2)


def explicit_objects(prose, cwd):
    quoted = re.findall(r"`([^`]+)`|<([^>]+)>", prose)
    paths = [a or b for a, b in quoted if "/" in (a or b)]
    unquoted = re.sub(r"`[^`]+`|<[^>]+>", "", prose)
    paths += re.findall(r"(?<![\w./-])(?:https?://|~?/|\.\.?/|[\w.-]+/)[^\s`\"'<>|]*", unquoted)
    return {canonical(p.rstrip('.,;:!?()[]'), cwd) for p in paths}


def mentioned(obj, prose, cwd):
    explicit = explicit_objects(prose, cwd)
    if explicit:
        return obj in explicit
    for suffix, (name, _) in PROVIDERS.items():
        if re.search(r"(?<![\w-])" + re.escape(name) + r"(?![\w-])", prose, re.I):
            expected = str(Path.home() / suffix)
            if not (obj == expected or obj.startswith(expected + "/")):
                return False
    names = [obj, os.path.relpath(obj, cwd) if not obj.startswith("http") else obj, os.path.basename(obj)]
    return any(len(n) > 1 and re.search(r"(?<![\w./-])" + re.escape(n.rstrip("/")) + r"(?![\w.-])", prose) for n in names)


def check_claims(message, completed, opened, cwd):
    claim = re.compile(os.environ["CLAIMS_CLAIM_RE"], re.I)
    # Protect tags before splitting sentences, so dots in paths/commands are inert.
    tag = re.compile(r"\[(?:opened:[^\]\n]+|ran:[^\n]+? exit -?\d+|inferred)\]|`(?:opened:[^`\n]+|ran:[^`\n]+? exit -?\d+|inferred)`|(?<![\w])(?:opened:\S+|ran:[^\n]+? exit -?\d+|inferred)(?![\w])")
    message = re.sub(r"```.*?```|~~~.*?~~~", "", message, flags=re.S)
    for line in message.splitlines():
        if line.lstrip().startswith(">"):
            continue
        marker = "_CLAIM_TAG_"
        while marker in line:
            marker += "_"
        token = re.escape(marker) + r"(\d+)"
        tags = []
        def keep(match):
            raw = match.group()
            value = raw.strip("[]`") if raw.startswith(("[", "`")) else raw.rstrip(".,;!?")
            suffix = "" if raw.startswith(("[", "`")) else raw[len(value):]
            tags.append(value)
            return f" {marker}{len(tags)-1} {suffix}"
        protected = tag.sub(keep, line)
        for sentence in re.split(r"(?<=[.!?;])[*_`\"')\]]*(?:\s+|(?=[A-Z]))", protected):
            indexes = [int(i) for i in re.findall(token, sentence)]
            prose = re.sub(token, "", sentence).strip()
            hits = list(claim.finditer(prose))
            if not hits:
                continue
            if any(tags[i] == "inferred" for i in indexes):
                continue
            if not indexes:
                deny("material claim has no provenance tag: " + prose[:140])
            covered = set()
            deploy = any(hit.lastgroup == "deploy" for hit in hits)
            for i in indexes:
                value = tags[i]
                if value.startswith("opened:"):
                    obj = canonical(value[7:], cwd)
                    if deploy:
                        deny("deployment requires a ran receipt from the served-artifact check")
                    if obj not in opened or not mentioned(obj, prose, cwd):
                        deny("opened tag lacks a completed read on the claim's object: " + value[7:])
                    covered.add(obj)
                elif value.startswith("ran:"):
                    command, code = value[4:].rsplit(" exit ", 1)
                    words, _, _, _ = shell_info(command, cwd)
                    matches = [(objects, output) for w, c, objects, failed, output in completed if words == w and int(code) == c and (not failed or c != 0) and any(mentioned(o, prose, cwd) for o in objects)]
                    if not matches:
                        deny("ran tag lacks a matching completed command, exit status, or claim object")
                    if deploy and not any(re.search(os.environ["CLAIMS_EVIDENCE_RE"], output, re.I) for _, output in matches):
                        deny("deployment receipt has no served-artifact proof from the matching tool result")
                    for objects, _ in matches:
                        covered.update(objects)
            if not explicit_objects(prose, cwd) <= covered:
                deny("each named object needs its own matching provenance receipt")



try:
    data = json.loads(os.environ.get("INPUT") or "{}")
    family = "integration" if sys.argv[1] == "--integration" else "claims"
    if override(family, [], data):
        raise SystemExit(0)
    targets = integration_targets(data) if sys.argv[1] == "--integration" else []
    if sys.argv[1] == "--integration" and not targets:
        raise SystemExit(0)
    subagent = data.get("hook_event_name") == "SubagentStop"
    path = data.get("agent_transcript_path" if subagent else "transcript_path", "")
    events = []
    if path:
        with open(path) as f:
            events = [json.loads(line) for line in f if line.strip()]
    turn = normalize(events)
    cwd = data.get("cwd") or os.getcwd()
    completed, opened, inspected = receipts(turn, cwd)
    if sys.argv[1] == "--integration":
        integration(data, targets, turn, opened, inspected)
    elif not override("claims", turn, data):
        message = data.get("last_assistant_message")
        if message is None:
            message = next((value for kind, value in reversed(turn) if kind == "assistant"), "")
        check_claims(message, completed, opened, cwd)
except (OSError, ValueError, TypeError, KeyError) as exc:
    deny("cannot inspect provenance: " + str(exc), "integration" if sys.argv[1] == "--integration" else "claims")
PY
