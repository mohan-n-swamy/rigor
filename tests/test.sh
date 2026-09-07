#!/usr/bin/env bash
# End-to-end test in a throwaway HOME. Never touches the real ~/.claude.
# Every assertion here is one of the FLAWLESS facts in .rigor.md.
set -uo pipefail
PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
export HOME="$T"
fail=0
ok()   { echo "PASS $1"; }
bad()  { echo "FAIL $1"; fail=1; }
check() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

# --- private-content sweep over the package tree -------------------------------
if /usr/bin/grep -rEn '/Users/[a-z]+|Orange Health|Kamakshi|91886|sk-[A-Za-z0-9]{10,}|ghp_[A-Za-z0-9]{10,}' "$PKG" --exclude-dir=.git --exclude-dir=dist --exclude=.rigor.md --exclude=test.sh >/dev/null; then
  bad "no private paths, names or keys in the tree"
else
  ok "no private paths, names or keys in the tree"
fi
check "PONYTAIL.md carries the MIT attribution" "grep -q DietrichGebert '$PKG/canon/PONYTAIL.md'"
check "done-gate points at the shipped canon, not a private doctrine" "! grep -q EVIDENCE-DOCTRINE '$PKG/hooks/evidence-gate.sh'"
check "hooks do not depend on rig dispatchers" "! grep -qE 'voice\(|HOOKS_DIR|_wrappers' '$PKG'/hooks/*.sh"
check "claims-regex shebang is portable" "head -1 '$PKG/hooks/modules/claims-regex.sh' | grep -q '/usr/bin/env bash'"

# --- install into a HOME that already has settings and a foreign hook -----------
mkdir -p "$T/.claude"
printf '{"permissions":{"allow":["Bash(ls:*)"]},"hooks":{"Stop":[{"matcher":"*","hooks":[{"type":"command","command":"echo foreign"}]}]}}\n' > "$T/.claude/settings.json"
printf '# my rules\n' > "$T/.claude/CLAUDE.md"
python3 -c 'import json,sys;print(json.dumps(json.load(open(sys.argv[1])),sort_keys=True))' "$T/.claude/settings.json" > "$T/before.json"

check "rigor install exits 0" "bash '$PKG/bin/rigor' install"
check "settings.json still parses" "python3 -m json.tool '$T/.claude/settings.json'"
check "three rigor hook commands wired" "[ \"\$(grep -c 'hooks/rigor/' '$T/.claude/settings.json')\" = 3 ]"
check "PreToolUse matcher is the edit tools" "grep -q 'Write|Edit|MultiEdit|NotebookEdit' '$T/.claude/settings.json'"
check "foreign hook survived install" "grep -q 'echo foreign' '$T/.claude/settings.json'"
check "foreign permissions survived install" "grep -q 'Bash(ls:\*)' '$T/.claude/settings.json'"
check "no --integration mode wired" "! grep -q -- '--integration' '$T/.claude/settings.json'"
check "CLAUDE.md block present once" "[ \"\$(grep -c 'rigor:begin' '$T/.claude/CLAUDE.md')\" = 1 ]"
check "CLAUDE.md imports ponytail" "grep -q '@~/.agents/PONYTAIL.md' '$T/.claude/CLAUDE.md'"
check "second install is idempotent (still 3 commands)" "bash '$PKG/bin/rigor' install >/dev/null && [ \"\$(grep -c 'hooks/rigor/' '$T/.claude/settings.json')\" = 3 ]"
check "second install keeps one CLAUDE.md block" "[ \"\$(grep -c 'rigor:begin' '$T/.claude/CLAUDE.md')\" = 1 ]"
st="$(bash "$PKG/bin/rigor" self-test 2>&1)"
check "self-test passes on the installed gate" "printf '%s' \"\$st\" | grep -q 'PASS red: bare template rejected' && ! printf '%s' \"\$st\" | grep -q FAIL"

# --- pre-work gate: blocks the third file, allows with a valid .rigor.md ---------
G="$T/.claude/hooks/rigor/rigor-gate.sh"; W="$T/work"; mkdir -p "$W"
ev() { printf '{"session_id":"t1","tool_input":{"file_path":"%s","content":"%s"}}' "$1" "$2"; }
ev "$W/a.py" "x" | bash "$G" >/dev/null 2>&1; r1=$?
ev "$W/b.py" "x" | bash "$G" >/dev/null 2>&1; r2=$?
ev "$W/c.py" "x" | bash "$G" >/dev/null 2>&1; r3=$?
check "files 1 and 2 allowed, file 3 blocked (exit 2)" "[ $r1 = 0 ] && [ $r2 = 0 ] && [ $r3 = 2 ]"
check "'rigor: small' bypasses the block" "ev '$W/d.py' 'rigor: small' | bash '$G'"
check "bare template fails validate" "! bash '$PKG/bin/rigor' validate '$PKG/templates/rigor.md'"
sed -n '/cat > "\$tmp\/good.md" <<'"'"'EOF'"'"'/,/^EOF$/p' "$G" | sed '1d;$d' > "$W/.rigor.md"
check "sample .rigor.md passes validate" "bash '$PKG/bin/rigor' validate '$W/.rigor.md'"
check "third file allowed once .rigor.md exists above it" "ev '$W/e.py' 'x' | bash '$G'"
check "--ask nags on a big request" "printf '{\"prompt\":\"rebuild the whole dashboard from scratch\"}' | bash '$G' --ask | grep -q 'RIGOR CHECK'"
check "--ask silent on a small request" "[ -z \"\$(printf '{\"prompt\":\"fix the typo\"}' | bash '$G' --ask)\" ]"

# --- done-gate: denies an untagged claim, allows a tagged one --------------------
E="$T/.claude/hooks/rigor/evidence-gate.sh"; TR="$T/transcript.jsonl"
printf '%s\n' '{"type":"user","message":{"role":"user","content":"is it done?"}}' > "$TR"
stop() { printf '{"session_id":"t1","transcript_path":"%s","cwd":"%s","last_assistant_message":"%s"}' "$TR" "$T" "$1" | bash "$E" >/dev/null 2>&1; }
stop "Done. The tests pass and the fix is deployed."; r=$?
check "untagged 'done' with no evidence is denied (exit 2)" "[ $r = 2 ]"
check "[inferred] claim passes" "stop '[inferred] the tests probably pass; I did not run them.'"
check "a question with no claim passes" "stop 'Which option do you want?'"

# --- uninstall restores the foreign settings exactly -----------------------------
check "rigor uninstall exits 0" "bash '$PKG/bin/rigor' uninstall"
python3 -c 'import json,sys;print(json.dumps(json.load(open(sys.argv[1])),sort_keys=True))' "$T/.claude/settings.json" > "$T/after.json"
check "settings.json identical to before install" "cmp -s '$T/before.json' '$T/after.json'"
check "CLAUDE.md block removed, user text kept" "! grep -q rigor:begin '$T/.claude/CLAUDE.md' && grep -q 'my rules' '$T/.claude/CLAUDE.md'"
check "hook files removed" "[ ! -d '$T/.claude/hooks/rigor' ] && [ ! -f '$T/.agents/RIGOR-ALGORITHM.md' ]"

# --- python3 missing: install refuses with exit 1 -------------------------------
P="$T/nobin"; mkdir -p "$P"
for b in bash cp mkdir chmod grep sed cat touch rm dirname; do ln -sf "$(command -v $b)" "$P/$b"; done
check "install exits 1 without python3" "! PATH='$P' bash '$PKG/bin/rigor' install && [ \$(PATH='$P' bash '$PKG/bin/rigor' install >/dev/null 2>&1; echo \$?) = 1 ]"

rm -rf "$T"
[ $fail = 0 ] && echo "ALL PASS" || { echo "SOME FAIL"; exit 1; }
