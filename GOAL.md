# Goal — the standing intent anchor

**Not a spec-kit artifact.** [github/spec-kit](https://github.com/github/spec-kit) ships no goal or vision template — its `templates/` directory contains only constitution, spec, plan, tasks, and checklist; the closest it gets is README prose. This repository adds one because autonomous, multi-session runs need a standing statement of intent that a per-issue spec can't carry: an issue tells an agent *what* to build; nothing else tells it *why the repo exists* or *what phase it's proving right now*. Non-negotiable operating rules live in `CONSTITUTION.md`, not here.

## Mission

Turn *"here's a task"* into a verified, review-ready pull request through a real issue → branch → PR flow, run by AI agents with humans at the boundary: humans author the work and approve the result; the line in between runs autonomously. Grow this bottom-up into a fully autonomous, observable, guard-railed "dark factory," one dogfooded increment at a time — refactoring earlier decisions is expected, not a failure.

## Current Phase

> prove that one externally-authored issue can be driven issue → branch → pull request → review, unattended, within a single session window, with the human only authoring work and merging results

This is a point-in-time claim, expected to move — update it as the phase advances (see `CLAUDE.md`'s backlog, #12–#20, for what's next).

## Non-Goals

- **Synthesizing a spec and building against it in one unattended pass.** A one-line description is not executable input — it must become a human-authored issue first (ADR-0002).
- **Autonomous execution of `type:epic` issues.** An epic is a container, not an executable unit; it must be decomposed into child issues before pickup.
- **Claiming hook-enforced gates today.** The gates are prompt-honored forcing functions; hard enforcement is separate, tracked backlog work, not a property of the current phase.
- **Autonomous merging.** The merge is always human, in this phase and every phase after it.
- **Concurrent, multi-issue orchestration.** The current phase proves a single issue end-to-end before this repo claims anything about running several at once.

## When To Re-Read

- **Session start** — before touching any issue, to reload standing intent that no single issue carries.
- **Waking after a usage-window reset** — resumed context should reconfirm the mission and current phase, not just the task in flight.
- **Before picking up new work** — to check the work still serves the current phase, not a phase already superseded.

## Volatility

This file changes through a normal documentation pull request — no amendment ceremony required. Contrast `CONSTITUTION.md`, which changes only via its own amendment procedure and a version bump.
