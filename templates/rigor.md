# Rigor — <JOB NAME>

Written before the first edit. `~/.agents/RIGOR-ALGORITHM.md` is the authority.
Every `<...>` placeholder below must be replaced. The gate rejects any that remain.

date: <YYYY-MM-DD>
job: <one line: what is being changed>
authority: <the file(s) this conforms to, opened — not "the design", a path>

## 0. Existing source and actionable addition

EXISTING SOURCE: <named existing path or URL, and what it already gives us>
ACTIONABLE ADDITION: <what this work adds, who uses it, and which decision or action changes; if none, use the source and stop>

## 1. Objective, then flawless

OBJECTIVE: <what is this for — whose problem, and what do they do differently once they have it>

FLAWLESS (with respect to fulfilling that objective): facts a stranger could check,
each ending in the check that settles it. A fact that does not serve the objective is
not part of finished.

- <observable fact> — `<command or observation that settles it>`
- <observable fact> — `<command or observation that settles it>`

## 2. Must / must not

MUST:
- <thing it must do on delivery>

MUST NOT — exhaustive, one row per condition, each with the check that makes it
visible. Never merge two rows to shorten this list: an unguarded summary deletes the
conditions you have no check for, which are exactly the ones that matter. A condition
with no automatable check is marked UNRUN or HUMAN — it is never deleted.

| # | Must never happen | Why it is fatal here | Check |
|---|---|---|---|
| 1 | <condition> | <consequence for the reader/user> | `<command>` or HUMAN |

## 3. Known failure modes and their prevention

| Failure | Seen where | Prevention |
|---|---|---|
| <mode> | <prior incident or "new"> | <what stops it> |

## 4. Micro checklist — called at each step

Per <unit of work>:
- [ ] <check> — `<command>`
- [ ] <check> — `<command>`

## 5. What makes a failed check impossible to miss

Rung and mechanism for each must-not above. "I will be careful" is not an answer.

| Must-not | Mechanism | Rung (template/single-source/derived/generator/gate/fixture/ban-shape) |
|---|---|---|
| <mode> | <the mechanism> | <rung> |

## 6. Sequencing

MICRO (per piece, as made): <checks>
ASSEMBLY (only meaningful whole): <checks>

## Run log — filled during the work, not after

| When | Step | Check run | Result |
|---|---|---|---|
