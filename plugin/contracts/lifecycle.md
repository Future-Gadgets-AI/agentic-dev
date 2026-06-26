# Issue Lifecycle

> **Enforcement: prompt-honored.** This is the contract `/pickup` and the human entrypoints are *told* to follow; deterministic gating (hooks) is a backlog item. See ADR-0003.

An issue's life is a state machine. Each **column** has one **owner** (human or autonomous) and one **procedure**. Each issue's state is encoded in its `phase:` / `readiness:` / `status:` labels (`labels.md`). A GitHub Projects board surfaces these as columns via a single-select **Status** field that mirrors the labels — Projects can't use labels for columns directly (the board mapping is designed in #19).

## States

| Column / state | Owner | Procedure | Exits to |
|---|---|---|---|
| **Draft / Refinement** | 🧑 human | author/refine the issue (`/create-issue`, `/create-adr`, `/create-epic`, agentspec `/brainstorm`) until it passes the DoR | Ready |
| **Ready** (To-Do) | 🤖 autonomous | `/pickup #N` runs the DoR gate, then begins | In Progress · or → Refinement (gate NOT-READY → `needs-refinement`) |
| **In Progress** | 🤖 autonomous | the `/pickup` engine: branch → SDD (implement) → smoke gate | Review · or Escalated (mid-flight block) |
| **Escalated** | 🧑 human | answer the structured question in a comment; remove `status:needs-decision` | In Progress (a session resumes) |
| **Review** | 🤖 blind-review, then 🧑 `/review-pr` | the blind reviewer runs the test plan + comments; the other human reviews the PR | Ready-to-merge · or → In Progress (changes requested) |
| **Ready to merge** | 🧑 human | merge the PR | Done |
| **Done** | — | terminal (issue closed) | — |

## The two gates on the happy path
- **DoR gate** (defines Draft → Ready; re-checked at pull): an issue is *Ready* only once it passes the Definition of Ready (`readiness:ready`). `/pickup` re-runs the gate when it pulls a Ready card (in case the issue went stale); a fail bounces it back to Refinement (`readiness:needs-refinement`). (A *mid-flight* block is different — that's Escalated / `status:needs-decision`.) See `dor-rubric.md`.
- **Smoke gate** (In Progress → Review): no PR without an executed test **and** a real smoke of the changed path (captured transcript), incl. the shadow-trick for paid/destructive paths.

## Ownership boundary — where humans stay
Humans own **Refinement**, **Escalated**, and **Ready-to-merge** (and may own Review). Everything between Ready and the PR is autonomous. **The merge is always human.** Escalation is **async**: the card waits in a column behind a label; the human reviews a "brownfield" card when they get to it, then fire-and-forgets again.

## Minimalism
Every column must earn its place with a *distinct* owner + procedure. Resist speculative columns — a ready-gate that grows into a bureaucratic stage-gate kills flow (the Definition-of-Ready anti-pattern).
