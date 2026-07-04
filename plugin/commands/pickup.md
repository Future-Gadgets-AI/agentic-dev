---
description: Execute a ready issue end-to-end — DoR re-check, branch, implement, verify, draft PR, blind review
argument-hint: [issue-number]
---

# /pickup — execution composer

Execute one `readiness:ready` GitHub issue from the current repo through the autonomous leg of the lifecycle (`${CLAUDE_PLUGIN_ROOT}/contracts/lifecycle.md`): branch → implement → verify → draft PR → blind review. Humans author issues and merge PRs; everything between is yours. This command owns only the sequencing and the entry/exit conditions — every action belongs to the skill, contract, or script named at each step.

Run headlessly: never pause to ask permission mid-chain. When a step cannot honestly proceed, write its state to the issue as a bot-attributed comment and stop cleanly — the issue is the ledger, and a later session resumes from it.

Identity: every git/gh write runs as the bot — in each Bash block that writes, first `source "${CLAUDE_PLUGIN_ROOT}/scripts/bot-auth.sh" || exit 1` (fail-fast; never fall back to a personal account). Reads need no bot identity.

## Entry conditions — refuse before touching anything

Target: issue `$ARGUMENTS` (tolerate a leading `#`). Refusals are replies to the invoker; they write nothing to GitHub.

- No argument → refuse: execution is issue-only (the issue is the spec, per ADR-0001). Reply with usage `/pickup #<issue>` and stop.
- Fetch the issue (`gh issue view <N> --json title,body,labels,comments`). Nonexistent or closed → refuse.
- `type:epic` → refuse: epics decompose into sub-issues; they are never executed directly.
- `type:spike` or `type:adr` → refuse: their deliverables (knowledge, a decision) don't fit this branch→PR path; say so. v1 routes `type:feature`, `type:task`, and built-in `bug` down the one shared path below.
- Missing `readiness:ready` → refuse: the ready label is the autonomy gate (ADR-0004). Point the human at `/refine-issue`.

## The chain

Each step names its owner. A step that fails or returns Blocked: post its report as a bot comment on issue #N, leave the labels as they truthfully stand, and stop — do not improvise recovery (mid-flight escalation machinery is deliberately deferred), and never round a Blocked result up to done.

1. **Pull-time DoR re-check** — grade the issue against `${CLAUDE_PLUGIN_ROOT}/contracts/dor-rubric.md`; this guards against a stale `ready` label. READY → proceed. READY-WITH-LOGGED-ASSUMPTIONS → proceed, carrying each logged assumption into the PR body. NOT-READY → relabel `readiness:ready` → `readiness:needs-refinement`, comment the failing dimensions as targeted questions or explore-directives (bot), stop.
2. **Phase: in-progress** — validate against the live label set (`gh label list`; never create a label), then move the issue's `phase:` label to `phase:in-progress` (bot).
3. **Branch** — from an up-to-date `main`: `<type>/<short-kebab-slug>` (conventional-commit type — feat, fix, chore, docs, refactor), pushed immediately with `-u` (bot). The composer owns branch creation; the create-pr skill's own branch step no-ops later.
4. **Implement** — load this plugin's `implement` skill in composed mode: DoR is already re-checked, so hand the issue's content straight through. It expects to already be on the branch and returns a build-report summary; `Status: Blocked` → the uniform failure path above.
5. **Verify / smoke gate** — apply `${CLAUDE_PLUGIN_ROOT}/skills/a2a-workflow/assets/verify-gate.md`: executed tests plus a real smoke of the changed path, captured as a `Smoke evidence:` transcript; shadow paid/destructive paths per its stub rule. Genuinely unrunnable → continue, but the PR carries its `## Verification: BLOCKED — <reason>` section; never report green what didn't run.
6. **Version bump** — if the repo ships a Claude plugin (a `.claude-plugin/plugin.json` manifest) and shipped plugin files changed, bump its `version` per the change's nature.
7. **Open the PR** — load the `create-pr` skill. Draft is the headless default — the human flips it ready. The body must close issue #N (`Closes #N`), carry the logged assumptions from step 1, and embed the `Smoke evidence:` block in its test plan.
8. **Phase: review** — move `phase:in-progress` → `phase:review` (bot).
9. **Blind review** — run `${CLAUDE_PLUGIN_ROOT}/skills/a2a-workflow/assets/blind-review.md` exactly: a fresh general-purpose subagent (never a fork), working in its own fresh clone (never this working tree), re-running the PR's test plan and commenting on the PR as the bot. Handle its findings per that asset: blocking → fix on the branch, push, reply on the PR.
10. **Request reviewers** — `bash "${CLAUDE_PLUGIN_ROOT}/scripts/request-reviewers.sh" "<owner/repo>" <PR#>` (it self-sources bot auth). Report a `MISSING:` result; don't hide it.

## Exit

Reply with a compact run report: issue, verdict trail (DoR → implement → verify → blind review), branch, PR URL and draft status, blind-review comment URL, assumptions logged, anything Blocked. The merge is the human's — never merge, and never mark the draft ready yourself.
