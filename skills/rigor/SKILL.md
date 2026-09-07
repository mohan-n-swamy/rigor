---
name: rigor
description: Run the Rigor Algorithm before a big change — answer the six questions in writing to .rigor.md, validate them, and emit the micro-checklist. Invoke when a request is big enough (3+ files, a new user-facing surface, behaviour others depend on, anything not undoable with git checkout, or more than ~30 minutes to redo), when the rigor gate blocks an edit, or on /rigor.
---

# /rigor — the six answers, before the work

**The authority is `~/.agents/RIGOR-ALGORITHM.md`. Open it. Do not recall it.**
This skill does not restate the six questions; it runs them.

## When it fires

- **By default, unasked**, the moment a request meets "big enough" in the canon. The
  first move is not the first edit — it is to say *this looks big enough for the rigor
  protocol, shall I run it?* and wait.
- When `rigor-gate.sh` blocks an edit.
- On `/rigor`.

## Procedure

1. **Read the canon.** `cat ~/.agents/RIGOR-ALGORITHM.md`. Every time. The point of the
   article is that the standard stops working the moment it lives in memory.

2. **Name the authority.** Question 2 needs something to conform *to* — a file, opened,
   with a path. "The design" and "the spec" are not authorities; `specs/217/design/
   V2-SHELL.html` is. If you cannot name a file, that gap IS the first finding.

3. **Copy the template, then answer.**
   `cp ~/.claude/templates/rigor.md <work-dir>/.rigor.md`
   Answer all six. Rules that decide whether an answer is real:
   - Q1: **objective first, flawless second, never merged.** State what the task is FOR
     — whose problem, and what they do differently once they have the output — then
     define flawless as facts that serve that objective, each ending in a check a
     stranger could run. No check, not a fact. A fact that does not serve the objective
     is not part of finished. Define flawless without the objective and it silently
     becomes a description of what you were going to build anyway.
   - Q2: **write the MUST NOT list longer than feels necessary.** It is the list nobody
     writes and the list every review turns out to be about. If it has fewer entries
     than the MUST list, you have not finished.
   - Q3: draw failure modes from what has actually gone wrong before — this session,
     this repo, your project's known-issues notes. Invented ones are cheap; real
     ones are the point.
   - Q4: per-step, not per-project. If a check can only run at the end, it belongs in Q6
     under ASSEMBLY, not here.
   - Q5: every must-not gets a mechanism and a rung. "I will be careful" is rejected.
     Prefer the top of the ladder: a defect made *inexpressible* by a template or a
     single source needs no vigilance at all.
   - Q6: split MICRO from ASSEMBLY explicitly, or the assembly faults hide until the end.

4. **Validate.** `rigor validate <work-dir>/.rigor.md` (or `bash ~/.claude/hooks/rigor/rigor-gate.sh --validate <work-dir>/.rigor.md`)
   Exit 0 or fix what it names. This unblocks the gate.

5. **Show the user the answers and get them agreed** before the first edit. The must-not
   list is what they will react to.

6. **Run it, do not file it.** Call Q4's checklist at each step and append to the run log
   in the file as you go. A run log written afterwards is fiction.

7. **Unit one, whole chain.** Take the first unit all the way through every check before
   unit two exists. A batch inherits whatever unit one carried.

## Before saying done

**What did I run?** Not what did I read. What executed, and could it have failed?
A check ran → say done. None did → run it now, or say *"written but not yet verified"*.
That state is legitimate and costs far less than a review discovering it.
`evidence-gate.sh` enforces this on Stop; do not wait to be caught by it.

## Guards

- **Do not write the answers to fit what you already plan to build.** The order is the
  whole method: target, then conformance, then work, then proof. Answers written after
  the approach is chosen describe the approach; they cannot fail it.
- **Do not restate the canon** in the .rigor.md, in a summary, or in chat. Point to it.
- **The gate is the backstop, not the trigger.** Being blocked by rigor-gate means the
  default behaviour — asking first — was already skipped.

## Related

- `~/.agents/RIGOR-ALGORITHM.md` — canonical, the six questions
- `~/.claude/hooks/rigor/rigor-gate.sh` — pre-work gate (`--validate`, `--self-test`)
- `~/.claude/hooks/rigor/evidence-gate.sh` — done-gate on Stop
- `~/.agents/PONYTAIL.md` — the counterweight: smallest change that works, no runaway scope
- https://turiya.beehiiv.com/p/rigor-as-an-algorithm — the article the canon comes from
