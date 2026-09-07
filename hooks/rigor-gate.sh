#!/usr/bin/env bash
# rigor-gate.sh — the PRE-work half of the Rigor Algorithm.
# Authority: ~/.agents/RIGOR-ALGORITHM.md  (do not restate it here)
#
# evidence-gate.sh (Stop) catches a completion claim with no check behind it.
# That is the END. It cannot help a job that started with no target, because by
# then the target has already been written to fit whatever was built.
# This is the START: once a change is demonstrably big, question zero and the six
# answers must exist in writing before the next edit.
#
# "Big enough" — canonical list is in RIGOR-ALGORITHM.md. The mechanical proxy
# enforced here is the THIRD distinct non-scratch file edited in a session.
#
# Modes:
#   (default)     PreToolUse on Write|Edit|MultiEdit|NotebookEdit — block or allow
#   --ask         UserPromptSubmit — inject "ask before starting" on a big-looking request
#   --validate F  schema-check one .rigor.md, exit 0/1
#   --self-test   prove the gate can fail AND can pass
set -uo pipefail

CANON="$HOME/.agents/RIGOR-ALGORITHM.md"
TEMPLATE="${RIGOR_TEMPLATE:-$HOME/.claude/templates/rigor.md}"
STATE_DIR="$HOME/.claude/state/rigor"
THRESHOLD="${RIGOR_FILE_THRESHOLD:-3}"

# A user can mute this session with a standalone `rigor: mute session` line.
# Tool results in user envelopes are not user instructions. Hash the SID so it
# cannot select a state path outside this gate's directory.
session_muted() {
  RIGOR_OVERRIDE_STATE="$STATE_DIR" python3 -c '
import hashlib, json, os, pathlib, sys
try:
    data = json.load(sys.stdin)
except (ValueError, TypeError):
    sys.exit(1)
if not isinstance(data, dict):
    sys.exit(1)
sid = data.get("session_id")
if not isinstance(sid, str) or not sid:
    sys.exit(1)
flag = pathlib.Path(os.environ["RIGOR_OVERRIDE_STATE"], hashlib.sha256(sid.encode()).hexdigest() + ".muted")
if flag.is_file():
    sys.exit(0)

def requested(content):
    if isinstance(content, list):
        content = "\n".join(block.get("text", "") for block in content
                            if isinstance(block, dict) and block.get("type") in ("text", "input_text")
                            and isinstance(block.get("text"), str))
    return isinstance(content, str) and any(line.strip() == "rigor: mute session" for line in content.splitlines())

mute = requested(data.get("prompt", ""))
try:
    with open(data.get("transcript_path", ""), errors="replace") as transcript:
        for line in transcript:
            if "rigor: mute session" not in line:
                continue
            try:
                event = json.loads(line)
            except ValueError:
                continue
            if not isinstance(event, dict):
                continue
            message = event.get("message", {}) if event.get("type") == "user" else event.get("payload", {})
            if not isinstance(message, dict):
                continue
            if event.get("type") == "user" or (event.get("type") == "response_item" and message.get("role") == "user"):
                mute = mute or requested(message.get("content", ""))
except (OSError, TypeError):
    pass
if not mute:
    sys.exit(1)
flag.parent.mkdir(parents=True, exist_ok=True)
flag.write_text("rigor: mute session\n")
'
}

# ---------------------------------------------------------------- validate ----
# A .rigor.md counts only if question zero and all six answers are answered. An empty
# heading is a syntax error here, not a judgement call — that is rung 1
# (template) doing the work instead of my good intentions.
validate() {
  local f="$1" errs=0
  [ -f "$f" ] || { echo "no such file: $f"; return 1; }
  local body; body=$(cat "$f")
  local h
  for h in "0. Existing source and actionable addition" \
           "1. Objective, then flawless" "2. Must / must not" \
           "3. Known failure modes" "4. Micro checklist" \
           "5. What makes a failed check impossible to miss" "6. Sequencing"; do
    printf '%s' "$body" | grep -qF "$h" || { echo "missing section: $h"; errs=1; }
  done
  # Unreplaced template placeholders mean the questions were skimmed, not answered.
  # Strip inline code spans first: `bash -n <file>` is a command argument, not an
  # unanswered question. Found by this validator rejecting its own author's file.
  local prose; prose=$(printf '%s' "$body" | sed 's/`[^`]*`//g')
  if printf '%s' "$prose" | grep -qE '<[a-z][^>]*>'; then
    echo "unreplaced <placeholder> left in the file"; errs=1
  fi
  # Q0 names what already supplies the result and the addition someone will use.
  # This checks a named path/URL and populated answer, not source existence or utility.
  local q0 source addition answer
  q0=$(printf '%s' "$body" | sed -n '/^## 0\./,/^## 1\./p')
  source=$(printf '%s' "$q0" | sed -n 's/^EXISTING SOURCE:[[:space:]]*//p' | tr -d '`')
  addition=$(printf '%s' "$q0" | sed -n 's/^ACTIONABLE ADDITION:[[:space:]]*//p' | tr -d '`')
  printf '%s\n' "$source" | grep -qE '(^|[[:space:]])(https?://[^[:space:]<>]+|(~?/|[[:alnum:]_.-]+/)[^[:space:]<>]+|[[:alnum:]_.-]+\.[[:alnum:]_.-]+)($|[[:space:]])' \
    || { echo "section 0 must name an EXISTING SOURCE path or URL"; errs=1; }
  for answer in "$source" "$addition"; do
    if ! printf '%s\n' "$answer" | grep -q '[[:alnum:]]' ||
       printf '%s\n' "$answer" | grep -qiE '^[[:space:]*_]*(tbd|todo|none|n/?a|placeholder|to be (determined|filled|added))[[:space:]*_.-]*$|<[^>]*>'; then
      echo "section 0 needs an answered EXISTING SOURCE and ACTIONABLE ADDITION, not placeholders"; errs=1
    fi
  done
  # Q2's must-not list is the one everybody omits. Demand it explicitly.
  local mn; mn=$(printf '%s' "$body" | sed -n '/MUST NOT/,/^## 3\./p')
  printf '%s' "$mn" | grep -qE '^[-*|] *\S' \
    || { echo "MUST NOT list is empty — that list is the whole trick"; errs=1; }
  # Every must-not row must carry its check. A row with no check is an intention,
  # and an unguarded summary always deletes the expensive intentions first — which
  # is how 26 reader conditions became 9 on 2026-09-01.
  local rows unchecked
  rows=$(printf '%s' "$mn" | grep -cE '^\| *(¬|not-)?R?[0-9]' || true)
  if [ "${rows:-0}" -gt 0 ]; then
    unchecked=$(printf '%s' "$mn" | grep -E '^\| *(¬|not-)?R?[0-9]' | grep -vc '`' || true)
    [ "${unchecked:-0}" -gt 0 ] && {
      echo "$unchecked must-not rows carry no check in backticks — mark them UNRUN or HUMAN, never drop them"; errs=1; }
  fi
  # Q1 and Q4 must carry commands, or they are intentions.
  local q1; q1=$(printf '%s' "$body" | sed -n '/^## 1\./,/^## 2\./p')
  printf '%s' "$q1" | grep -q 'OBJECTIVE:' \
    || { echo "section 1 states no OBJECTIVE — flawless cannot be defined before what the task is for"; errs=1; }
  printf '%s' "$q1" | grep -qE 'OBJECTIVE:[[:space:]]*\S' \
    || { echo "OBJECTIVE: is empty"; errs=1; }
  printf '%s' "$q1" | grep -q 'FLAWLESS' \
    || { echo "section 1 has no FLAWLESS block measured against the objective"; errs=1; }
  printf '%s' "$q1" | grep -q '`' \
    || { echo "section 1 has no check in backticks — a fact a stranger cannot check is not a fact"; errs=1; }
  printf '%s' "$body" | sed -n '/4\. Micro checklist/,/^## 5\./p' | grep -q '`' \
    || { echo "section 4 has no runnable check"; errs=1; }
  return $errs
}

# ------------------------------------------------------------- self-test ------
# A gate that has never been seen to fail is not known to be a gate.
self_test() {
  local tmp; tmp=$(mktemp -d)
  local rc=0
  cp "$TEMPLATE" "$tmp/.rigor.md" || { rm -rf "$tmp"; return 1; }
  if validate "$tmp/.rigor.md" >/dev/null 2>&1; then
    echo "FAIL: bare template validated — the gate cannot fail"; rc=1
  else
    echo "PASS red: bare template rejected"
  fi
  cat > "$tmp/good.md" <<'EOF'
# Rigor — sample
## 0. Existing source and actionable addition
EXISTING SOURCE: `~/.claude/hooks/rigor-gate.sh` already validates written plans.
ACTIONABLE ADDITION: reject missing source answers so the implementer reviews existing capability before editing.
## 1. Objective, then flawless
OBJECTIVE: prove the gate works so a big change cannot start ungoverned.
FLAWLESS:
- the file exists — `test -f /etc/hosts`
## 2. Must / must not
MUST:
- do the thing
MUST NOT:
- invent data
## 3. Known failure modes and their prevention
| a | b | c |
## 4. Micro checklist — called at each step
- [ ] it parses — `bash -n script.sh`
## 5. What makes a failed check impossible to miss
| x | y | gate |
## 6. Sequencing
MICRO: parse. ASSEMBLY: run.
EOF
  if validate "$tmp/good.md" >/dev/null 2>&1; then
    echo "PASS green: a complete file is accepted"
  else
    echo "FAIL: a complete file was rejected"; validate "$tmp/good.md"; rc=1
  fi
  sed 's|~/.claude/hooks/rigor-gate.sh|https://turiya.beehiiv.com/p/rigor-as-an-algorithm|' "$tmp/good.md" > "$tmp/url.md"
  if validate "$tmp/url.md" >/dev/null 2>&1; then
    echo "PASS green: a URL source is accepted"
  else
    echo "FAIL: a URL source was rejected"; validate "$tmp/url.md"; rc=1
  fi
  sed '/^## 0\./,/^## 1\./{ /^## 1\./!d; }' "$tmp/good.md" > "$tmp/nozero.md"
  sed 's/^EXISTING SOURCE:.*/EXISTING SOURCE:/' "$tmp/good.md" > "$tmp/emptysource.md"
  sed 's/^EXISTING SOURCE:.*/EXISTING SOURCE: TBD/' "$tmp/good.md" > "$tmp/placeholdersource.md"
  sed 's/^EXISTING SOURCE:.*/EXISTING SOURCE: `<existing\/source>`/' "$tmp/good.md" > "$tmp/codesource.md"
  sed 's/^ACTIONABLE ADDITION:.*/ACTIONABLE ADDITION:/' "$tmp/good.md" > "$tmp/emptyaddition.md"
  sed 's/^ACTIONABLE ADDITION:.*/ACTIONABLE ADDITION: TODO/' "$tmp/good.md" > "$tmp/placeholderaddition.md"
  local bad
  for bad in nozero emptysource placeholdersource codesource emptyaddition placeholderaddition; do
    if validate "$tmp/$bad.md" >/dev/null 2>&1; then
      echo "FAIL: $bad slipped through"; rc=1
    else
      echo "PASS red: $bad rejected"
    fi
  done
  # A file that answers everything EXCEPT must-not must still be rejected.
  sed '/^- invent data$/d' "$tmp/good.md" > "$tmp/nomustnot.md"
  if validate "$tmp/nomustnot.md" >/dev/null 2>&1; then
    echo "FAIL: missing MUST NOT list slipped through"; rc=1
  else
    echo "PASS red: missing MUST NOT list rejected"
  fi
  # Override tests stay in scratch; no HOME reassignment or live mute flags.
  local STATE_DIR="$tmp/state"
  printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","content":"rigor: mute session"}]}}' > "$tmp/tool-result.jsonl"
  if printf '{"session_id":"test-mute","transcript_path":"%s"}' "$tmp/tool-result.jsonl" | session_muted; then
    echo "FAIL: tool result muted the session"; rc=1
  else
    echo "PASS red: tool-result override ignored"
  fi
  if printf '%s' '{"session_id":"test-mute","prompt":"rigor: mute session"}' | session_muted &&
     printf '%s' '{"session_id":"test-mute"}' | session_muted; then
    echo "PASS green: user mute persists for its session"
  else
    echo "FAIL: user session mute was not persisted"; rc=1
  fi
  if printf '%s' '{"session_id":"other-session"}' | session_muted; then
    echo "FAIL: mute leaked into another session"; rc=1
  else
    echo "PASS red: mute does not cross sessions"
  fi
  printf '%s\n' '["rigor: mute session"]' '{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"rigor: mute session"}]}}' > "$tmp/user.jsonl"
  if printf '{"session_id":"transcript-mute","transcript_path":"%s"}' "$tmp/user.jsonl" | session_muted; then
    echo "PASS green: user transcript mute survives malformed records"
  else
    echo "FAIL: user transcript mute was ignored"; rc=1
  fi
  rm -rf "$tmp"
  return $rc
}

case "${1:-}" in
  --validate) shift; validate "${1:-}"; exit $? ;;
  --self-test) self_test; exit $? ;;
esac

mkdir -p "$STATE_DIR"
INPUT=$(cat 2>/dev/null || echo '{}')
[ -n "${RIGOR_GATE_OFF:-}" ] && exit 0
[ -f "$HOME/.claude/state/rigor-gate.disabled" ] && exit 0
printf '%s' "$INPUT" | session_muted && exit 0

# ------------------------------------------------------------------ --ask -----
# UserPromptSubmit: when the request itself reads big, put the question in front
# of me BEFORE the first edit. The default behaviour is to ask; the file-count
# block below is only the backstop for when I don't.
if [ "${1:-}" = "--ask" ]; then
  PROMPT=$(printf '%s' "$INPUT" | python3 -c \
    "import json,sys; print(json.load(sys.stdin).get('prompt',''))" 2>/dev/null || echo "")
  [ -z "$PROMPT" ] && exit 0
  printf '%s' "$PROMPT" | grep -qiE '\b(build|implement|rebuild|redesign|refactor|migrat|rewrite|overhaul|ship|deploy|launch|create (a|the) (new )?(app|service|page|dashboard|manual|report|pipeline)|end.to.end|from scratch|whole|entire|all (the )?(pages|screens|files|services))\b' || exit 0
  cat <<'MSG'
{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"RIGOR CHECK — this request reads big enough for the rigor protocol (~/.agents/RIGOR-ALGORITHM.md). Default behaviour: do NOT start editing. Say that it looks big enough, ask whether to run the protocol, and if yes write question zero and the six answers to .rigor.md via the /rigor skill BEFORE the first edit. If it is genuinely small, say so in one line and proceed."}}
MSG
  exit 0
fi

# ------------------------------------------------- PreToolUse: the backstop ---
FILE=$(printf '%s' "$INPUT" | python3 -c \
  "import json,sys; d=json.load(sys.stdin).get('tool_input',{}) or {}; print(d.get('file_path') or d.get('notebook_path') or '')" 2>/dev/null || echo "")
SID=$(printf '%s' "$INPUT" | python3 -c \
  "import json,sys; print(json.load(sys.stdin).get('session_id','nosession'))" 2>/dev/null || echo nosession)
CONTENT=$(printf '%s' "$INPUT" | python3 -c \
  "import json,sys; d=json.load(sys.stdin).get('tool_input',{}) or {}; print((d.get('content') or '')+(d.get('new_string') or ''))" 2>/dev/null || echo "")
[ -z "$FILE" ] && exit 0

# Declared-small bypass. Literal, and it lands in the transcript where you can see it.
printf '%s' "$CONTENT" | grep -qF 'rigor: small' && exit 0

# Scratch, session bookkeeping and the .rigor.md itself are not the work.
case "$FILE" in
  */.rigor.md|*/rigor.md) exit 0 ;;
  */scratchpad/*|/private/tmp/*|/tmp/*|*/.session/*|"$HOME"/.claude/state/*|*/memory/*|*/MEMORY.md) exit 0 ;;
esac

SEEN="$STATE_DIR/$SID.files"
touch "$SEEN"
grep -qxF "$FILE" "$SEEN" 2>/dev/null || echo "$FILE" >> "$SEEN"
COUNT=$(wc -l < "$SEEN" | tr -d ' ')
[ "$COUNT" -lt "$THRESHOLD" ] && exit 0

# Big by the first test in the canon. Is there a .rigor.md above this file?
DIR=$(dirname "$FILE")
FOUND=""
while [ "$DIR" != "/" ] && [ "$DIR" != "$HOME" ] && [ -n "$DIR" ]; do
  if [ -f "$DIR/.rigor.md" ]; then FOUND="$DIR/.rigor.md"; break; fi
  DIR=$(dirname "$DIR")
done
[ -z "$FOUND" ] && [ -f "$HOME/.rigor.md" ] && FOUND="$HOME/.rigor.md"

if [ -n "$FOUND" ]; then
  if PROBLEMS=$(validate "$FOUND" 2>&1); then exit 0; fi
  {
    echo "RIGOR GATE — $FOUND exists but does not answer question zero and the six questions:"
    echo "$PROBLEMS" | sed 's/^/  - /'
    echo
    echo "Fix those answers before the next edit. The authority is $CANON."
  } >&2
  exit 2
fi

{
  echo "RIGOR GATE — this change has now touched $COUNT distinct files. That is big by the"
  echo "first test in the canon, and there are no written answers anywhere above:"
  echo "  $FILE"
  echo
  echo "Rigor is not care or thoroughness. It is the answers, in writing, before the work,"
  echo "run during it. The authority is $CANON — open it, do not recall it."
  echo
  sed -n '/^## THE SIX QUESTIONS/,/^## Before the word/p' "$CANON" 2>/dev/null | sed '$d'
  echo "Do one of exactly two things:"
  echo
  echo "  A. WRITE THE ANSWERS. Copy $TEMPLATE to a .rigor.md beside the work"
  echo "     (repo root or the feature directory) and answer question zero plus all six. The /rigor skill"
  echo "     does this. Section 2's MUST NOT list is the one that will be missing."
  echo
  echo "  B. DECLARE IT SMALL. If this genuinely is not a big change, put the literal"
  echo "     string 'rigor: small' in the content you are writing. It shows in the"
  echo "     transcript, so the declaration is visible rather than silent."
  echo
  echo "User override: a standalone 'rigor: mute session' line mutes this session."
  echo "Global override: touch ~/.claude/state/rigor-gate.disabled (remove to re-enable)."
} >&2
exit 2
