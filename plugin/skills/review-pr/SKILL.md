---
name: review-pr
description: The A2A review protocol — fetch and checkout the PR branch, read the linked Issue/ADR's acceptance criteria, RUN THE TESTS, review the diff for correctness and quality, then post a structured review comment (approve, or request-changes with specific actionable items) and leave the merge to the human. Use when the user wants to review a PR, check a pull request, respond to the other person's PR, or verify a change before merge. Defaults to skepticism — never rubber-stamps.
---

# Review PR

The protocol for reviewing the **other person's** PR. A PR is an A2A message: their agent wrote it, **your** agent reviews it. Your job is to **verify**, not to trust.

> **Default to skepticism.** Approve only on **evidence**: the tests pass *and* the acceptance criteria are met. The author's agent and yours may be the **same model** — so you can share blind spots. A clean-looking diff is not proof. Run the code; check the claims. The **human does the final merge** — you recommend, you do not merge.

> **Identity.** `review-pr` posts as **your own** GitHub account (the reviewer) — it does *not* assume the bot and has no `bot-auth` step, because a review is the counterparty's act, not the author's. (The bot's *automated* first-pass — P7 blind-review — does post as the bot; see `a2a-workflow` → `assets/blind-review.md`.)

> **Draft status is expected — not a finding.** The autonomous engine opens every headless PR as a **draft** — you're typically reviewing a draft, not a ready-for-merge PR, and that alone is never a reason to request changes or hold off. The human flips it ready and merges at the Ready-to-merge step, informed by your review, never blocked on it (`plugin/contracts/lifecycle.md`).

## Detect the repo first (never hardcode)

```bash
gh repo view --json nameWithOwner -q .nameWithOwner   # preferred
git remote get-url origin                             # fallback
```

## Step 1 — Fetch & checkout the PR branch

```bash
gh pr list --repo REPO                       # find the PR number
gh pr view <n> --repo REPO                    # read the PR body
gh pr checkout <n> --repo REPO                # check out the branch locally
gh pr diff <n> --repo REPO                    # see the full diff
```

## Step 2 — Read the linked Issue/ADR's acceptance criteria

The PR body's **Implements** line points to the source Issue or ADR. Open it and extract the **acceptance criteria / definition of done** — that's the contract this PR must satisfy.

```bash
gh issue view <linked-issue> --repo REPO
```

If the PR links **nothing** and states no inline acceptance criteria → **request changes**: an unanchored PR can't be objectively verified. Ask for the source Issue/ADR or explicit criteria.

> **CI gate — `closing-keyword-gate` (#48):** the body must carry a closing keyword (`Closes`/`Fixes`/`Resolves #NN`) **or** an explicit opt-out (`Implements ADR #NN`, or `[no-close: <reason>]`); a bare `(#NN)` fails it. Confirm the check is green, and if an opt-out was used, sanity-check the stated reason is legitimate.

## Step 3 — RUN THE TESTS (non-negotiable)

Run the test plan from the PR body, plus the project's own suite (`pytest`, `npm test`, `make test`, etc. — whatever the repo uses). Do **not** approve on a read-through alone.

- Tests pass → evidence toward approval.
- Tests fail / are missing / don't actually cover the change → **request changes** with the exact failure output.

## Step 4 — Review the diff (correctness + quality)

Read the diff critically. Check for:

- **Correctness** — does it actually do what the Issue/ADR asked? Edge cases, error paths, off-by-ones, wrong assumptions.
- **Acceptance criteria** — tick each one off against the code. Anything unmet is a blocker.
- **Quality** — clarity, naming, dead code, missing types/docs where the repo expects them, obvious security/perf issues.
- **Scope** — does the PR stay on one concern, or did unrelated changes sneak in?
- **Shared-blind-spot check** — where the author's agent made a *judgment call* (an interpretation of the spec, a default, an "obviously fine" shortcut), look harder: that's exactly where a same-model reviewer tends to nod along. Re-derive it from the Issue/ADR rather than trusting the diff's framing.

## Step 5 — Post a structured review

Use `gh pr review`. Two outcomes:

**Approve** — only when tests pass **and** every acceptance criterion is met:

```bash
gh pr review <n> --repo REPO --approve --body "$(cat <<'EOF'
## Review — Approve

**Tests:** <command(s) run> → all pass.
**Acceptance criteria:** all met —
- [x] <criterion 1>
- [x] <criterion 2>

**Notes:** <optional non-blocking observations>

Recommending merge — leaving the final merge to the human.
EOF
)"
```

**Request changes** — for any failing test, unmet criterion, or correctness/quality blocker:

```bash
gh pr review <n> --repo REPO --request-changes --body "$(cat <<'EOF'
## Review — Request changes

**Tests:** <command> → <what failed, with output>.

**Blocking:**
1. <specific, actionable item — file/function + what's wrong + what to do>
2. <…>

**Acceptance criteria not yet met:**
- [ ] <criterion> — <why it's not satisfied>

**Non-blocking (optional):**
- <nit>
EOF
)"
```

Every requested change must be **specific and actionable** — name the location, the problem, and the fix. "Looks off" is not a review.

## Step 6 — Hand off to the human

Approving signals readiness; it is **not** a merge. State explicitly that the **human does the final merge**. Do not run `gh pr merge`.

## DOs / DON'Ts

**DO:** check out and run the code · run the tests · verify against the linked acceptance criteria · default to skepticism · scrutinize the author's judgment calls (shared blind spots) · give specific actionable feedback · leave the merge to the human.

**DON'T:** approve on a read-through alone · approve with failing/missing tests · approve a PR with no source Issue/ADR and no inline criteria · rubber-stamp because the diff "looks fine" · merge the PR yourself.
