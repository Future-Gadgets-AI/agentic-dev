# Label Scheme

> **Enforcement: prompt-honored.** Components are *told* to validate against this file and the live repo; nothing hard-blocks a wrong label yet (hook enforcement is a backlog item). The repo's live labels are the ultimate truth — this file captures the intent.

Single source of truth for the GitHub issue/PR labels this plugin uses, at `${CLAUDE_PLUGIN_ROOT}/contracts/labels.md`. Referenced **directly** by `git-collaboration` (the conventions reference) and `a2a-workflow`; the other label-applying components (`publish-issue`, `create-issue`, `create-adr`, `fix-bug`) reach the scheme through `git-collaboration`. The planned `/pickup` will reference it too (see #12).

## Namespaces

### `type:` — kind of work (exactly one per issue)
| Value | Meaning |
|-------|---------|
| `type:feature` | A new capability to add |
| `type:task` | A concrete unit of work (child of a feature/epic/ADR) |
| `type:spike` | A time-boxed investigation with a defined deliverable |
| `type:epic` | A large umbrella initiative (parent of features/tasks) |
| `type:adr` | An Architecture Decision Record, published as an issue |
| `bug` *(built-in)* | A defect (requires repro + expected/actual) — uses GitHub's built-in `bug` label |

### `priority:` — urgency (at most one)
| Value | Meaning |
|-------|---------|
| `priority:high` | Now / blocking — P0/P1 (data corruption, silent costs, every-user impact) |
| `priority:medium` | Soon — scheduled work with a clear horizon |
| `priority:low` | Backlog — nice-to-have, no active blocker |

### `readiness:` — Definition-of-Ready state (exactly one; see `dor-rubric.md`)
The DoR gate's verdict, persisted on the issue. **Orthogonal** to `phase:` and `type:`.
| Value | Meaning |
|-------|---------|
| `readiness:draft` | Captured idea, not yet DoR-assessed (default on creation) |
| `readiness:needs-refinement` | DoR assessed and **failed** — needs human authoring before an agent can pick it up; the gaps are in a comment |
| `readiness:ready` | Passes the Definition of Ready — `/pickup` may execute it autonomously |

### `status:` — transient blocker (apply only when true; remove when resolved)
| Value | Meaning |
|-------|---------|
| `status:blocked` | Waiting on an external dependency — name it in a comment |
| `status:needs-decision` | Escalated: awaiting a specific human decision — @-mention the decider; the structured question is in a comment |

### `phase:` — workflow position (mutable; applied by `/pickup`; removed when the issue closes)
| Value | Meaning |
|-------|---------|
| `phase:triage` | Created, not yet pulled into active implementation |
| `phase:in-progress` | A branch exists; implementation active |
| `phase:review` | PR open; awaiting blind / human review |
| `phase:done` | Merged; issue closing |

## How the dimensions compose into lifecycle columns
The kanban column an issue sits in (see `lifecycle.md`) is derived from `phase:` × `readiness:` × `status:`. For example: `phase:triage` + `readiness:draft` = the *Draft / Refinement* column (human-owned); `phase:triage` + `readiness:ready` = the *Ready* column (an agent may pull it); any `status:needs-decision` = the *Escalated* column.

## Rules
- **Validate against the live repo.** Run `gh label list --repo REPO` before applying. If a label here is missing on the repo, surface it and ask the human — **never auto-create** (the lone exception is a deliberate, human-approved scheme rollout).
- **One `type:` and one `readiness:` per issue.** Multiple `type:` ⇒ the issue covers multiple topics — split it.
- **Ownership = assignee**, not a label. **Grouping = native sub-issues**, not `Parent: #N` in the body.
- **`phase:` / `readiness:` / `status:` are mutable** — update them as the issue moves; remove `phase:` when it closes.
