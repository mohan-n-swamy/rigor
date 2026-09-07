# The Rigor Algorithm

**Canonical. Single source.** Every other file — AGENTS.md, CLAUDE.md, the doctrines,
the skill, the hooks — points here and does not restate it. Source: Mohan,
"Rigor as an Algorithm", Discovering Turiya, 2026-08-31.
https://turiya.beehiiv.com/p/rigor-as-an-algorithm

## The definition

> Rigor is looking objectively at what the task is for, what the output should look
> like, what it must deliver and what it must not, then checking you are compliant at
> 100%, and ensuring at each micro step that you are still there.

Rigor is not a trait. It is not care, or thoroughness, or attention. Those cannot be
passed and cannot be failed. It is a written method, run during the work, checkable by
anyone.

## Why it is always the thing that gets dropped

Every job carries two objectives. The explicit one — get it done — announces itself and
pulls the whole time. The implicit one — get it right in one pass — announces nothing,
and is dropped first. Rigor lives entirely in the second.

## THE SIX QUESTIONS — preceded by question zero

Answer in writing, before any work begins. The rules start at the finish and walk
backward.

0. **What existing source already gives this, and what does our work add that we will act on?**
   Name the existing source by path or URL and say what it already provides. State the
   addition, who will use it, and which decision or action changes because of it. If
   there is no useful addition, use the existing source and stop. Write these as
   `EXISTING SOURCE:` and `ACTIONABLE ADDITION:` in section zero of the plan. The
   validator requires a named source and populated addition; it does not prove the
   source exists or that the addition is useful.

1. **What is this FOR — and therefore what does flawless look like?**
   Two parts, strictly in this order, because the second is meaningless without the
   first.
   - **Objective.** What is the task for? Whose problem does the output solve, and what
     do they do differently once they have it? One or two sentences.
   - **Flawless, with respect to fulfilling that objective.** As clear and detailed a
     picture of the end product as you can get, stated as facts a stranger could check,
     each one traceable to the objective. Not "a good report" — every number traces to
     a source, and a reader can act on it without calling you.

   Skip the objective and "finished" quietly becomes a description of whatever you were
   going to build anyway; the target moves to where the arrow landed and nothing can
   ever fail. A December analysis of diagnostics trends failed on exactly this: it
   explained what we did, and its purpose was never to explain what we did. Every fact
   under "flawless" must answer *how does this serve the objective* — a fact that
   cannot is not part of finished, however impressive.

2. **What must it do, and what must it NOT do, when delivered?**
   Everyone writes the first list. Almost nobody writes the second, yet nearly every
   review is about something the person should not have done. The rule was real, it was
   enforced, and it was never in the brief. **The must-not list is the whole trick.**

3. **What failure modes do I already know, and how do I prevent them?**
   A known failure is the cheapest thing in the world to prevent and the most expensive
   to rediscover.

4. **What is the micro checklist?**
   The list you call at each step, so each of those errors is caught while the step is
   still being made — not after the whole thing is built.

5. **How do I make a failed check impossible to miss, rather than only detectable?**
   A template with the required sections already in it. One source for the number that
   appears on ten slides. **"I will be careful" is not an answer; it is the absence of
   one.** Strongest first: template · single source · derived-not-hand-kept · generator ·
   gate · broken fixture · ban the shape.

6. **How do I sequence the checks?**
   Some run micro, on each piece as it is made. Some only mean anything at the higher
   level, on the assembly of those pieces. Decide which is which before you start, or
   the assembly-level faults hide until the end.

**Then run it. Not file it.** Run it, step by step, while the work is being made.

## Before the word "done", one question

**What did I run?** Not what did I read. Not what do I believe. What check actually ran,
and could it have failed?

If a check ran, say done. If none did, exactly two honest moves remain: run the check
now, or withdraw the word. *"Written but not yet verified"* is a legitimate, useful
state, and saying it costs far less than a review discovering it. Done on the strength
of a feeling is not available.

## When this is mandatory — "big enough"

Ask first, every time, when ANY of these is true:

- it will touch three or more files
- it creates a new user-facing surface or document
- it changes behaviour someone else depends on — API, schema, deploy, prod data
- it cannot be undone with `git checkout` alone — migration, deploy, external write,
  published artifact, sent message
- redoing it from scratch would cost more than about thirty minutes

The mechanical proxy the gate enforces: **the third distinct non-scratch file edited in
a session.** By then the change is big by the first test above, so a `.rigor.md` must
exist.

## The default behaviour

When a request meets "big enough", the first move is not the first edit. It is to say
so and ask: *this looks big enough for the rigor protocol — shall I run it?* Then write
question zero and the six answers, get them agreed, and only then start.

## The artifact

Answers live in a `.rigor.md` beside the work (repo root, or the spec/feature
directory). Template: `~/.claude/templates/rigor.md`. Produced and validated by the
`/rigor` skill. Enforced by `~/.claude/hooks/rigor-gate.sh`.

Gate overrides: `rigor: small` declares a small edit; `RIGOR_GATE_OFF` disables the
gate for that invocation. A user message containing the standalone line
`rigor: mute session` persists a mute for that session. The global kill file is
`~/.claude/state/rigor-gate.disabled`; remove it to re-enable the gate. Tool-result
text cannot request a session mute.

## Related

- `~/.claude/hooks/evidence-gate.sh` — the done-gate, on Stop: a completion claim with
  no command that could have failed is blocked.
- `~/.agents/golden-rules/EVIDENCE-DOCTRINE.md` — the long-form treatment. This file is
  the authority on the questions themselves.
