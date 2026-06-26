# Architecture — the agentic-dev "dark factory"

> **Status: design-of-record (living).** How the system works *now*. The *why* behind each choice is in the ADRs (published as `type:adr` issues on this repo — ADR-0001 … ADR-0005). The canonical machine-loaded rules are in `plugin/contracts/`. This file is prose, kept lean so it stays current rather than rotting.

`agentic-dev` turns *"here's a task"* into a verified, review-ready PR through a real **issue → branch → PR** flow, run by AI agents with humans at the boundary. The model is a **lights-out factory**: humans author and approve; the line in between runs autonomously, with gates that **halt-and-escalate** rather than guess.

## The spine
- **GitHub is the state store; the issue is the spec.** (ADR-0001) Every unit of work is a self-contained GitHub issue. Sessions are *stateless workers* — any session can resume any issue purely from its GitHub state (issue, comments, labels, branch, PR). Deferred work is a **draft issue**, not a TODO.
- **Two kinds of entrypoint.** (ADR-0002) *Human / authoring* entrypoints create work (`/create-issue`, `/create-adr`, `/create-epic`, agentspec `/brainstorm`). The *agentic / execution* entrypoint **`/pickup #N`** consumes work — **issue-only: no issue, no run.** `/pickup` is one type-driven executor (it reads the issue's `type:` and adapts), replacing separate `fix-bug` / `implement-feature` verbs.

## The issue lifecycle (`plugin/contracts/lifecycle.md`, ADR-0003)
A state machine = kanban columns, each with an owner and a procedure:

```
Draft/Refinement ──DoR──> Ready ──/pickup──> In Progress ──> Review ──> Ready-to-merge ──> Done
     (🧑)                  (🤖)               (🤖)            (🤖+🧑)         (🧑)
                                                │
                                          Escalated (🧑)  ← needs-decision / blocked
```

**Readiness** (`readiness:draft | needs-refinement | ready`) is an orthogonal dimension that gates Draft→Ready; scheduling (backlog vs active) is orthogonal again. An issue's state is encoded in its `phase:` × `readiness:` × `status:` labels. (A GitHub Projects board *can't* make columns from labels — it surfaces these as columns via a single-select **Status** field that mirrors them; that mapping is designed in #19.)

## The gates
- **Definition-of-Ready gate** (`plugin/contracts/dor-rubric.md`, ADR-0004) — the DoR defines the Draft→Ready boundary; `/pickup` re-checks it before starting work, keyed to **reversibility × blast-radius, not model confidence**. Verdicts: READY / READY-WITH-LOGGED-ASSUMPTIONS / NOT-READY (with the specific gaps). Missing info that lives in the repo → the agent explores; intent only a human holds → it asks.
- **Verify / smoke gate** — no PR without an executed test **and** a real smoke of the changed path (captured), incl. the **shadow-trick** for paid/destructive paths.

Both are **prompt-honored forcing functions today**, not hook-enforced. Real enforcement (hooks, especially for irreversible steps) is on the backlog. *The gates raise the floor; the shadow-trick + human merge cap the ceiling.*

## Escalation is async (fire-and-forget)
A NOT-READY verdict or a mid-flight blocking question never makes a human sit and wait: the card gets `status:needs-decision` + a **structured comment** and parks in the *Escalated* column. A later session resumes it. The human reviews a "brownfield" card when convenient, then fire-and-forgets again.

## Components (ADR-0005)
Chosen by **role**, not by folder (commands and agents both nest):
| Type | Role | Examples |
|------|------|----------|
| **command** | entrypoint / orchestration | `/pickup`, `/create-issue`, `/create-adr` |
| **skill** | capability (loadable, specialist) | the gates, SDD steps, per-type reference |
| **agent** | a role/task, single-responsibility (body ≈ a system prompt) | blind reviewer, explorer, planner |
| **`plugin/contracts/`** | canonical rules/data | lifecycle, DoR rubric, labels |

The existing skills predate this taxonomy; migration is **incremental** (a backlog item), not a big-bang prerequisite.

## Records & where each thing lives
| Artifact | Answers | Where |
|----------|---------|-------|
| **ARCHITECTURE.md** (this file) | how it works *now* | repo root |
| **ADRs** | *why* — append-only decision history | `type:adr` issues |
| **`plugin/contracts/`** | the canonical rules the workflow loads | `plugin/contracts/*.md` |
| **issues** | the open work — and the durable state store | GitHub |
