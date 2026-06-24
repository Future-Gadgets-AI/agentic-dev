# P7 — Blind-Review Pass

After the PR is published, spawn an **independent, blind** reviewer to run the PR's own test plan and post its findings *on the PR*, tagging both devs. This is the automated first-pass review — separate from the human merge, and separate from the *other* person's agent running `review-pr` later.

## Why blind, why a subagent

- **Blind** = a fresh agent with **no memory of how the change was built** — so it can't rubber-stamp its own reasoning. Use a fresh `general-purpose` subagent, **not a fork** (a fork inherits your context, hence your blind spots).
- It **executes** the test plan rather than trusting the PR's claims — the real backstop against a faked or over-optimistic "verified."

## The spawn (prompt template)

Launch a `general-purpose` subagent:

> You are an INDEPENDENT, BLIND reviewer of PR #<N> on `<owner/repo>`. No prior context — review skeptically on its own merits; do not rubber-stamp; your job is to catch problems.
> Local clone: `<path>`; `gh` is authenticated; the env is set up.
> Use the `review-pr` skill and follow it end to end: `gh pr checkout <N>`; read the PR body + linked issue for the acceptance criteria and the "Test plan"; **actually run** every test-plan item and capture real output; review the diff (`gh pr diff <N>`) for correctness, edge cases, and quality; then post a structured comment via `gh pr comment <N> --body "…"` — **Verdict** (approve / request-changes), **Verified** (each item + evidence), **Concerns**, **Suggestions** — ending with a line tagging @<dev1> and @<dev2> so they're notified.
> ⚠️ ZERO SPEND: never invoke a paid/destructive path against the real binary. Shadow it with a no-op stub on PATH (see the verify gate) to prove a guard fires without paying.
> Report back: verdict, the evidence, and the comment URL.

## After it returns

- **Blocking findings** → fix on the branch, **push** (phased delivery), and reply on the PR noting what you addressed and in which commit.
- **Non-blocking suggestions** → take the cheap high-value ones (e.g. a missing behavioral test); note the rest as follow-ups, or offer to open a `[BUG]`/`[TASK]` for them.
- Then proceed to P8 (add the human reviewer + report). The blind-review **verdict + comment URL** are a field in the final report.

> The blind reviewer never merges — same A2A rule. It recommends; the human decides.
