# Issue Lifecycle

> **Enforcement: prompt-honored.** This is the contract `/pickup` and the human entrypoints are *told* to follow; deterministic gating (hooks) is a backlog item. See ADR-0003.

An issue's life is a state machine. Each **column** has one **owner** (human or autonomous) and one **procedure**. The kanban board's columns map to these states via the `phase:` / `readiness:` / `status:` labels (`labels.md`).

## States

| Column / state | Owner | Procedure | Exits to |
|---|---|---|---|
| **Draft / Refinement** | 🧑 human | author/refine the issue (`/create-issue`, `/create-adr`, `/create-epic`, agentspec `/brainstorm`) until it passes the DoR | Ready |
| **Ready** (To-Do) | 🤖 autonomous | `/pickup #N` runs the DoR gate, then begins | In Progress · or Escalated (gate = NOT-READY) |
| **In Progress** | 🤖 autonomous | the `/pickup` engine: branch → SDD (implement) → smoke gate | Review · or Escalated (mid-flight block) |
| **Escalated** | 🧑 human | answer the structured question in a comment; remove `status:needs-decision` | In Progress (a session resumes) |
| **Review** | 🤖 blind-review, then 🧑 `/review-pr` | the blind reviewer runs the test plan + comments; the other human reviews the PR | Ready-to-merge · or → In Progress (changes requested) |
| **Ready to merge** | 🧑 human | merge the PR | Done |
| **Done** | — | terminal (issue closed) | — |

## The two gates on the happy path
- **DoR gate** (Ready → In Progress): is the issue fleshed-out enough to run autonomously? `readiness:ready` ⇒ proceed; otherwise bounce to Escalated / Refinement. See `dor-rubric.md`.
- **Smoke gate** (In Progress → Review): no PR without an executed test **and** a real smoke of the changed path (captured transcript), incl. the shadow-trick for paid/destructive paths.

## Ownership boundary — where humans stay
Humans own **Refinement**, **Escalated**, and **Ready-to-merge** (and may own Review). Everything between Ready and the PR is autonomous. **The merge is always human.** Escalation is **async**: the card waits in a column behind a label; the human reviews a "brownfield" card when they get to it, then fire-and-forgets again.

## Minimalism
Every column must earn its place with a *distinct* owner + procedure. Resist speculative columns — a ready-gate that grows into a bureaucratic stage-gate kills flow (the Definition-of-Ready anti-pattern).
