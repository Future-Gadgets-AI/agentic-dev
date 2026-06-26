# CLAUDE.md — developing the agentic-dev plugin

> **This file is for developing the plugin itself — it is NOT a distributed plugin component.** Claude Code does not load a plugin's `CLAUDE.md` into a consumer's session; it applies only when working *inside this repo*. Consumer-facing surface = `README.md` + `ARCHITECTURE.md` + the `skills/` · `agents/` · `commands/` · `contracts/`. Keep the separation: **dev guidance here; product there.**

## What this is
`agentic-dev` is a Claude Code plugin that runs a **lights-out ("dark factory") development workflow** — turn a GitHub issue into a verified, review-ready PR, with AI agents doing the line work and humans at the boundary (authoring + approving). **Read `ARCHITECTURE.md` first** — it's the design-of-record.

## The vision (why we're building this)
- **The issue is the spec. GitHub is the state store. Sessions are stateless workers.** Any session resumes any issue from its GitHub state; deferred work is a *draft issue*, not a TODO. (ADR-0001)
- **Humans author + approve; the line between runs autonomously.** Authoring entrypoints create work; the agentic entrypoint `/pickup #N` (planned, #12) consumes it — *issue-only*. (ADR-0002)
- Grow it **bottom-up** into a fully autonomous, observable, guard-railed factory — see the backlog (#12–#20). Refactoring earlier decisions is expected, not a failure.

## Canonical sources — point at these, don't duplicate
- **`ARCHITECTURE.md`** — how the system works *now*.
- **ADRs** — *why* (decision history), published as `type:adr` issues on the repo.
- **`contracts/`** — canonical machine-loadable rules: `lifecycle.md` (issue state machine), `dor-rubric.md` (Definition-of-Ready gate), `labels.md` (label scheme).

## How we work in this repo (dogfood the workflow)
1. **Work from an issue** (the spec). No issue → author one first (`/create-issue`, `/create-adr`).
2. **Branch** `<type>/<slug>` off `main`, **push immediately**; never commit to `main`.
3. **Build in chunks**, pushing each that passes the gates (phased delivery).
4. **Smoke gate** — no PR without an executed test + a real smoke of the change (captured transcript); shadow-trick for paid/destructive paths.
5. **PR** via `create-pr`, linking the issue/ADRs; request both reviewers.
6. **Blind review** — an independent, *blind* agent (fresh context, **isolated in its own clone — not a fork, not the shared tree**) re-runs the test plan and comments as the bot.
7. **The human merges. Always.**

## Conventions
- **GitHub writes run as the bot** (`source scripts/bot-auth.sh` → komiko-bot); fail-fast, never a personal account. Reviewers come from `AGENTIC_REVIEWERS`.
- **Conventional commits**; end with the Claude co-author trailer.
- **Component taxonomy** (ADR-0005): `commands/` = entrypoints/orchestration · `skills/` = capabilities (loadable) · `agents/` = roles (single-responsibility, body ≈ a system prompt) · `contracts/` = canonical rules. **Pick by role, not by folder.**
- **Labels**: validate against the live repo before applying; **never auto-create** (scheme = `contracts/labels.md`).
- **Enforcement honesty**: the gates are *prompt-honored forcing functions*, not hook-enforced. Never call them "enforced" until a hook makes them so.

## Hard-won lessons (don't relearn these)
- **Parallel forks share the working tree.** A fork given full context + a loose task *derails* (one re-created the foundation issue + a branch and committed under the main run). Give forks **trimmed briefs**, not the whole session; **isolate read-only workers in a fresh clone**.
- **Bootstrap honesty**: when `/pickup` doesn't exist yet, hand-walk its role and *say so* — flag real-tool vs hand-executed steps.
- **Distrust a tidy subagent report** — verify against `git`/`gh` ground truth before believing (or repeating) it.

## Backlog = the roadmap
Draft issues on the board: `/pickup` #12 (headline) · `/create-epic` #13 · component migration #14 · hook enforcement #17 · observability #18 · GitHub Projects board #19 · guardrails #20. Validate `/pickup` by **dogfooding it on the "add Mandarin" feature** — it stresses the autonomy gate, which the foundation work didn't.
