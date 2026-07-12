# BUILD REPORT: ISSUE_72_HARDEN_REPO_PLAN_LIMITATION_PHASE_C

> Implementation report for issue #72 — apply mode's Phase C ("## C — Branch protection + ruleset"
> in `plugin/commands/harden-repo.md`) did not yet special-case the `na_plan_limitation` status
> Phase A (`repo-standard-diff.sh`) already writes to `plan.json` for a private repo on GitHub's
> free plan. Headless build run (Phase 3), no composer step run here (no `gh`/`git` write, no
> version bump — those are the composer's job).

## Metadata

| Attribute | Value |
|-----------|-------|
| **Requirements source** | `Future-Gadgets-AI/agentic-dev#72` — "[TASK] harden-repo apply mode: special-case na_plan_limitation in Phase C" |
| **DESIGN** | [`../features/DESIGN_ISSUE_72_HARDEN_REPO_PLAN_LIMITATION_PHASE_C.md`](../features/DESIGN_ISSUE_72_HARDEN_REPO_PLAN_LIMITATION_PHASE_C.md) |
| **Branch** | `fix/harden-repo-plan-limitation-phase-c` |
| **Date** | 2026-07-12 |
| **Author** | build phase (headless build agent) |
| **Status** | **Complete** |

---

## Summary

| Metric | Value |
|--------|-------|
| **Manifest execution** | 1/1 file (0 created, 1 modified) — exactly the design's manifest, no more |
| **Edits applied** | 2/2 — (a)/(b) paragraph insertion at the anchor, (d) `Status:` enum append + two new `Changed:` lines — both located by quoted "Before" text from the design, both matched the working tree on the first attempt |
| **Agents used** | 0 (direct — the design assigns no `@agent-name`; both blocks are copy-paste-ready per the design's own self-check, so this is verbatim transcription, not code generation requiring a specialist) |
| **Git commits / pushes / `gh` calls** | 0 (hard constraint honored — only read-only `git diff`/`git status`/`git show` run) |
| **`plugin/.claude-plugin/plugin.json`** | Untouched (composer's job — confirmed via `git diff --stat -- plugin/.claude-plugin/plugin.json`, empty) |
| **Verification commands run** | 4/4 (as mandated by the build brief) executed for real, all passed |

---

## Files touched

| # | File | Action | Summary |
|---|------|--------|---------|
| 1 | `plugin/commands/harden-repo.md` | Modify | Inserted design section (b)'s two new paragraphs at (a)'s anchor — between "`main` exists → continue below." and the existing "If protection status is already `\"match\"`..." combined-match paragraph — handling `na_plan_limitation` per-half, independently, before the existing match/confirmation logic. Applied (d): appended `\| N/A (plan limitation)` to the apply-mode "### Branch protection + ruleset" Report block's `Status:` enum line; appended two new `Changed:` lines (`protection: N/A (plan limitation) — ...` / `ruleset: N/A (plan limitation) — ...`) below the existing three, each carrying the mandated process-enforcement fallback text and its own `(only if ... status is "na_plan_limitation")` conditional. |

**Explicitly not touched** (per the design's file manifest and this build's hard constraints, confirmed via `git status --porcelain`): `plugin/scripts/repo-standard-diff.sh`, `plugin/contracts/repo-standard.md`, `plugin/scripts/repo-standard-apply-codeowners.sh`, `plugin/scripts/repo-standard-apply-labels.sh`, `plugin/.claude-plugin/plugin.json`. No `git commit`/`push`/`fetch`, no GitHub-writing `gh` command, run at any point in this build.

---

## Verification

All commands run for real from the repo root, offline (no network, no git write commands).

### 1 — `git diff --stat` and full `git diff plugin/commands/harden-repo.md`

```
$ git diff --stat plugin/commands/harden-repo.md
 plugin/commands/harden-repo.md | 8 +++++++-
 1 file changed, 7 insertions(+), 1 deletion(-)
```

```diff
$ git diff plugin/commands/harden-repo.md
diff --git a/plugin/commands/harden-repo.md b/plugin/commands/harden-repo.md
index 1455aa8..16db1b2 100644
--- a/plugin/commands/harden-repo.md
+++ b/plugin/commands/harden-repo.md
@@ -122,6 +122,10 @@ Re-probe that `main` exists before rendering the confirmation (Decision D7 — P
 - `main` missing and A2 didn't just create it (declined, blocked, or a non-empty repo with no `main`) → skip the **protection** half only, report `BLOCKED (main branch does not exist)`. The **ruleset** half has no such dependency (its `ref_name` conditions are pattern-based, not tied to an existing branch) — proceed with it independently.
 - `main` exists → continue below.
 
+Before the combined match check below, handle `na_plan_limitation` the same way the check above handles a missing `main`: read protection status and ruleset status independently — one half's status never implies the other's. Whichever half's status is `"na_plan_limitation"` (the **protection** half, the **ruleset** half, or both) is fully resolved right here, for the rest of this sub-step: its put/post body is never read or shown, its write is never attempted, and it is reported as `N/A (plan limitation)` — never `NO-OP (already matches)`, which stays reserved for a genuine `"match"` — together with the Free-plan carve-out's mandated fallback (`plugin/contracts/repo-standard.md`, "Free-plan carve-out"): process enforcement (bot-authored PRs plus human merges) stands in for the missing technical guardrail, plus a note on the *target* repo's own README documenting the residual risk (no branch protection/ruleset on this repo; merges are enforced by process, not by GitHub).
+
+A half resolved this way counts, everywhere below in this sub-step, exactly like a half already at `"match"`, even though the wording ahead never names this exception inline: the confirmation prompt's per-half blocks below omit it on the same terms as an already-`"match"` half, and it never runs its write line on **Yes** below either. If resolving `na_plan_limitation` this way leaves no half whose status still needs a write — both halves accounted for, or the one half left over is genuinely `"match"` — there is nothing to confirm at all: skip the confirmation prompt entirely and go straight to the Final report, exactly as the already-both-`"match"` case immediately below does.
+
 If protection status is already `"match"` **and** ruleset status is already `"match"` — nothing to confirm; report `NO-OP (already matches)` for both and skip straight to the Final report without asking.
 
 Otherwise, read `$PLAN_DIR/protection-put-body.json` and (if present) `$PLAN_DIR/ruleset-post-body.json`, pretty-print them, and **end your turn and wait for the human's next message**:
@@ -161,12 +165,14 @@ On **No** → report `DECLINED`, note "re-run `/harden-repo <repo> --apply` to r
 ```
 ### Branch protection + ruleset
 Identity:  ambient human (<CURRENT_LOGIN>) — asserted != configured bot (asserted <timestamp>)
-Status:    APPLIED (confirmed) | NO-OP (already matches) | AWAITING CONFIRMATION | DECLINED | BLOCKED (main branch does not exist) | BLOCKED (ambient identity check failed)
+Status:    APPLIED (confirmed) | NO-OP (already matches) | AWAITING CONFIRMATION | DECLINED | BLOCKED (main branch does not exist) | BLOCKED (ambient identity check failed) | N/A (plan limitation)
 Changed:
   protection.required_status_checks.contexts: <before> -> <after>
   (all other observed protection fields — restrictions, required_conversation_resolution,
    required_linear_history, block_creations, lock_branch, allow_fork_syncing — preserved verbatim)
   ruleset: created "branch-naming-convention" (new id <n>) | already present, no-op | DRIFT (not modified — see plan.json ruleset.diff_fields)
+  protection: N/A (plan limitation) — not written; see plan.json protection.reason for the 403 body; fallback: process enforcement (bot-authored PRs + human merges) plus a README note on <owner/repo> documenting the residual risk (no branch protection — merges enforced by process, not by GitHub)   (only if protection status is "na_plan_limitation")
+  ruleset: N/A (plan limitation) — not written; see plan.json ruleset.reason for the 403 body; fallback: process enforcement (bot-authored PRs + human merges) plus a README note on <owner/repo> documenting the residual risk (no branch-naming ruleset — merges enforced by process, not by GitHub)   (only if ruleset status is "na_plan_limitation")
 ```
 
 ## Final report (always rendered, both modes)
```

`git status --porcelain` at completion: only `M plugin/commands/harden-repo.md` (plus the pre-existing untracked `.claude/sdd/features/DESIGN_ISSUE_72_HARDEN_REPO_PLAN_LIMITATION_PHASE_C.md`, which this build phase did not create or modify).

### 2 — Diff-shape proof (AT-3's hard constraint, checked programmatically, not just eyeballed)

```
$ git diff plugin/commands/harden-repo.md | grep -c "^@@"
2
$ git diff plugin/commands/harden-repo.md | grep "^-" | grep -v "^---"
-Status:    APPLIED (confirmed) | NO-OP (already matches) | AWAITING CONFIRMATION | DECLINED | BLOCKED (main branch does not exist) | BLOCKED (ambient identity check failed)
$ git diff plugin/commands/harden-repo.md | grep "^+" | grep -v "^+++" | wc -l
       7
```

- **Two hunks total.**
- **Hunk 1** (anchor `@@ -122,6 +122,10 @@`): pure additions — 4 new lines (paragraph 1, blank, paragraph 2, blank), zero removed lines, both surrounding context lines (`- \`main\` exists → continue below.` and `If protection status is already \`"match"\`...`) reappear byte-identical as unchanged context.
- **Hunk 2** (anchor `@@ -161,12 +165,14 @@`): exactly **one** removed line (the old `Status:` line) paired with exactly one added line — verified programmatically to be a **strict prefix-preserving extension**:
  ```python
  removed = 'Status:    APPLIED (confirmed) | NO-OP (already matches) | AWAITING CONFIRMATION | DECLINED | BLOCKED (main branch does not exist) | BLOCKED (ambient identity check failed)'
  added   = 'Status:    APPLIED (confirmed) | NO-OP (already matches) | AWAITING CONFIRMATION | DECLINED | BLOCKED (main branch does not exist) | BLOCKED (ambient identity check failed) | N/A (plan limitation)'
  added.startswith(removed)  # -> True
  added[len(removed):]       # -> ' | N/A (plan limitation)'
  ```
  followed by 2 purely-added `Changed:` lines; the three pre-existing `Changed:` lines (`protection.required_status_checks.contexts...`, the parenthetical, `ruleset: created...`) reappear byte-identical as unchanged context.
- **Total: 1 line removed, 7 lines added** — matches `git diff --stat`'s `7 insertions(+), 1 deletion(-)` exactly. Every removed line is immediately re-added as a strict prefix-preserving extension, or the hunk is pure additions — no other line in the file changed (no whitespace, no wording, no reflow), confirmed by inspecting both hunks in full above.

### 3 — `N/A (plan limitation)` occurrence count (before/after)

The build brief's own guess was "3 occurrences before, +4 delta, 7 after." I verified the actual before-count myself, per the brief's own instruction not to trust an unverified claim — it does not match the guess in its absolute values, though the **delta** (which is what AT-3/AT-2 actually depend on) matches exactly:

```
$ git show HEAD:plugin/commands/harden-repo.md | grep -c "N/A (plan limitation)"
2
$ grep -c "N/A (plan limitation)" plugin/commands/harden-repo.md
6
```

**Before: 2** (not 3). Re-checked directly: `grep -n "N/A (plan limitation)"` against `git show HEAD:...` shows exactly two matches — the verify-mode Phase-A-exit line (originally line 31) and the verify-mode Final-report line (originally line 187). There is no separate third occurrence of the literal string "N/A (plan limitation)" anywhere else pre-edit — the "footer note" the brief mentions is the same line-187 sentence's trailing clause ("...footer `Writes performed: 0...`"), which does not itself repeat the "N/A (plan limitation)" string; it was miscounted as a third occurrence in the brief's expectation. This is a documented, harmless discrepancy in the *brief's own pre-count guess*, not a defect in this build — see Autonomous Decisions below.

**After: 6.** Delta: **+4**, exactly as the brief specified: the new prose paragraph (1 occurrence, in the first new paragraph's "...reported as `N/A (plan limitation)`..." clause) + the `Status:` enum append (1) + the two new `Changed:` lines (2) = 4. All 6 post-edit occurrences, with line numbers:

```
31:  ...`N/A (plan limitation)`... (verify-mode Phase-A-exit line — pre-existing, unedited, shifted from a lower earlier line count in the design's own citation to the same line 31 here since this edit is below it)
125: ...reported as `N/A (plan limitation)`... (NEW — this build's paragraph 1)
168: Status: ... | N/A (plan limitation)                                    (NEW — this build's enum append)
174:   protection: N/A (plan limitation) — ...                              (NEW — this build's Changed line 1)
175:   ruleset: N/A (plan limitation) — ...                                 (NEW — this build's Changed line 2)
193: ...`N/A (plan limitation)`... (verify-mode Final-report line — pre-existing, unedited)
```

### 4 — `grep -n "process enforcement"` — new fallback text present

```
$ grep -n "process enforcement" plugin/commands/harden-repo.md
125:  ...together with the Free-plan carve-out's mandated fallback (`plugin/contracts/repo-standard.md`, "Free-plan carve-out"): process enforcement (bot-authored PRs plus human merges) stands in for the missing technical guardrail, plus a note on the *target* repo's own README documenting the residual risk...
174:  protection: N/A (plan limitation) — ...; fallback: process enforcement (bot-authored PRs + human merges) plus a README note on <owner/repo> documenting the residual risk (no branch protection — merges enforced by process, not by GitHub)   (only if protection status is "na_plan_limitation")
175:  ruleset: N/A (plan limitation) — ...; fallback: process enforcement (bot-authored PRs + human merges) plus a README note on <owner/repo> documenting the residual risk (no branch-naming ruleset — merges enforced by process, not by GitHub)   (only if ruleset status is "na_plan_limitation")
```

Present in exactly the three places the design specifies: the new prose paragraph (line 125) and both new `Changed:` lines (174, 175). Traceable to `plugin/contracts/repo-standard.md`'s "Free-plan carve-out" section, per the design's Constraints self-check.

---

## Acceptance-test mapping

| AT | How satisfied | Verification |
|----|----------------|---------------|
| **AT-1** — "NO confirmation prompt for the affected field(s), no write for them" | Satisfied by design + build: the two new paragraphs (inserted verbatim, confirmed byte-for-byte against the design's (b) block above) state the field is resolved before the confirmation prompt is reached — body never read/shown, write never attempted, per-half omission from the prompt, whole-prompt skip when nothing is left. **Design-level proof**: the design's Fixture A/B/C simulated walkthroughs ((f) section) trace this line-by-line. **This build**: confirms the exact prose is now physically present in the file, unedited from the design's text. Final live-repo confirmation is the composer's `--apply` verify/smoke gate, not re-run here (headless build phase, no `gh` write permitted). |
| **AT-2** — "Final report shows `N/A (plan limitation)`, mentions the process-enforcement fallback" | Satisfied by design + build: the `Status:` enum line and both new `Changed:` lines literally contain "N/A (plan limitation)" and "process enforcement" / "bot-authored PRs" / "human merges" / "README" / "residual risk" — confirmed by verification checks 3 and 4 above, run against the actual edited file. Final live-repo confirmation is the composer's verify gate. |
| **AT-3** — "byte-identical for any status other than `na_plan_limitation`" | **PROVEN here, directly, by this build's own diff-check** (not deferred) — verification check 2 above shows the entire `git diff` consists of exactly two hunks: one pure-addition hunk (4 new lines, zero removals, unchanged context on both sides) and one hunk with exactly one removed line paired with one added line that is a programmatically-confirmed **strict prefix-preserving extension** (`added.startswith(removed)` → `True`, suffix = `' | N/A (plan limitation)'` exactly) plus two purely-added lines. No other byte in the file changed — `git diff --stat` reports 1 file, 7 insertions, 1 deletion, matching the diff hunks exactly. This is the diff-check a reviewer would run; it is included above in full, not summarized. |

---

## Autonomous Decisions

| # | Decision Point | Options Considered | Chose | Rationale |
|---|----------------|--------------------|-------|-----------|
| 1 | The build brief's own pre-count guess for `grep -c "N/A (plan limitation)"` on `HEAD` said "3 occurrences (lines ~31, ~187, and 'the verify-mode footer note')." My own verification (`git show HEAD:... \| grep -c`) returned **2**, not 3 — there is no separate third occurrence; the "footer note" the brief describes is part of the same line-187 sentence, which does not itself repeat the literal string. | (a) Silently use the brief's stated "3" and force my after-count to match a claimed "7", possibly by mis-locating a "third" occurrence that doesn't exist; (b) trust my own re-derived count (as the brief itself instructs — "verify the exact before-count yourself") and report the real numbers, flagging the discrepancy. | (b) — reported the real, independently-verified counts (before=2, after=6, delta=+4) and called out the mismatch explicitly in verification check 3 above, rather than papering over it. | The brief explicitly says to verify, not to trust the guess; the delta (+4, which is what the acceptance tests actually depend on) matches regardless, so this is a harmless discrepancy in the brief's pre-count expectation, not a defect — but a build report that silently "corrected" its evidence to match an unverified premise would be exactly the kind of untrustworthy report `CLAUDE.md`'s "distrust a tidy subagent report" lesson warns against producing. Smallest-correct-change principle: report ground truth, note the mismatch, move on — no file edit was warranted by this. |

---

## Blockers / Deviations from the design

None. The single file in the manifest was modified with exactly the two edits the design specifies — (a)/(b)'s paragraph insertion and (d)'s `Status:`/`Changed:` append — both applied byte-for-byte from the design's fenced "verbatim, ready to paste" blocks (confirmed via the full `git diff` read above, not just `--stat`). No other line in `plugin/commands/harden-repo.md` was touched. No other file in the repository was modified. No `git commit`/`push`/`fetch` and no GitHub-writing `gh` command was run. `plugin/.claude-plugin/plugin.json` was not touched (composer's job, per the design's own file manifest and this build's explicit hard constraint).

## Status: ✅ COMPLETE
