---
description: Cross-repo digest of everything waiting on you — reviews, decisions, in-progress work, ready-to-pull issues, and drafts to refine
argument-hint: [owner]
---

# /needs-me — what needs the human right now

The morning-standup digest for the whole plate: one read-only pass over live GitHub state, grouped from "needs you now" to "state of the line." Replaces opening every repo and scanning its board by hand.

**Read-only, always.** Runs as **you** — your own `gh` authentication — never the bot/automation identity (this command makes no writes, so it must never assume the automation account). Results are naturally scoped to whatever you can already see.

## What it reports

1. **Needs your review** — open PRs requesting review from a configured human reviewer.
2. **Needs your decision** — issues labelled `status:needs-decision` (escalated).
3. **In progress** — issues labelled `phase:in-progress`.
4. **Ready to pull** — issues labelled `readiness:ready`.
5. **Drafts to refine** — issues labelled `readiness:draft` or `readiness:needs-refinement`.

The automation account (`GITHUB_LOGIN`) is never reported as "needs you" — see `plugin/scripts/needs-me.sh` for how.

## Run it

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/needs-me.sh" $ARGUMENTS
```

Present its stdout verbatim as your reply — it is already a complete, grouped Markdown digest (repository · number · title · URL · age per line, per-group counts, empty groups shown as empty rather than omitted-as-error). Pass an owner login (org or user) as `$ARGUMENTS` to override auto-detection of the current repo's owner; omit it to auto-detect.

If the script prints `WARN` lines on stderr (a single query failed, or no `AGENTIC_REVIEWERS` is configured on this machine), surface them alongside the digest — don't swallow them silently.
