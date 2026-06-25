---
name: git-collaboration
description: Best-practices reference for the two-person agent-to-agent git workflow — the A2A model, the issue/ADR memory ledger, the self-containment principle, the simple main+feature gitflow, branch naming, conventional commits, the label scheme, and when to use an Issue vs an ADR vs a PR. Use when the user asks how the collaboration works, "how do we work together", which artifact to create, branch/commit conventions, or for an overview of the git workflow. Cross-references the action skills (create-issue, create-adr, publish-issue, create-pr, review-pr).
---

# Git Collaboration — Two-Person A2A Workflow

The reference for how the two developers collaborate across repos. This skill is the **map**; the action skills do the work:

| Skill | Does |
|---|---|
| `create-issue` | Drafts a self-contained issue from a per-type template. |
| `create-adr` | Drafts an Architecture Decision Record (with the worthiness gate). |
| `publish-issue` | Publishes a drafted issue **or** ADR to the current repo's GitHub, with guardrails. |
| `create-pr` | Turns a feature branch into a conventional commit + a structured PR addressed to the reviewer's agent. |
| `review-pr` | The A2A review protocol: checkout, run tests, check acceptance criteria, comment approve/request-changes. |

## The A2A model — write for an agent who has none of your context

Two developers collaborate, **each driving their own coding agent**. The collaboration is **agent-to-agent (A2A)**: one person's agent *authors* a GitHub artifact (issue, ADR, PR body); the **other** person's agent *reads, explains, and reviews* it.

The consequence drives everything below: **every artifact must be self-contained.** The reviewing agent has **zero** shared session context — no memory of your chat, your local paths, your half-finished reasoning. If the artifact isn't fully understandable on its own, the A2A loop breaks.

> **Self-containment test.** Would a developer who has never seen your session, your machine, or your scratch notes understand this artifact completely? If not, it leaks context.

What leaks context (strip it):
- Local paths (`/Users/...`, `src/...`), machine-specific details.
- References to "the thing we discussed", "as planned earlier", or any private session state.
- Bare numbered references from your own notes (your personal "item #4" can read as a link to a real issue `#4`).
- Internal codenames, nicknames, or shorthand only the two of you share.

## The memory ledger — issues + ADRs are durable

Issues and ADRs are the project's **append-only memory ledger** for both agents. They survive sessions, machines, and `/clear`.

- **Close, never delete.** Deleting destroys history and cross-references. A redundant or superseded issue is **closed with a one-line pointer** to the canonical one, staying searchable.
- **Decision lifecycle.** ADRs move `Proposed → Accepted / Rejected → Superseded / Deprecated`. A rejected decision **stays on record** so it isn't re-litigated later.
- **One topic per issue.** Dedup before posting. Three issues on one subject is disorganization — consolidate, or use sub-issues under a parent.

## When to use an Issue vs an ADR vs a PR

| Artifact | Purpose | Use when |
|---|---|---|
| **Issue** | A unit of work or a tracked report. | You want to capture a feature, task, bug, spike, or epic to be done. → `create-issue` |
| **ADR** | A durable record of one architecturally significant decision + its trade-offs. | A choice is **expensive to reverse** and a future contributor will need the *why*. → `create-adr` |
| **PR** | An A2A message proposing a change, addressed to the other agent. | You have code on a feature branch implementing an issue/ADR and want it reviewed + merged. → `create-pr` |

Quick rule: **work to do → Issue. Decision to remember → ADR. Code to merge → PR.** A capability that needs an architecture decision becomes an Issue **plus** a linked ADR — don't bury the decision inside the issue body.

See `create-adr` for the full **worthiness gate** (don't inflate the ledger with trivial decisions).

## PRs are A2A messages — the human merges

A PR is the author agent's message to the reviewer agent:

1. **Author's agent** writes the PR body — summary, key changes, test plan, and the **Issue or ADR it implements** (linking the source is mandatory). → `create-pr`
2. **Reviewer's agent** fetches the branch, reads the linked Issue/ADR's acceptance criteria, **runs the tests**, reviews the diff, and posts a structured review: **approve** or **request-changes** with specific items. → `review-pr`
3. **The human does the final merge.** Agents review and recommend; a person clicks merge.

> **Reviewer caution.** Both agents may be the *same model*, so they can share blind spots. The reviewer defaults to **skepticism** and requires **evidence** (tests pass, acceptance criteria met) before approving. Never rubber-stamp.

## Bot identity — the action skills run as the machine account

Every GitHub **write** in the action skills runs as one configured **bot account**, never a personal `gh` login — autonomous work is attributed to the bot. This covers `publish-issue`, `create-pr`, the P7 blind-review comment, and the branch/commit/push steps `a2a-workflow` drives. (`review-pr` is the exception: it's the *counterparty's* review and runs as the reviewer's own identity.)

**Single source of truth.** At the top of every git/gh write block, the skill sources one helper:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/bot-auth.sh" || exit 1
```

It resolves the bot token, **verifies the token actually belongs to the expected bot**, and — for that shell only — exports `GH_TOKEN` (so `gh` *and* `git push` act as the bot), ephemeral `GIT_AUTHOR_*`/`GIT_COMMITTER_*` (so commits are authored by the bot *without* writing the identity into the repo's git config), and `AGENTIC_REVIEWERS`.

**Fail-fast, no fallback.** If the bot can't be assumed — missing credentials, or the token resolves to the wrong account — the helper prints an actionable error and returns non-zero, and the skill **stops**. It must **never** fall back to a personal `gh` account. Acting as the wrong identity is the precise failure this guards against, so there is no "degrade gracefully" path here by design.

**Defense in depth (the hook).** A `PreToolUse` hook (`hooks/`) backstops a forgotten `source`: it denies any git/gh **write to the bot's org** that isn't routed through `bot-auth`. Two things to understand about its scope: it governs **only commands Claude Code runs through its Bash tool** — your own terminal, GitHub Desktop, IDE git, and CI are never touched — and it fails *open* on ambiguity (it's a backstop, not the primary mechanism). `gh pr review` is exempt; append `# agentic:allow-ambient` to a command for a deliberate non-bot write.

**One-time setup** (stores the PAT outside any repo, chmod 600):

```bash
scripts/setup-bot.sh --from-env <path/to/.env with GITHUB_PAT=...> \
  --login <bot-login> --probe-repo <org>/<repo>
```

Setup verifies the token is the bot and probes the fine-grained-PAT gotcha — a token can pass `gh api user` yet **403** on push/PR if it lacks org resource-owner approval + Contents / Pull requests / Issues write. Config keys (env vars, or the credentials file): `GITHUB_PAT` (required) · `GITHUB_LOGIN` (expected account) · `GITHUB_NAME`/`GITHUB_EMAIL` (commit identity; derived if absent) · `AGENTIC_REVIEWERS`. **Never** echo the token or commit the credentials file.

## Gitflow — simple: main + short-lived feature branches

- **`main`** is the only long-lived branch. It is always releasable.
- **Never commit straight to `main`.** Every change goes through a short-lived branch and a PR.
- **No `develop` branch, no heavy ceremony.** Branch → commit → PR into `main` → human merges → delete branch.

### Branch naming

`<type>/<short-kebab-description>` — type matches the conventional-commit type:

| Prefix | For |
|---|---|
| `feat/` | a new capability |
| `fix/` | a bug fix |
| `chore/` | maintenance, deps, tooling |
| `docs/` | documentation only |
| `refactor/` | restructuring with no behavior change |

Examples: `feat/oauth-refresh`, `fix/null-date-parse`, `docs/readme-setup`.

### Conventional commits

`<type>(<scope>): <description>` — present tense, concise (< 72 chars), **scope = the component/area touched**.

```
feat(parser): add ISO-8601 date support

- handle timezone offsets
- fall back to UTC when offset is absent

Co-Authored-By: Claude <noreply@anthropic.com>
```

Types: `feat` · `fix` · `refactor` · `docs` · `test` · `chore` · `style` · `perf` · `ci` · `build`.

## Label scheme

Labels are applied directly on the issue (no `Labels:` line in the body). Four namespaces (canonical source: `skills/a2a-workflow/assets/issue-labels.md`):

| Namespace | Values | Meaning |
|---|---|---|
| `type:` | `feature` · `task` · `bug` · `spike` · `epic` · `adr` | The kind of work. Exactly one per issue. |
| `priority:` | `high` · `medium` · `low` | high = now/blocking · medium = soon · low = backlog. |
| `status:` | `blocked` · `needs-decision` | `blocked` = waiting on something (name it in a comment) · `needs-decision` = awaiting a call (@-mention the decider). |
| `phase:` | `triage` · `in-progress` · `review` · `done` | Current position in the a2a-workflow engine. Applied/updated by `fix-bug` / `a2a-workflow`; mutable as the issue progresses. |

Rules that keep the scheme honest:
- **Validate labels against the repo at runtime** (`gh label list`) before applying — the live repo is the truth, this table is the intent.
- **Human-in-the-loop for missing labels.** If a label here doesn't exist in the repo, surface it and ask the human — **never auto-create** labels.
- **Ownership = GitHub assignee**, not a label. A person's identity survives reshuffles; a label rots.
- **Grouping = native parent/sub-issue relationships**, not prose `#NN` mentions in the body.

## Repo detection — works in any repo

These skills target **whatever repo you're currently in**, never a hardcoded one:

```bash
gh repo view --json nameWithOwner -q .nameWithOwner   # preferred
git remote get-url origin                             # fallback
```

## The roles

A collaboration between human maintainers and a bot. The actual GitHub accounts are **configured per install** (in the bot credentials file written by `init` / `setup-bot.sh`), never hardcoded here:

- **Human maintainers** — the people who review and merge; their logins are in `AGENTIC_REVIEWERS`. Use them for `--assignee` and for @-mentions when a decision needs a person.
- **Machine account (autonomous author)** — the bot identity that authors writes, stored as `GITHUB_LOGIN`.

The bot authors; the human maintainers review and merge. To change who's involved, edit the credentials file (see **Bot identity** above) — nothing here is tied to specific people.
