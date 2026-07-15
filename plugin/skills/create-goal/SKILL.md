---
name: create-goal
description: >-
  Authors a paste-ready `/goal <condition>` — Claude Code's loop primitive, which re-prompts the
  session after every turn until a small fast model judges the condition met. Grounds the
  condition in the repo and runs the check for real first, so the loop can neither self-clear on
  turn 1 nor hunt for a proof that never arrives. Use whenever the user wants to create, write,
  set, draft, or repair a goal; hand a session off to grind unattended; says "keep working until
  X", "don't stop until", "run it till it's green"; mentions loop engineering or completion
  conditions; or asks why a /goal looped forever, cleared early, or stalled on a permission
  prompt. NOT for this repo's root `GOAL.md` standing-intent anchor — that's a document about why
  the repo exists, changed by an ordinary doc PR, and shares nothing with this command but the
  word. Also not for time-triggered re-runs (`/loop`), evaluation in every session forever (a Stop
  hook in settings), or delegating merge authority for an unattended run (night-shift).
argument-hint: "[what you want done]"
---

# Create goal

**Source of truth:** <https://code.claude.com/docs/en/goal> — snapshot 2026-07-14, needs Claude
Code ≥ 2.1.139. The multi-line condition and the Haiku evaluator below are *observed* behavior
(probed on 2.1.210), not inference. Re-fetch the doc if anything here contradicts what you see.

**One responsibility: author the condition, and prove it starts false.** You never arm the goal —
you hand over a string to paste, because a loop that spends money unattended is the human's to
start (ADR-0002: humans author and approve).

## How `/goal` works

- **`/goal <condition>` starts a turn immediately, with the condition itself as the directive.**
  It is the opening prompt *and* the stop test at once. Serving both is the craft: a pure test
  ("all tests pass") is a limp directive, and a pure directive ("migrate the auth module") is
  unjudgeable.
- **After each turn, a small fast model (Haiku) reads the condition and the conversation and
  returns yes/no with a reason.** A "no" hands that reason back as the next turn's guidance.
- **The evaluator has no tools.** It cannot run your tests or open your files. It judges text
  already sitting in the transcript — fast, cheap (~5% of turn spend), and a prompt-honored judge
  rather than a gate.
- **A goal grants no permissions.** Unattended turns need auto mode, or turn 1 stalls at the first
  approval prompt and the loop quietly does nothing.
- **A bound is not durable.** On `--resume` the condition carries over, but the turn count, timer,
  and spend baseline all reset — so "stop after 20 turns" silently becomes *20 more*, every resume.

`/goal` alone shows status; `/goal clear` stops it. Conditions can run to 4,000 characters, and
multi-line parses fine.

## The one question

The evaluator has no tools, so it believes text. Every way a goal dies early is a face of that, so
there is really only one question to ask of a draft:

> **What is the cheapest string that makes a credulous reader say yes — and can Claude produce it
> without doing the work?**

If it can, the goal is already broken. Faces you'll actually meet — evidence the question is
load-bearing, not a checklist to tick:

- **A bare claim.** "The tests pass" is satisfied by Claude *saying* the tests pass.
- **A vacuous quantifier.** "Every sub-issue is closed" is *true* over an empty set — so a goal
  whose subjects the run itself creates is already met on turn 1.
- **The check itself.** "The suite is green" makes any test that catches a real bug an *obstacle*,
  and deleting it the shortest path to done.
- **Your own transcript.** Success output pasted while drafting is precisely the string the
  evaluator hunts for.

The repair is always the same shape: demand an artifact a real command produced *this turn*,
anchor counts to a positive floor, and pin whatever the check measures.

**Then turn the question on your own evidence.** Before you call a defect proven, ask whether the
output you're holding would look identical if the code were fine. If it would, you ran a demo, not
an experiment — you need a control case, or a falsifier you state out loud. This is the same
question, and it is easier to fail here than anywhere else: a goal aimed at a defect you only
*believe* is real spends the whole night fixing nothing.

## Discover the end state; don't ask for it

The repo's gate rule (`ARCHITECTURE.md`) governs here too:

> Missing info that lives in the repo → the agent explores; intent only a human holds → it asks.

When the ask is "make it better", the end state is usually already in the code and the user just
hasn't named it — so read it, run the check, find the real defects, and come back with an end state
you *found*. Ask only for intent the codebase cannot hold: what "bite" means to them, which of two
policies they want. A question you could have answered yourself is the worst thing to hand someone
who is already walking out the door.

## Is this a goal at all?

| The work | Use |
|---|---|
| Ends when a named condition holds, checked after each turn | **`/goal`** |
| Finishes in one turn | Just ask — a goal adds an evaluator round-trip and nothing else |
| Ends when time passes, or polls something external | `/loop` |
| Should be evaluated in every session of this repo, forever | a Stop hook in settings |
| Has no end state you can name *after looking* | Nothing yet — say what you looked at |

## Flow

1. **Find the end state.** One measurable thing: an exit code, a failure count, an empty queue, a
   label.
2. **Find the real check and run it.** Discover the command from the repo — `package.json`,
   `Makefile`, `pyproject.toml`, CI config — never assume `npm test`. Execute it and keep the
   output.
3. **It should FAIL.** A check that already passes means the goal clears on turn 1 having done
   nothing: either the work is done (say so) or the condition tests the wrong thing. If the check
   needs credentials, network, or minutes you don't have, don't fake it — draft and flag it
   unverified.
4. **Draft** in the shape below, then **run pre-flight**.
5. **Hand it over** and stop.

## Pre-flight

Deliberately not a score — a 7/10 goal still burns the night.

| Question | A FAIL emits |
|---|---|
| Can the check command actually run here? | Find the real one; if none exists there's no check, so this isn't a goal yet |
| Does the check fail *right now*? | The work is already done, or the condition tests the wrong thing |
| Is success provable from text alone? | Demand the output be pasted, not described — a silent edit is invisible to a tool-less judge |
| Is honest failure a *winning* end state, and does it cost something? | Add the OR-branch — and require the blocker be named **and** what was tried, or it's a free exit the model will take |
| Is there a bound? | "or stop after N turns and report what remains" |
| Will the turns run unattended? | Say so at handover: pair with auto mode, or scope to pre-allowed tools |

Verdicts: **SHIP** · **SHIP, FLAGGED** (name what you couldn't verify) · **NOT A GOAL** (route it
per the table above). NOT A GOAL is a conclusion you reach *after looking* — never a question you
hand back.

## The shape

```
/goal <The directive, imperative — this is literally the first prompt, so make it start work.>

Done when: <the measurable end state> — proved by running `<exact command>` fresh and pasting
<the specific artifact: summary line / exit code / count>.

Or done when: <the honest-failure state> — name the specific blocker and what was attempted. Both
are success; do not guess past a blocker to satisfy this goal.

Constraints: <what must not change on the way there> — including whatever the check measures, so
the goal cannot be met by breaking it.

Bound: stop after <N> turns and report what remains.
```

## Hand it over

Three things, then stop:

1. The condition, fenced, ready to paste — or, if there is no goal here, what you found instead.
2. **Baseline:** one line — what the check printed just now.
3. **Before you paste:** auto mode on or off, anything unverified, and `/goal clear` as the exit.
   If your verification came back **green**, say to arm it in a fresh session — you just put the
   evaluator's target string into this transcript.

**Whenever you drop or replace the condition they asked for**, you owe them the reasoning — and
that debt is triggered by the swap, not by the verdict. It comes due just as hard when you quietly
ship something better as when you refuse outright, because in both cases they are not getting what
they asked for and deserve to know why. Two things carry it: why their version couldn't work (the
evaluator's mechanics are the part nobody guesses on their own), and what it would have cost
running unattended. Note that this is *reasoning*, not findings — a wall of everything you
discovered is not an explanation, and lands worse than the terse version it replaced.

## In this repo

The highest-value goal wraps `/pickup` — and done naively it fights the architecture. `/pickup`
escalates asynchronously and **stops cleanly**; a goal that only accepts "the PR is open"
re-prompts a session that already, correctly, gave up, so it re-escalates as spam or it guesses.
Give escalation a winning branch, and price it:

```
/goal Execute the /pickup workflow (plugin/commands/pickup.md) for issue #N.

Done when EITHER a PR for #N is open with the blind review posted, OR #N carries the `blocked`
label and a bot-attributed comment naming the specific blocker and what was attempted. Both are
success — do not guess past a blocker to satisfy this goal.

Constraints: never merge; never flip readiness yourself.

Bound: stop after 25 turns and report where it landed.
```

`/pickup` needs a `readiness:ready` target — without one the goal dies at the autonomy gate in
seconds, so check the board before promising a walk-away. `night-shift` owns delegated merge
authority and budget stop-lines: a goal is the engine inside one lifecycle, not a substitute for
that charter.
