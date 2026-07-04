# Implement — Build Report Summary (the normalized handback contract)

The shape `implement` returns to its caller, regardless of which SDD plugin produced the underlying native artifacts. The native `DESIGN_<SLUG>.md` and `BUILD_REPORT_<SLUG>.md` remain the full record and get committed as-is (`SKILL.md` → **Artifact placement**); this is the short, plugin-agnostic contract the composer actually reads to drive its own G2 verify/smoke gate and the PR body — so it doesn't need to know any given SDD plugin's native report format.

## Structure

```
## Implement report — issue #<N>

| Field | Value |
|---|---|
| Status | Complete \| Blocked \| In Progress |
| Blocked at | Step 0 (pre-check) \| design \| build \| — |
| Feature slug | <SLUG> |
| Resolved entrypoints | design=<name> · build=<name> |
| Design artifact | `.claude/sdd/features/DESIGN_<SLUG>.md` |
| Build report (native) | `.claude/sdd/reports/BUILD_REPORT_<SLUG>.md` |
| Files changed | <count, backed by `git diff --stat`> |

**Method:** SDD design+build (<design entrypoint> -> <build entrypoint>)

**Autonomous decisions:** <pulled from the native report's table, or "none">

**Blockers:** <pulled from the native report's table, or "none">

**Acceptance tests:**

| ID | Scenario | Status | Evidence |
|---|---|---|---|
| AT-001 | <from the synthesized design-input> | Pass / Fail | <how verified> |

**Deviations from design:** <or "none">
```

## Rules

- **A Blocked report is a valid, complete return — not a failure of this skill.** The pre-check stopping at Step 0 and a build hitting a CRITICAL risk both return this same shape, with `Status: Blocked`, a filled `Blocked at`, and the specific blocker named. The caller (composer) decides whether that becomes a GitHub escalation (`status:needs-decision`) — `implement` itself makes no GitHub writes.
- **Never round up.** A Blocked build, a failed acceptance test, or a partially-complete file manifest is reported as such — the caller's G2 gate and the eventual blind review both re-derive this independently and will catch an inflated status.
- **`Files changed` is evidence, not a claim** — back it with `git diff --stat` (or equivalent) output, not a description.
- **`Resolved entrypoints` names what Step 0 actually found**, not a plugin you expected to find — this is the field a reviewer checks when the `Method:` line looks unfamiliar.
