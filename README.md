# rigor

Six answers before the work. Evidence before the word "done". A gate for each, wired into Claude Code with one command.

Rigor is not care, thoroughness or attention. Nobody can pass those and nobody can fail them. Rigor is a written method: what the task is for, what flawless looks like, what it must and must not do, which failures you already know, the checklist you call at each step, and how a failed check becomes impossible to miss. Answered before the first edit, run during the work, checkable by anyone. The article: [Rigor as an Algorithm](https://turiya.beehiiv.com/p/rigor-as-an-algorithm).

This package is that method as it runs on the author's machine, lifted out so anyone can install it.

## What you get

| Piece | Where it lands | What it does |
|---|---|---|
| `canon/RIGOR-ALGORITHM.md` | `~/.agents/RIGOR-ALGORITHM.md` | Question zero and the six questions. The single source; every other file points here. |
| `templates/rigor.md` | `~/.claude/templates/rigor.md` | The `.rigor.md` skeleton. Empty headings fail validation, so skimming is not an option. |
| `skills/rigor/SKILL.md` | `~/.claude/skills/rigor/SKILL.md` | `/rigor`: read the canon, name the authority, answer, validate, get the answers agreed, then run the checklist. |
| `hooks/rigor-gate.sh` | `~/.claude/hooks/rigor/` | **Pre-work gate.** Blocks the third distinct file edited in a session unless a valid `.rigor.md` sits above it. `--ask` nags on requests that read big. |
| `hooks/evidence-gate.sh` | `~/.claude/hooks/rigor/` | **Done-gate.** At Stop, a material claim ("done", "works", "deployed", "verified") with no tool evidence in the turn and no `[inferred]` tag is refused. |
| `canon/PONYTAIL.md` | `~/.agents/PONYTAIL.md`, imported from `~/.claude/CLAUDE.md` | The counterweight. Rigor without it runs away on its own trip: the ladder (does it need to exist, is it already here, stdlib, native, one line, minimum) keeps the answers small. Hook-free copy of [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail), MIT. |

`rigor install` also writes three entries into `~/.claude/settings.json` (PreToolUse on the edit tools, UserPromptSubmit, Stop) and one marked block into `~/.claude/CLAUDE.md`. Both are add-if-absent and removed exactly by `rigor uninstall`. Nothing else in either file is touched.

## Install

Homebrew:

```bash
brew install mohan-n-swamy/tap/rigor
rigor install
```

Git or zip:

```bash
git clone https://github.com/mohan-n-swamy/rigor && cd rigor   # or unzip rigor-v*.zip && cd rigor-v*
./install.sh
```

Restart your Claude Code sessions. `rigor status` shows what is wired. Needs `bash` and `python3`.

For ponytail with its own hooks (mode tracking, subagent propagation), install the plugin as well:

```bash
claude plugin marketplace add DietrichGebert/ponytail && claude plugin install ponytail@ponytail
```

## What a session looks like afterwards

1. You ask for something big. The prompt hook injects: *this reads big enough for the rigor protocol, do not start editing, ask.*
2. Claude runs `/rigor`, copies the template to `.rigor.md` beside the work, answers question zero and the six questions, and validates. Section 2's MUST NOT list is the one that will be missing; the validator demands it.
3. Work proceeds. If Claude skipped step 2, the third file it touches is blocked with the questions printed and two exits: write the answers, or put the literal `rigor: small` in the edit.
4. Claude says "done". The Stop hook checks the turn: a command that could have failed ran, or the claim is tagged `[inferred]`, or the turn is refused with the reason.

## Overrides

Every gate ships with its override, because an unsilenceable warning gets ignored.

| Scope | How |
|---|---|
| One edit | the literal `rigor: small` in the content |
| One session | a message containing the standalone line `rigor: mute session` |
| Pre-work gate, globally | `touch ~/.claude/state/rigor-gate.disabled` (remove to re-enable) |
| Done-gate, globally | `touch ~/.claude/state/claims-gate.disabled` |
| One invocation | `RIGOR_GATE_OFF=1` in the environment |
| Threshold | `RIGOR_FILE_THRESHOLD=5` (default 3) |

## Commands

```
rigor install        wire everything (idempotent)
rigor uninstall      remove exactly what install added
rigor status         what is installed, how many hooks wired
rigor validate FILE  schema-check a .rigor.md
rigor self-test      prove the gate can fail and can pass
```

## Tests

`make test` runs `tests/test.sh` in a throwaway `HOME`: install over a settings file that already has a foreign hook, assert the three entries and the CLAUDE.md block, run twice for idempotence, feed the pre-work gate three edits and see the third blocked, validate a good and a bad `.rigor.md`, feed the done-gate an untagged and a tagged claim, uninstall and diff settings back to the original, and confirm install refuses without `python3`. `make dist` builds the zip from tracked files only.

## Limits, stated

- The done-gate reads the Claude Code transcript format of 2026-09. If that format changes, the gate fails open (exit 0), not closed.
- The pre-work gate counts files, not risk. Three trivial edits trip it; one catastrophic edit does not. The canon's "big enough" list is the real test; the count is the mechanical backstop.
- `evidence-gate.sh --integration` is a mode specific to the author's rig and is never wired by the installer.

## License

MIT. `canon/PONYTAIL.md` is MIT, (c) 2026 DietrichGebert.
