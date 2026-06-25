# P8 — Final Report

The run's closing artifact. It exists so the human can merge **fast and well-informed** — every field is there to shorten their review, not to celebrate the work.

## Structure

```
## <type>: <one-line outcome>

| Artifact | Link / status |
|---|---|
| Issue   | #N — <labels> |
| Branch  | <name> (pushed) |
| PR      | #M — <draft? · assignees · reviewers> |

**What changed:** <2–3 lines>

**Assumptions (review these):** <the ASSUME-bucket decisions, or "none">
**Open decisions (needs human):** <BLOCKING items left documented, or "none">
**Ripple:** <what else changed / what deliberately didn't + why>

**Smoke evidence:**     ← REQUIRED — a real transcript, not a claim
<the captured test + smoke output, including exit codes>

**Blind review (P7):** <verdict + PR-comment URL>
**Residual risk:** <where a reviewer should look hardest; or "none material">
```

## Rules

- The **`Smoke evidence:`** block is mandatory and must be a real transcript. If verification was blocked, it becomes `Verification: BLOCKED — <reason>` and the PR is a **draft**.
- Keep it scannable — tables + short lines. The reviewer reads this to decide *where to look*, not to re-derive the work.
- **State outcomes faithfully.** A deferred acceptance criterion is named as deferred; a skipped step is named as skipped; tests that failed are shown with their output. Never round "5 of 6 verified" up to "done."
