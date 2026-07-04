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
| `/agentic-dev:implement` | Atomic design+build for one ready issue (ADR-0009's composable middle — no branching, no PR of its own) |

**Commands** (entrypoints — orchestration only, per the component taxonomy):

| Command | Purpose |
|---|---|
| `/agentic-dev:pickup #N` | Execute a `readiness:ready` issue end-to-end, headless: DoR re-check → branch → implement → verify → draft PR → blind review |

**Setup:** `/agentic-dev:init` — guided one-time bot-credential onboarding (create or wire the token, verify, store). See **Bot identity & setup** below.

## Prerequisites

- **GitHub CLI (`gh`)**, authenticated — the transport for every GitHub operation. Note: **write** operations run as a configured *bot account*, not your personal login — see **Bot identity & setup** below.
- **AgentSpec plugin** (preferred, not required) — when installed, `a2a-workflow` uses `agentspec:sdd-workflow` as the implement engine (P5) and `agentspec:architect:the-planner` for P1 analysis, giving richer multi-phase SDD workflows. Without it, the plugin falls back to the bundled `plugin/agents/the-planner.md` (drives both P1 analysis and P5 planning) and `plugin/agents/codebase-explorer.md` (recon). All standalone building-block skills (`create-issue`, `publish-issue`, etc.) work without AgentSpec regardless.

## Installation

```text
/plugin marketplace add Future-Gadgets-AI/cc-plugins
/plugin install agentic-dev@cc-plugins
```

## Bot identity & setup

Every GitHub **write** (issues, PRs, comments, commits, pushes) is attributed to a configured **machine account**, not your personal `gh` login — so autonomous work shows up as the bot. This is **mandatory and fail-fast**: the write skills stop with an error if the bot can't be assumed; they never fall back to your personal account. (`review-pr` is the exception — a review is your own act and uses your `gh` identity.)

**The easy way — `/agentic-dev:init`:** run it and it walks you through creating or wiring the bot's token (catching the common resource-owner and permission traps), verifies it works, and stores it. The manual steps below are what it automates.

One-time setup stores the bot's fine-grained PAT outside any repo (`~/.config/agentic-dev/credentials`, chmod 600):

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/setup-bot.sh \
  --from-env <path/to/.env with GITHUB_PAT=...> \
  --login <bot-login> \
  --probe-repo <org>/<repo>
```

The PAT must be **fine-grained** with **Resource owner = your org** (approved by an org owner if required) and **Contents + Pull requests + Issues = write** — otherwise `gh api user` succeeds but push/PR calls 403. Setup verifies the token resolves to the bot and probes those permissions. The reviewer pair requested on every PR is configurable via `AGENTIC_REVIEWERS`. Full protocol: `git-collaboration` → **Bot identity**.

## Usage

- **Quick GitHub action:** `/agentic-dev:create-pr`, `/agentic-dev:create-issue`, etc. — invoke the building block you need.
- **Full bug flow:** `/agentic-dev:fix-bug <description>` — runs the gated issue → PR engine end to end (richer with AgentSpec; falls back to the bundled agents without it).
- **Autonomous execution:** `/agentic-dev:pickup #N` — take a `readiness:ready` issue to a review-ready **draft PR** unattended (the human refines issues before, and merges after).

## Credits

The `the-planner` agent is adapted (and trimmed for this plugin) from the upstream [the-planner.md](https://github.com/luanmorenommaciel/agentspec/blob/main/.claude/agents/architect/the-planner.md) in the AgentSpec project.

The `codebase-explorer` agent is adapted (and trimmed for this plugin) from the upstream [codebase-explorer.md](https://github.com/luanmorenommaciel/agentspec/blob/main/.claude/agents/dev/codebase-explorer.md) in the AgentSpec project.

## License

MIT
