---
name: refine-issue
description: Refines a `readiness:draft` or bounced `readiness:needs-refinement` GitHub issue up to `readiness:ready`: grounds it against the repo, applies the Definition-of-Ready rubric, resolves the gaps the codebase can answer itself, asks the human only for genuine intent gaps, rewrites it self-contained, and flips the label — auto, within blast-radius bounds. The human-side mirror of `/pickup`'s autonomy gate. Use when the user wants to refine, ready, grade, or flesh out a draft issue, DoR-check it, or prepare the board's drafts for autonomous pickup. Authoring a brand-new issue is create-issue; executing a ready one is /pickup.
---

# Refine Issue

Turns a **`readiness:draft`** issue into a **`readiness:ready`** one: ground it, grade it against the Definition of Ready, close the gaps, rewrite it self-contained, and flip the label. The **human-side mirror** of the autonomy gate `/pickup` runs at pull time (ADR-0004) — the same rubric, applied *before* an agent ever pulls the card.

**One responsibility:** make a draft *ready*. Authoring conventions are `create-issue`; the board-write guardrails + bot identity are `publish-issue`; the grading criteria are `contracts/dor-rubric.md`. This skill **applies** that rubric — it does **not** restate it (single source, shared with `/pickup` #12).

## Detect the repo first (never hardcode)
```bash
gh repo view --json nameWithOwner -q .nameWithOwner   # in-tree → REPO
```
For a **headless or out-of-tree** run that targets a specific issue in a repo you are not inside, take `OWNER/REPO` from the invocation and pass `--repo OWNER/REPO` on **every** `gh` call (view, label edit, comment) — do not rely on the working directory.

## Flow

1. **Fetch the draft.** `gh issue view <N> --repo REPO --json title,body,labels`. This skill refines `readiness:draft` and bounced `readiness:needs-refinement` issues. **Stop and report why** (don't refine) if the issue is instead: `readiness:ready` (already done), closed, `phase:in-progress`/`review`, or carries no `readiness:` label.
2. **Ground.** Read the issue and explore the repo for the context it leans on. Use read-only recon (subagents / grep / read). Do not guess what the codebase can answer.
3. **Grade.** Apply **`contracts/dor-rubric.md`**: Pass 1 sets the blast-radius bar (GREEN / AMBER / RED); Pass 2 grades D1–D4. Produce the rubric's output — **one of the three verdicts** (READY / READY-WITH-LOGGED-ASSUMPTIONS / NOT-READY) **+ the named gaps** — never an opaque score.
4. **Resolve the gaps.**
   - **Epistemic** (the answer exists in the repo) → find it, fill it into the draft, and **log the fill + its evidence** (path/ref). Never ask the human something the codebase already answers — this is the anti-over-asking valve.
   - **Aleatoric** (intent only the human holds) — **default to auto/headless; take the *Interactive* branch only when a human is actively in the loop**:
     - *Interactive* → ask via `AskUserQuestion`.
     - *Headless / auto* → if the issue is GREEN/AMBER (reversible), proceed on the **most reversible documented assumption** and record it; if the gap is load-bearing on a **RED** issue, do **not** guess — escalate (step 6).
5. **Rewrite + write back** (READY-bound issues only). Rewrite the body self-contained, per `create-issue`'s content rules (zero leaked context, native relationships, one topic, no Labels line) — it must read on its own to the other person's agent — then **persist it**: `gh issue edit <N> --repo REPO --body-file <file>`, as the bot (see Bot identity). A NOT-READY / RED **bounce skips the rewrite** — the body stays human-owned; go straight to step 6.
6. **Flip — map the rubric's verdict (from step 3) to a label** (the write goes through `publish-issue`, as the bot). Do **not** re-derive from D1–D5 — consume the verdict the rubric already produced:
   - **READY** → set `readiness:ready`.
   - **READY-WITH-LOGGED-ASSUMPTIONS** → set `readiness:ready`; record each assumption on the issue.
   - **NOT-READY** → set `readiness:needs-refinement`; post the failing dimensions as a comment; bounce to the human.
   - 🔴 **RED override** (on top of the verdict): a RED issue is **never** auto-readied, even on a READY verdict — its irreversible step must be gated at the harness layer (#17, not built). Set `readiness:needs-refinement` + `status:needs-decision`, post the gaps, @-mention the decider, and stop.
7. **Audit trail.** Whatever the verdict, leave a comment (as the bot) recording: the blast-radius class, the verdict, each epistemic fill + its evidence, and each logged assumption. "Auto" is not "silent" — its decisions stay reviewable (by the human, the board #19, or the recommender #25).

## Bot identity (every board write)
The label flip, the rewritten body, and the audit/escalation comments are GitHub writes — run them as the machine account:
```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/bot-auth.sh" || exit 1
```
Fail-fast; never refine under a personal account. The grounding **reads** don't need it. See `git-collaboration` → **Bot identity**.

## Scope
- **In:** one draft issue, end to end (ground → grade → resolve → rewrite → flip / escalate).
- **Out:** executing the issue (that's `/pickup`, #12); the harness-layer hard gate for RED steps (#17); refining more than one issue at a time (single-issue — loop externally if needed).

## DOs / DON'Ts
**DO:** apply `dor-rubric.md` (don't restate it) · resolve epistemic gaps yourself before asking · keep the human for genuine intent + every RED call · log each fill and assumption · write as the bot.

**DON'T:** auto-ready a RED issue · ask what the repo can answer · leak session context into the rewrite · flip a label under a personal account · restate or fork the rubric.
