# Issue Label Scheme

Single source of truth for GitHub issue labels used by this plugin. Every skill that applies labels (publish-issue, fix-bug, a2a-workflow) references this file. Labels are validated against the live repo at runtime — this table captures the **intent**; the repo is the truth.

## Label namespaces

### `type:` — kind of work (exactly one per issue)

| Value | Meaning |
|-------|---------|
| `type:feature` | A new capability to add |
| `type:task` | A concrete unit of work (child of feature/epic/ADR) |
| `type:bug` | A defect (requires repro + expected/actual) |
| `type:spike` | A time-boxed investigation with a defined deliverable |
| `type:epic` | A large umbrella initiative (parent of features/tasks) |
| `type:adr` | An Architecture Decision Record published as an issue |

### `priority:` — urgency (at most one per issue)

| Value | Meaning |
|-------|---------|
| `priority:high` | Now / blocking — P0/P1; use for data corruption, silent costs, or every-user impact |
| `priority:medium` | Soon — scheduled work with a clear horizon |
| `priority:low` | Backlog — nice-to-have, no active blocker |

### `status:` — transient state (apply only when applicable; remove when resolved)

| Value | Meaning |
|-------|---------|
| `status:blocked` | Waiting on an external dependency — name it in a comment |
| `status:needs-decision` | Awaiting a call from a named person — @-mention the decider |

### `phase:` — workflow position within the a2a-workflow engine (applied by fix-bug / a2a-workflow; removed when the issue moves past that phase)

| Value | Meaning |
|-------|---------|
| `phase:triage` | Issue created but not yet scheduled for implementation |
| `phase:in-progress` | A branch exists and implementation is active (P4–P5) |
| `phase:review` | PR is open and awaiting blind-review or human review (P6–P7) |
| `phase:done` | Implementation merged; issue closed or closing |

## Rules

- **Validate at runtime.** Run `gh label list --repo REPO` before applying any label. If a label from this table is missing in the repo, surface it and ask the human — never auto-create.
- **Human-in-the-loop for missing labels.** Never silently create a label. Ask first.
- **One `type:` per issue.** More than one is a sign the issue covers multiple topics — split it.
- **`phase:` is mutable.** Update it as the issue progresses; remove it when the issue closes.
- **Ownership = assignee, not a label.** Use `gh issue edit --add-assignee` for ownership.
- **Grouping = GitHub native sub-issues**, not `Parent: #N` in the body.
