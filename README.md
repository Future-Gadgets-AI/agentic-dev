# agentic-dev

Agentic development workflows with GitHub integration. A suite of Claude Code skills that turn *"fix this"* / *"ship that"* into a **well-formed issue → verified change → review-ready PR**, through a real issue/branch/PR flow with forced quality gates.

## Skills

**GitHub building blocks** (standalone — no extra dependencies beyond `gh`):

| Skill | Purpose |
|---|---|
| `/agentic-dev:create-issue` | Draft a well-formed GitHub issue |
| `/agentic-dev:publish-issue` | Publish, label, and relate an issue against the live repo |
| `/agentic-dev:create-pr` | Open a structured PR linked to its issue/ADR |
| `/agentic-dev:review-pr` | Review a PR (the collaborator's side of the A2A flow) |
| `/agentic-dev:create-adr` | Capture an architecturally-significant decision as an ADR |
| `/agentic-dev:git-collaboration` | The two-person A2A model — branching, commits, conventions (reference) |

**Workflow engine:**

| Skill | Purpose |
|---|---|
| `/agentic-dev:a2a-workflow` | End-to-end issue → PR engine: understand → clarify → issue → branch → implement → verify → PR → blind-review, with four quality gates |
| `/agentic-dev:fix-bug` | Thin wrapper that drives a bug through `a2a-workflow` |

## Prerequisites

- **GitHub CLI (`gh`)**, authenticated — every GitHub operation runs through it.
- **AgentSpec plugin** — `a2a-workflow` (and `fix-bug`, which wraps it) delegate the *implement* step to `agentspec:sdd-workflow` and `the-planner`. The standalone building-block skills above work **without** it.

## Installation

```text
/plugin marketplace add lucasbrandao4770/lucasbrandao-cc-plugins
/plugin install agentic-dev@lucasbrandao-cc-plugins
```

## Usage

- **Quick GitHub action:** `/agentic-dev:create-pr`, `/agentic-dev:create-issue`, etc. — invoke the building block you need.
- **Full bug flow:** `/agentic-dev:fix-bug <description>` — runs the gated issue → PR engine end to end (requires AgentSpec).

## License

MIT
