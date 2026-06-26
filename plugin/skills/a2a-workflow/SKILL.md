---
name: a2a-workflow
description: The shared engine behind /fix-bug and /implement-feature — drives a bug or feature end-to-end through the two-person A2A workflow (understand → clarify → issue → branch → implement → verify → PR → blind-review), delegating each step to the existing A2A skills. Use whenever the user wants a bug fixed or a feature implemented through the real issue/branch/PR flow (not just a quick edit), or invokes /fix-bug or /implement-feature. Also the reference for the phased-delivery rhythm and the four quality gates.
---

# A2A Workflow — autonomous issue → PR engine

**This is an orchestrator. Do NOT re-implement issue/ADR/PR mechanics — call the skill that owns each step.** Its only original content is the four quality gates and the phased-delivery rhythm; everything else is delegation. Usually reached through the thin wrappers `/fix-bug` and `/implement-feature` (they set the bug-vs-feature specifics); this engine runs the shared flow.

The whole point: turn "fix this" / "add this" into a **well-formed issue, a verified change, and a PR a human can merge fast and confidently** — with the carefulness (clarify, expand, ripple, smoke) *forced* by gates rather than left to chance.

## What it delegates to

| Step | Owned by |
|---|---|
| Requirement analysis, recon | `the-planner` (preferred: AgentSpec `agentspec:architect:the-planner`; fallback: bundled `agents/the-planner.md`) + read-only subagents |
| Draft the issue / ADR | `create-issue` / `create-adr` |
| Publish + label + relate | `publish-issue` (label scheme: `contracts/labels.md`) |
| Implement | `agentspec:sdd-workflow` (preferred, requires AgentSpec) or `the-planner` + `codebase-explorer` + subagents (fallback — both bundled in `agents/`) |
| Open the PR | `create-pr` |
| The A2A model, branching, commits | `git-collaboration` (reference) |

The four gates (◆) and the phased rhythm are this skill's own — detailed in `assets/`.

## The run (P0 → P8)

Deliver each artifact **as its phase completes** — never hoard everything to the end (see `assets/phased-delivery.md`). The shared remote is the A2A surface; a collaborator should see progress.

- **P0 · INTAKE** — parse the request; detect the repo (`gh repo view --json nameWithOwner -q .nameWithOwner`); load `CLAUDE.md` + `memory/`. Restate the request as **verifiable success criteria** before touching code.
- **P1 · UNDERSTAND + EXPAND + RIPPLE** — `the-planner` for analysis (preferred: `agentspec:architect:the-planner`; fallback when AgentSpec is not installed: bundled `agents/the-planner.md`); run the **6 expansion lenses** (`assets/expansion-lenses.md`) and the **ripple scan** (`assets/ripple-scan.md`); read-only recon via subagents. Reproduce first for a bug.
- **◆G1 · CLARIFICATION GATE** — classify each open question STOP / ASSUME / SPLIT by reversibility × blast-radius (`assets/clarification-gate.md`). A healthy run fires **0–1** blocking questions; >2 ⇒ the request is underspecified — say so.
- **P2 · DRAFT ISSUE** (+ ADR iff architecturally significant) — `create-issue` / `create-adr`. Persist the expansion output as `## Scope & interpretation`. **Review it for quality, then publish** when satisfied.
- **P3 · PUBLISH** — `publish-issue` (dedup, self-containment lint, label validation against the **live repo** — reconciled to the kb scheme — with the HITL no-auto-create rule, native sub-issues, assignee for ownership).
- **P4 · BRANCH** — `<type>/<slug>` (`fix/…`, `feat/…`), never `main`. **Push the branch immediately** (as the bot — `source ${CLAUDE_PLUGIN_ROOT}/scripts/bot-auth.sh` at the top of the block) — nothing to review, and it makes the work visible.
- **P5 · IMPLEMENT** — `agentspec:sdd-workflow` as the preferred engine (requires AgentSpec plugin); fallback when AgentSpec is not installed: bundled `agents/the-planner.md` for planning + bundled `agents/codebase-explorer.md` for recon + read-only subagents. Work in **chunks**; after each chunk that passes G2, **commit (conventional) + push**.
- **◆G2 · VERIFY / SMOKE GATE** — run the tests **and** a real smoke of the changed path; demonstrate the specific behavior. No "done" without it (`assets/verify-gate.md`). Includes the **shadow trick** for paid/destructive paths (prove the guard fires with zero spend).
- **P6 · PR** — draft → self-review → publish via `create-pr` (structured body; **links the issue/ADR** — mandatory).
- **P7 · BLIND REVIEW** — spawn an **independent blind subagent** (fresh context, *not* a fork) that runs the PR's test plan, reviews the diff, and **posts findings as a PR comment** (as the bot) tagging both devs (`assets/blind-review.md`). Address blocking findings → push. This is *not* the human merge and *not* the other agent's `review-pr`.
- **P8 · REPORT** — request **both** configured reviewers (mechanism in `create-pr`); emit the final report (`assets/final-report.md`): issue#, PR#, assumptions, ripple, **smoke evidence**, blind-review verdict, residual risk.

> The workflow never self-runs `review-pr` — that's the *other* person's agent. **The human merges.**

## The four quality gates (what the suite lacks)

1. **Clarification gate (G1)** — STOP-ask vs ASSUME-document vs SPLIT-off, keyed to reversibility × blast-radius, *not* model confidence. Stops both over-asking and silent wrong assumptions.
2. **Adversarial expansion (P1)** — 6 lenses that surface the hidden set behind a request ("Chinese" = simplified + traditional; "add X for A" ⇒ what about A's siblings?). An empty lens answer is a failure, not a pass.
3. **Ripple / blast-radius (P1)** — find siblings that branch on the same axis; decide in-scope vs SPLIT; record what you deliberately did *not* change and why.
4. **Verify / smoke gate (G2)** — a non-skippable, *executed* test + smoke with a captured transcript. The one gate that catches "it compiles, ship it."

These are forcing functions. The model is smart enough to do them when prompted — the gates make sure it always is.

## Interactive vs headless — same flow, one difference

The only thing that changes is how a **BLOCKING** question resolves:
- **Interactive:** `AskUserQuestion`.
- **Headless** (Agents view / cron): record under `## Open decisions (needs human)`, label `needs-decision`, @-mention the decider, proceed on the best documented assumption, and open the **PR as a draft**. The P7 blind-review still runs and posts — the humans read it on return.

Default for headless until trust is earned: **draft PR always**.

## Guardrails

- **Run as the bot.** Every GitHub write this engine drives — branch, commit, push (P4–P6), the issue/PR (via `publish-issue` / `create-pr`), and the P7 blind-review comment — is attributed to the configured machine account: source `${CLAUDE_PLUGIN_ROOT}/scripts/bot-auth.sh` at the top of each write block, **fail-fast** if it can't assume the bot, and **never** fall back to a personal `gh` login (`git-collaboration` → **Bot identity**). `review-pr` (the human's own review) is the lone exception.
- **Orchestrate, don't re-implement.** If you're writing `gh issue create` by hand, you've skipped `publish-issue`. Call the owning skill.
- **No "done" without G2 evidence.** A `Smoke evidence:` transcript is required in the report; a blocked smoke ⇒ draft PR + `## Verification: BLOCKED`.
- **Never invoke a paid/destructive path to "test" it.** Use the shadow trick (`assets/verify-gate.md`).
- **The human merges.** Agents author, verify, and review; a person clicks merge.
- **Process quality is guaranteeable; taste is not.** The job is to make the human's merge review fast and well-informed — not to replace it.
