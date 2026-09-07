# rigor — STATUS

**Updated:** 2026-09-07
**Branch:** main
**Content identity:** sha256:12c931b5a1a2fa7b14a00cf7a97a9e352eeade21ed06461349317ffa6ced758b (indexed paths, working-tree bytes; excludes STATUS.md and untracked files; stage additions first)
**Tree:** DIRTY

## Current goal

Keep v0.1.x installable for strangers: one command, three hooks, exact uninstall. Next change only when a user report or a Claude Code hook-format change demands it.

## Latest verified evidence

`bash tests/test.sh` → ALL PASS (34 assertions, throwaway HOME) on 2026-09-07 before commit bbbfee5. `brew upgrade mohan-n-swamy/tap/rigor` 0.1.0→0.1.1 and `brew test rigor` exit 0 on the author's Mac the same day.

## Blocker

_none_

## Next action

- [ ] Install on one machine that is not the author's rig and confirm a session is blocked at the third file and at an unevidenced "done" (the rig wires the same gates through its own dispatchers, so it cannot be the test).

---
_Stage intended new files with `git add -- <paths>` before refreshing with `bin/gen-status.rb rigor` for /save, /park, /wrap-up. Use `--allow-untracked` only for unrelated scratch. Machine header (Updated/Branch/Content identity/Tree) is auto-filled; the prose is yours._
