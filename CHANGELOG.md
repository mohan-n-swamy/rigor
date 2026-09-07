# Changelog

## v0.1.0 — 2026-09-07

First public cut. Everything here ran unchanged on the author's machine before packaging.

- `canon/RIGOR-ALGORITHM.md` — the six questions plus question zero, verbatim from the rig.
- `canon/PONYTAIL.md` — hook-free copy of DietrichGebert/ponytail (MIT), the counterweight.
- `hooks/rigor-gate.sh` — pre-work gate: blocks the third distinct file with no `.rigor.md` above it; `--ask` nags on big-sounding requests; `--validate`; `--self-test`.
- `hooks/evidence-gate.sh` — done-gate: a material claim with no tool evidence and no `[inferred]` tag is refused at Stop.
- `bin/rigor` — `install` (idempotent settings.json merge, marked CLAUDE.md block), `uninstall`, `status`, `validate`, `self-test`.
- `tests/test.sh` — end-to-end in a throwaway HOME; both gates shown to block and to allow.
