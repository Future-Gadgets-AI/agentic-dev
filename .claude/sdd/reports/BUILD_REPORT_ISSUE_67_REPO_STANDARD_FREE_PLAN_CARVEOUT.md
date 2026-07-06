# BUILD REPORT: ISSUE_67_REPO_STANDARD_FREE_PLAN_CARVEOUT

> Implementation report for issue #67 — "repo-standard: carve-out for private repos on the free
> plan." A private repo on the org's free GitHub plan 403s on branch-protection/rulesets GETs;
> before this build that 403 propagated as an undifferentiated hard failure inside
> `repo-standard-diff.sh`, crashing labels + CODEOWNERS along with it. Headless build run
> (Phase 3), composed mode.

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | ISSUE_67_REPO_STANDARD_FREE_PLAN_CARVEOUT |
| **Date** | 2026-07-05 |
| **Author** | build phase (headless build agent) |
| **DESIGN** | [`../features/DESIGN_ISSUE_67_REPO_STANDARD_FREE_PLAN_CARVEOUT.md`](../features/DESIGN_ISSUE_67_REPO_STANDARD_FREE_PLAN_CARVEOUT.md) |
| **Branch** | `fix/repo-standard-free-plan-carveout` |
| **Status** | **Complete** |

---

## Summary

| Metric | Value |
|--------|-------|
| **Manifest execution** | 3/3 files (0 created, 3 modified) — exactly the design's manifest, no more |
| **Edits applied** | 11/11 — (a) contract section, (b0)–(b8) script edits, (c1)–(c2) command-doc edits — all located by quoted "Before" text, all matched on first try |
| **Agents used** | 0 (direct — design assigns no `@agent-name`; the DESIGN's blocks are copy-paste-ready, so this is faithful transcription, not code generation requiring a specialist) |
| **Git commits / pushes / `gh` calls** | 0 (hard constraint honored — worked purely in the local tree; only read-only `git diff`/`git status` run) |
| **Network calls made during verification** | 0 (no `repo-standard-diff.sh` end-to-end run attempted, per instructions — that's the composer's shadow-gh smoke gate) |
| **`plugin/.claude-plugin/plugin.json`** | Untouched (composer's job, confirmed via `git status --porcelain`) |
| **Verification commands run** | 9/9 executed for real; 9/9 passed |

---

## Files touched

| # | File | Action | Summary |
|---|------|--------|---------|
| 1 | `plugin/contracts/repo-standard.md` | Modify | Inserted (a): new `## Free-plan carve-out — private repos cannot assert protection/rulesets` section (31 lines), placed immediately after the CLI-convention section's closing sentence ("...offline, syntactic validation only.") and immediately before `## Bot wiring — pointer`. Covers all four DEFINE-required elements: what still applies (labels/CODEOWNERS), what cannot be asserted (protection/ruleset, with GitHub's exact `HTTP 403` / "Upgrade to GitHub Pro or make this repository public" wording), the mandated fallback (process enforcement + target-repo README note), and the explicit non-goals (paying, going public). |
| 2 | `plugin/scripts/repo-standard-diff.sh` | Modify | Applied (b0)–(b8) verbatim: header-comment paragraph documenting the carve-out (b0); new `is_plan_limited()` predicate + `PlanLimited` exception class, and both `get_or_empty`/`get_list_or_empty` raise it on the carve-out 403 shape (b1); the branch-protection GET call site wrapped in `try/except PlanLimited` (b2); `na_plan_limitation` branch added first in the protection status-decision tree (b3); the rulesets-list GET call site wrapped the same way (b4); `na_plan_limitation` branch added first in the ruleset status-decision tree (b5); `plan.json`'s `protection`/`ruleset` sub-objects both gain a `reason` field (b6); report rendering for both sections gains a `status_display` mapping dict + conditional `reason:` line (b7); the Summary table's combined cell uses the same display dict (b8). |
| 3 | `plugin/commands/harden-repo.md` | Modify | Applied (c1)/(c2): both verify-mode `Status` enum lines (line 31's Phase-A-exit prose, line 187's Final-report prose) now list `N/A (plan limitation)` alongside `MATCH`/`DRIFT`/`ABSENT`/`BLOCKED`, each annotated "(Protection/ruleset-only)". No other line touched — the apply-mode Report-block enum (line 164, "Apply-mode Phase C gap" per the design's own inline decision) deliberately left unchanged, matching the DEFINE's verify-mode-only AT-3 scope. |

**Explicitly not touched** (hard constraints, confirmed via `git status --porcelain` — all absent from the diff): `plugin/scripts/repo-standard-apply-codeowners.sh`, `plugin/scripts/repo-standard-apply-labels.sh`, `plugin/.claude-plugin/plugin.json`, and any `DESIGN_ISSUE_36_*` / `BUILD_REPORT_ISSUE_36_*` / `DESIGN_ISSUE_66_*` file.

---

## Verification

All commands run for real from the working directory, offline (no `gh`, no network, no git write commands).

| # | Command | Real observed output | Exit | Result |
|---|---------|------------------------|------|--------|
| 1 | `bash -n plugin/scripts/repo-standard-diff.sh` | (no output) | 0 | Pass — syntax OK |
| 2 | Extract embedded python heredoc body (between `<<'PY'` / `PY`) to `/private/tmp/.../scratchpad/extracted_heredoc.py`, then `python3 -m py_compile extracted_heredoc.py` | Extraction wrote 18,335 bytes; `py_compile` produced `extracted_heredoc.cpython-314.pyc` with no errors | 0 | Pass — embedded Python is syntactically valid (runtime failure without argv is expected and irrelevant, per instructions) |
| 3 | `git diff --stat` | ```plugin/commands/harden-repo.md       \|  4 +-``` / ```plugin/contracts/repo-standard.md    \| 31 +++++++++++++``` / ```plugin/scripts/repo-standard-diff.sh \| 86 ++++++++++++++++++++++++++++++++----``` / ```3 files changed, 110 insertions(+), 11 deletions(-)``` | 0 | Pass — exactly the 3 manifest files, no more, no less |
| 4 | `grep -n "na_plan_limitation" plugin/scripts/repo-standard-diff.sh` | `25:# protection.status / ruleset.status == "na_plan_limitation" in plan.json,` / `322:    protection_status = "na_plan_limitation"` / `369:    ruleset_status = "na_plan_limitation"` / `526:status_display = {"match": "MATCH", "absent": "ABSENT", "drift": "DRIFT", "na_plan_limitation": "N/A (plan limitation)"}` / `535:if protection_status == "na_plan_limitation":` / `543:if ruleset_status == "na_plan_limitation":` | 0 | Pass — both status-decision trees (322, 369) assign the literal; the display dict (526) maps it; both report-rendering conditionals (535, 543) check it. The `plan.json` dict itself (lines 473/480 `"status": protection_status`/`"status": ruleset_status`, lines 477/482 `"reason": protection_plan_limited`/`"reason": ruleset_plan_limited"`) carries the value through variables rather than repeating the string literal — confirmed by direct read, see note below the table |
| 5 | `grep -c "N/A (plan limitation)" plugin/scripts/repo-standard-diff.sh` | `2` | 0 | Pass — line 26 (the (b0) header-comment paragraph, which itself quotes this exact display string as documentation) + line 526 (the (b7) display-dict literal, the actual rendering site). Both occurrences are design-mandated text (present verbatim in the DESIGN's own (b0)/(b7) "After" blocks) — no stray third occurrence exists |
| 6 | `grep -n "upgrade to github pro" plugin/scripts/repo-standard-diff.sh` | `156:    return "HTTP 403" in err and "upgrade to github pro" in err.lower()` | 0 | Pass — exactly one occurrence, lower-cased, inside `is_plan_limited` |
| 7 | Inspection: `sys.exit` negative-case still present/reached in `get_or_empty`/`get_list_or_empty` | Lines 172–180 (`get_or_empty`) and 183–191 (`get_list_or_empty`): each function's final statement is unchanged — `sys.exit(f"repo-standard-diff: GET {path} failed: {err.strip()}")` — reached whenever `ok` is `False`, `is_missing(err)` is `False`, **and** `is_plan_limited(err)` is `False` (i.e. any 403 without the exact "upgrade to github pro" body, any 401/5xx/network error, any 404-with-unrelated-text). The new `is_plan_limited` check is a pure insertion between the pre-existing `is_missing` check and this pre-existing hard-fail line — neither the line's text nor its position relative to the two callers changed | n/a (static inspection) | Pass — negative case (any OTHER 403 still hard-fails, byte-identical to before) confirmed by direct read, not just by grep |
| 8 | `grep -n "N/A (plan limitation)" plugin/commands/harden-repo.md` | `31:**Verify mode (no \`--apply\`) stops here.** Render the Final report below with every \`Status\` limited to \`MATCH\`/\`DRIFT\`/\`ABSENT\`/\`BLOCKED\`/\`N/A (plan limitation)\` (the last is Protection/ruleset-only — see \`plan.json\`'s \`protection.status\`/\`ruleset.status\` == \`na_plan_limitation\`)...` / `187:Verify mode: every \`Status\` is \`MATCH\`/\`DRIFT\`/\`ABSENT\`/\`BLOCKED\`/\`N/A (plan limitation)\` (Protection/ruleset-only); footer...` | 0 | Pass — exactly the two verify-mode enum lines from (c1)/(c2), no other occurrence |
| 9 | Inspection: contract section placement | Lines 186–188 (unchanged, pre-existing): "API-based existence verification... offline, syntactic validation only." + blank line. Line 189: new `## Free-plan carve-out — private repos cannot assert protection/rulesets` heading begins immediately after. Lines 189–219: the new section's full body. Line 220 (unchanged, immediately following the new section with no gap): `## Bot wiring — pointer (never re-derive credential logic here)` | n/a (static inspection) | Pass — new section sits exactly between the CLI-convention section's end and `## Bot wiring — pointer`, per the design's pinned appendix position |

**Note on row 4** (`plan.json` wiring): the design's `plan` dict (b6) assigns `"status": protection_status` / `"status": ruleset_status` and the new `"reason": protection_plan_limited` / `"reason": ruleset_plan_limited"` — it references the variables set in the status-decision trees (b3/b5) rather than re-typing the string literal `"na_plan_limitation"`. Confirmed present at lines 473–482 via direct read. This is the correct, DRY wiring the design specifies (single source of truth for the literal, in the decision tree) — not a gap.

Full `git diff` for all three files was also read in full (not just `--stat`) and confirmed hunk-for-hunk identical to the design's (a)/(b0)–(b8)/(c1)–(c2) "After" blocks, with zero stray changes outside those hunks.

---

## Acceptance-test mapping

| AT | How satisfied | Verification |
|----|----------------|---------------|
| **AT-1** — `repo-standard.md` documents the carve-out: what applies, what cannot, the mandated fallback, the non-goals | New `## Free-plan carve-out` section (a) contains all four elements verbatim: "What still applies" (labels/CODEOWNERS), "What cannot be asserted" (protection/ruleset + exact `HTTP 403` / "Upgrade to GitHub Pro or make this repository public" wording), "Mandated fallback" (process enforcement + target-repo README note), "Explicitly out of scope" (paying, going public) | **Inspection** (per the DEFINE's own framing — not executed): read the new section end to end (verification row 9); all four required elements present, correctly cross-referencing Decision D4 and `DESIGN_ISSUE_36`'s ruleset-DRIFT row rather than minting a new "D11" |
| **AT-2** — the script distinguishes the 403-plan-limitation shape from real drift/absence on protection **and** ruleset, verifiable via a shadow-`gh` shim | `is_plan_limited` (b1) classifies the exact shape; `PlanLimited` raised only at the two relevant call sites (b2, b4); both status trees (b3, b5) emit `"na_plan_limitation"` with `diff_fields: []` and a populated `reason`, never `"absent"`, never routed into `sys.exit` — all confirmed present by static inspection (rows 4, 6, 7 above) | **Deferred to the composer's shadow-`gh` smoke gate** — this build phase does not run `repo-standard-diff.sh` end-to-end (no network access, no shadow-`gh` shim constructed here, per explicit instruction). Not claimed as executed. |
| **AT-3** — hardening a private free-plan repo (verify mode) completes labels + CODEOWNERS normally, reports the carve-out for protection/ruleset, exit code `0` | Labels/CODEOWNERS are computed via entirely separate `gh api` calls never routed through the two `PlanLimited`-aware call sites (unaffected — traced in the DESIGN's call graph, unchanged by this build); `PlanLimited` is caught locally, never re-raised, never calls `sys.exit`; execution reaches the file's end normally — nothing exists after the `python3` heredoc closes (confirmed: the heredoc's last statement is the final `print("\n".join(lines))`, followed only by the closing `PY` marker) | **Deferred to the composer's shadow-`gh` smoke gate** — same reason as AT-2. Not claimed as executed. |

---

## Autonomous Decisions

None. Every one of the 11 edits — (a), (b0)–(b8), (c1)–(c2) — was located by its quoted "Before" text and matched the working tree's actual content exactly on the first attempt (no line-number drift encountered, no ambiguous match, no missing anchor text). The DESIGN's blocks are explicitly "copy-paste-ready," and every block was applied verbatim with zero adaptation. No KB-domain pattern lookup was needed beyond the DESIGN itself (it is a self-contained bash/markdown edit with no framework-specific idiom to validate against). No decision fork — ambiguous interpretation, missing anchor, or gap the DESIGN didn't pre-decide — was encountered anywhere in this build.

---

## Blockers / Deviations from the design

None. All three files match the design's manifest exactly; all 11 edits applied byte-for-byte per the "After" blocks (confirmed via full `git diff` read, not just `--stat`); no scope was added or omitted. The one pre-existing, consciously-deferred gap the design itself names ("Apply-mode Phase C gap — flagged, not fixed") was correctly left untouched, exactly as the design instructs — this is not a deviation, it is following the design's own explicit non-goal.

## Status: ✅ COMPLETE
