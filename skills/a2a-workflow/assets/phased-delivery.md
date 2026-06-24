# Phased Delivery — deliver each artifact as its phase completes

The rule: **don't hoard.** Ship each phase's artifact to the shared remote the moment that phase is done — don't do all the local work and reveal everything at the end. The remote is the A2A surface; the other person (and their agent) should watch the work land, not get one big drop.

This is **not** "push earlier." It's *phase-by-phase* delivery — each artifact reviewed (where there's something to review) and published as it becomes ready.

## The rhythm

| When | Deliver |
|---|---|
| Issue drafted | **review it** → publish when satisfied (`publish-issue`). |
| Branch created | **push it immediately** — nothing to review. |
| Each implementation chunk | passes G2 (verify) → **commit + push** that chunk. |
| PR drafted | **review it** → publish when satisfied (`create-pr`). |
| PR published | spawn the **blind-review** pass → it comments on the PR. |
| Done | add the other dev as reviewer → final report. |

## Why

- **Visibility.** The other person sees progress on the remote and can course-correct early, instead of facing a finished wall at the end.
- **Smaller, safer steps.** A pushed chunk is a *verified* chunk — the branch never hides a big pile of unvalidated work.
- **A2A + backup.** The remote is where the other agent reads your work; local-only work is invisible to the collaboration.

## What NOT to do

- ❌ Do all the work locally (issue + branch + commits + PR) and push everything at the very end.
- ❌ Push a branch full of unverified chunks "to save time" — each pushed chunk should have passed G2.
- ✅ Issue published when ready · branch pushed at creation · each verified chunk pushed · PR published when ready · blind-review posted · reviewer added.
