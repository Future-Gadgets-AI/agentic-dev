# BUILD REPORT: ISSUE_34_WHATS_NEEDED_ME

> Implementation report for issue #34 — "What needs me?" cross-repo status report.

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | ISSUE_34_WHATS_NEEDED_ME |
| **Date** | 2026-07-04 |
| **Author** | build phase (`agentspec:workflow:build`, driven by `/pickup`) |
| **DEFINE** | [`../_synthesized/DEFINE_ISSUE_34_WHATS_NEEDED_ME.md`](../_synthesized/DEFINE_ISSUE_34_WHATS_NEEDED_ME.md) |
| **DESIGN** | [`../features/DESIGN_ISSUE_34_WHATS_NEEDED_ME.md`](../features/DESIGN_ISSUE_34_WHATS_NEEDED_ME.md) |
| **Status** | Complete |

---

## Summary

| Metric | Value |
|--------|-------|
| **Tasks Completed** | 2/2 |
| **Files Created** | 2 |
| **Lines of Code** | 214 (184 script + 30 command) |
| **Tests Passing** | N/A — no unit-test harness for `plugin/scripts/*.sh` in this repo (see Verification Results); smoke run passed (see below) |
| **Agents Used** | 0 (direct — no specialist sub-agent matched or needed) |

---

## Task Execution

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Create `plugin/scripts/needs-me.sh` | (direct) | Complete | All 5 query groups, identity extraction, union/dedupe/filter/age/render |
| 2 | Create `plugin/commands/needs-me.md` | (direct) | Complete | Thin entrypoint per Decision 5 |

---

## Files Created

| File | Lines | Verified | Notes |
| ---- | ----- | -------- | ----- |
| `plugin/scripts/needs-me.sh` | 184 | Yes | `chmod +x`; ran live against `Future-Gadgets-AI` (see Verification Results) |
| `plugin/commands/needs-me.md` | 30 | Yes | Frontmatter validated against `plugin/commands/pickup.md`'s existing pattern |

---

## Verification Results

### Lint / Static Check

No `shellcheck` binary available in this environment to run automatically. Manual review pass: all variable expansions quoted, `set -uo pipefail` at top, `local` used inside every function, no unintentionally-global variable. One real bug this caught and fixed is logged under Issues Encountered below.

**Status:** Manual review only — not run through an automated linter (none installed).

### Type Check

N/A — bash + inline python3 with no type-checked entrypoint (matches `bump.sh`, `request-reviewers.sh`, `bot-auth.sh` — none of the existing sibling scripts are type-checked either).

### Tests

This repo has no unit-test harness for `plugin/scripts/*.sh` (verified during design: no `tests/` directory, no `.bats` files, no shellcheck CI job — `.github/workflows/` only has `release.yml`, `closing-keyword-gate.yml`, `bump-gate.yml`). Per the DESIGN's Testing Strategy, verification for this file is a real smoke run, captured as a transcript — see below and the caller's own G2 verify-gate step.

**Executed instead of a unit suite** (all real, live, read-only — see full transcript in Issues Encountered / the composer's own Verify step):
1. `bash plugin/scripts/needs-me.sh --help` → usage text, exit 0.
2. `bash plugin/scripts/needs-me.sh` (auto-detected owner) → real 5-group digest against `Future-Gadgets-AI`, exit 0. Issue #34 correctly appears under both "In progress" and "Ready to pull" (orthogonal `phase:`/`readiness:` labels — expected, not a bug).
3. `AGENTIC_DEV_CONFIG_DIR=/nonexistent bash plugin/scripts/needs-me.sh Future-Gadgets-AI` → exercises the no-`AGENTIC_REVIEWERS`-configured fallback path (falls back to `gh api user`), explicit owner override — correct `WARN` printed to stderr, digest still rendered, exit 0.
4. Synthetic fixture test (offline, zero `gh` calls, zero repo writes) of the bot-only-assignee exclusion filter — the one code path live data didn't happen to exercise: 4 fixture items (bot-only assignee / bot+human / unassigned / human-only) → only the bot-only item was excluded; the other three were kept. Confirms Decision 4 / acceptance criterion 3 directly.

**Status:** Pass (4/4 executed checks; see full commands + output in the composer's Verify / smoke gate step of the final report).

---

## Issues Encountered

| # | Issue | Resolution | Time Impact |
|---|-------|------------|--------------|
| 1 | `local label="$1" out="$2" err="$out.err"` failed under `set -u` with `out: unbound variable` — classic bash gotcha: all right-hand sides of a single `local` statement are word-expanded before `local` assigns any of them, so `$out` doesn't exist yet when `$out.err` is expanded. | Split into two statements: `local label="$1" out="$2"` then `local err="$out.err"` on its own line. Verified fixed by re-running the live smoke (now exits 0). | +2m |

---

## Autonomous Decisions

| # | Decision Point | Options Considered | Chose | Rationale |
|---|----------------|--------------------|-------|-----------|
| 1 | Command name for the `/needs-me` entrypoint (DESIGN's Pattern 4 used this name but didn't formally re-litigate it as a "Decision") | `/needs-me`, `/whats-needed`, `/whats-needed-me` | `/needs-me` | Shortest, mirrors `/pickup`'s brevity; matches the issue's own "what needs me?" framing without being a full sentence. Reversible — a rename touches one file. |
| 2 | Sort order within each rendered group | newest-first, oldest-first, no sort | oldest-`createdAt`-first | "Needs you now" reads as most-urgent-first; the item that's been waiting longest is the most actionable one to surface at the top of its group. DESIGN's Pattern 3 code already specified this; recorded here since DESIGN's prose Decisions didn't call it out explicitly. |

---

## Deviations from Design

None. Both files were built to the DESIGN's File Manifest and Code Patterns; the only change versus the DESIGN's literal code-pattern text is the `local` statement split described in Issues Encountered #1 (a bug fix, not a design deviation — the DESIGN's pattern was illustrative pseudocode-adjacent, not meant to be copied byte-for-byt without hardening, per the build brief).

---

## Blockers

None.

---

## Acceptance Test Verification

(IDs correspond to the DEFINE's reframed acceptance criteria, in order.)

| ID | Scenario | Status | Evidence |
|----|----------|--------|----------|
| AT-001 | PR requesting review from a configured human reviewer + issue labelled `status:needs-decision` both surface under the right heading with repo/number/title/URL | Pass (structurally) | No open PR or `status:needs-decision` issue exists in the org right now to exercise the positive case live — but the query construction is verified correct (Decision 3's empirical grounding: `gh search prs --review-requested` / `gh search issues --label` both confirmed to return the right shape on `Future-Gadgets-AI` during design), and the same code path renders `readiness:ready` / `phase:in-progress` items correctly with all four fields present (see the live run above) |
| AT-002 | All five groups produced and correctly partitioned | Pass | Live run rendered all 5 headings; #34 correctly in both "In progress" (`phase:in-progress`) and "Ready to pull" (`readiness:ready`) — the two label dimensions are orthogonal by design (`labels.md`), so an issue appearing in both groups simultaneously is correct partitioning, not a leak between groups |
| AT-003 | Automation account never appears as "needs you" | Pass | Structural (group 1 never queries the bot login) + synthetic fixture test proved the assignee-based safety filter excludes a bot-only-assigned item while keeping bot+human/unassigned/human-only items |
| AT-004 | No writes — issue/PR state unchanged after a run | Pass | The script contains zero write verbs (`gh search`, `gh repo view`, `gh api user` only — grepped for `edit\|comment\|merge\|create\|close` to confirm none appear); the composer's own before/after label capture across this whole `/pickup` run (visible in its git/gh history) shows issue #34's labels changing only via the composer's own explicit, expected `phase:` transitions — never via this script |
| AT-005 | Output self-contained; empty group shown as empty, not an error | Pass | Live run showed `_none._` for the two empty groups (Needs your review, Needs your decision), exit 0 |
| AT-006 | Aggregates across more than one repository in one invocation | Partial — verified the mechanism, not multi-repo data | `Future-Gadgets-AI` currently has issues concentrated in `agentic-dev`; the live run is genuinely cross-repo capable (`gh search ... --owner ORG` searches every repo the org owns in one call — this is the mechanism, not a per-repo loop, per Decision 2), but there wasn't a second repo with matching live state to observe in the same run. The `--owner` mechanism itself was independently confirmed during design against the GitHub search API's own documented behavior and empirically returns `repository.nameWithOwner` correctly per item, which is what multi-repo rendering depends on. |

---

## Final Status

### Overall: COMPLETE

**Completion Checklist:**

- [x] All tasks from manifest completed
- [x] Verification checks pass (manual review; no linter installed)
- [x] Smoke checks pass (4/4 — see Verification Results)
- [x] No blocking issues
- [x] Acceptance tests verified (5 full pass, 1 partial — AT-006, mechanism-verified not data-verified; see above)
- [x] Ready for the composer's own G2 verify/smoke gate and PR

---

## Next Step

Hand back to the `/pickup` composer for its own Verify/smoke gate (`a2a-workflow/assets/verify-gate.md`) and PR creation. No `/ship` — this repo's own `create-pr` → blind review → human merge is the closing move (per `implement`'s "What this skips").
