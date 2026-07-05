# BUILD REPORT: ISSUE_66_REPO_STANDARD_SCRIPT_INTERFACES

> Implementation report for issue #66 — "[BUG] repo-standard scripts: inconsistent confirmation
> interfaces; codeowners script accepts flags as owner handles." Headless build run (Phase 3),
> composed mode.

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | ISSUE_66_REPO_STANDARD_SCRIPT_INTERFACES |
| **Date** | 2026-07-05 |
| **Author** | build phase (headless build agent) |
| **DESIGN** | [`../features/DESIGN_ISSUE_66_REPO_STANDARD_SCRIPT_INTERFACES.md`](../features/DESIGN_ISSUE_66_REPO_STANDARD_SCRIPT_INTERFACES.md) |
| **Branch** | `fix/repo-standard-script-interfaces` |
| **Status** | **Complete** |

---

## Summary

| Metric | Value |
|--------|-------|
| **Manifest execution** | 3/3 files (0 created, 3 modified) — exactly the design's manifest, no more |
| **Agents used** | 0 (direct — design assigns no `@agent-name`; single-domain bash/markdown edit) |
| **Git commits / pushes / `gh` calls** | 0 (hard constraint honored — worked purely in the local tree) |
| **Network calls made during verification** | 0 (every failing case died on usage validation, never reached `bot-auth.sh`) |
| **Verification commands run** | 9/9 executed for real; 9/9 passed |

---

## Files touched

| # | File | Action | Summary |
|---|------|--------|---------|
| 1 | `plugin/scripts/repo-standard-apply-codeowners.sh` | Modify | Replaced lines 1–29 (shebang through `source "$HERE/bot-auth.sh" \|\| exit 1`) with the design's copy-paste-ready block, verbatim: new `OWNER/REPO --reviewers "..." --confirmed` flag interface, a flag-parsing loop (unknown arg → error), a `--confirmed` gate, a `--reviewers` non-empty gate, and a dash-prefix + zero-token check over the whitespace-split reviewer list — all of it lexically before `bot-auth.sh` is sourced. Header comment rewritten to document the new interface, an "Argument validation" note block, and the D9 reversibility rationale (kept, reworded to explain `--confirmed` is an interface-consistency marker, not a new gate). Everything from `TARGET_LINE="*"` (original line 31) through EOF (original line 177) is **byte-identical** — confirmed via `git diff`, which shows a single contiguous hunk ending at the pre-existing `command -v python3` check, with no further hunks for the rest of the file. |
| 2 | `plugin/commands/harden-repo.md` | Modify | A2 CODEOWNERS invocation line changed from `... "<owner/repo>" "$REVIEWERS"` to `... "<owner/repo>" --reviewers "$REVIEWERS" --confirmed`; one clarifying sentence added immediately after the code block (`--confirmed` is a CLI-interface literal, not a human gate; sub-step gate stays `NONE`). No other prose touched — heading, D9 paragraph, argument-hint, Report block template all verified unchanged per the design's explicit checklist. |
| 3 | `plugin/contracts/repo-standard.md` | Modify | New `## repo-standard-*.sh family — CLI convention` section inserted between `## CODEOWNERS — format` and `## Bot wiring — pointer`: a 3-row table of positional/flags/`--confirmed`/`--reviewers` per script, plus prose on the deliberate `diff.sh`-fallback vs. apply-explicit `--reviewers` asymmetry, the shared `--confirmed` requirement, and the offline owner-handle validation rule (referencing #66). `## CODEOWNERS — format`'s own existing text left untouched, per the design. |

**Explicitly not touched** (hard constraints, confirmed via `git status --porcelain` — all empty/absent): `plugin/scripts/repo-standard-apply-labels.sh`, `plugin/scripts/repo-standard-diff.sh`, `plugin/.claude-plugin/plugin.json`, and any `DESIGN_ISSUE_36_*` / `BUILD_REPORT_ISSUE_36_*` file.

---

## Verification

All commands run for real from the working directory, offline (no `gh`, no network) — each failing case's stderr is checked to confirm it originates from the script's own usage validation, never from `bot-auth.sh`/`gh`.

| # | Command | Expected | Observed stderr (verbatim) | Exit | Result |
|---|---------|----------|------------------------------|------|--------|
| 1 | `bash -n plugin/scripts/repo-standard-apply-codeowners.sh` | syntax OK | (none) | 0 | Pass |
| 2 | `bash plugin/scripts/repo-standard-apply-codeowners.sh` (no args) | usage error, non-zero | `...: line 35: 1: usage: repo-standard-apply-codeowners.sh OWNER/REPO --reviewers "reviewer1 reviewer2 ..." --confirmed` | 1 | Pass |
| 3 | `... example-org/example-repo --confirmed` (**AT-3 regression**: missing `--reviewers`) | usage error naming missing `--reviewers`, non-zero | `repo-standard-apply-codeowners: refusing — missing --reviewers (a space-separated list of GitHub logins is required).` | 1 | Pass |
| 4 | `... example-org/example-repo --reviewers "--confirmed alice" --confirmed` (**AT-2 dash-token**) | error naming the `-`-prefixed token, non-zero | `repo-standard-apply-codeowners: refusing — reviewer token '--confirmed' looks like a flag (starts with '-'), not a GitHub login.` | 1 | Pass |
| 5 | `... example-org/example-repo --reviewers "" --confirmed` | empty-list usage error, non-zero | `...: line 42: 1: --reviewers needs a value` | 1 | Pass (see Autonomous Decisions #1) |
| 6 | `... example-org/example-repo --reviewers "   " --confirmed` (**AT-2 empty-after-split**) | empty-after-split usage error, non-zero | `repo-standard-apply-codeowners: no reviewers resolved — refusing to write an empty CODEOWNERS rule.` | 1 | Pass |
| 7 | `... example-org/example-repo --reviewers "alice bob"` (missing `--confirmed`) | usage error, non-zero | `repo-standard-apply-codeowners: refusing — missing --confirmed (the confirmation gate is the caller's job).` | 1 | Pass |
| 8 | `... example-org/example-repo --bogus-flag --reviewers "alice" --confirmed` | unknown-argument error, non-zero | `repo-standard-apply-codeowners: unknown argument: --bogus-flag` | 1 | Pass |
| 9 | `grep -rn "apply-codeowners" plugin/ \| grep -v "repo-standard-apply-codeowners.sh:"` | every remaining reference shows the new interface | `harden-repo.md:46` shows the updated invocation (`--reviewers "$REVIEWERS" --confirmed`); all other hits are prose in the new contract section / the unchanged report-block label. No stale two-positional-arg call site anywhere. | 0 | Pass |

Every one of cases 2–8 died on a `usage:`/`refusing`/`unknown argument` message from the script itself (or bash's native `${var:?message}` mechanism) — never a `gh`/`bot-auth`-prefixed line — confirming, by construction, that validation fully precedes the network boundary (`source "$HERE/bot-auth.sh"`).

Bonus check: `shellcheck` is not installed in this environment, so it was skipped — it was not in the task's mandated verification list, and the pre-existing `# shellcheck source=/dev/null` directive was preserved unmodified from the original file.

---

## Acceptance-test mapping

| AT | How satisfied | Verification |
|----|----------------|---------------|
| **AT-1** — both apply scripts share one documented confirmation convention | New contract section documents both scripts requiring `--confirmed`; both use the identical refusal message `refusing — missing --confirmed (the confirmation gate is the caller's job).`, differing only in script-name prefix — confirmed by reading `repo-standard-apply-labels.sh` line 18 side-by-side with the new codeowners script's line 194-equivalent text. | **Inspection** (per DEFINE's own framing — not executed): contract section + both scripts' headers/messages cross-read and confirmed matching. |
| **AT-2** — rejects a `-`-prefixed token and an empty owner list, each a usage error, non-zero exit, zero network calls | Pre-flight validation (dash-check + zero-token check) sits strictly before `bot-auth.sh` is sourced. | **Executed** against dummy slug `example-org/example-repo`: dash-token case (row 4 above) and empty-after-split case (row 6 above) — both non-zero exit, both stderr from the script's own validation, no `gh`/`bot-auth` output in either. |
| **AT-3** — the exact original bug (`OWNER/REPO --confirmed`, `--reviewers` never supplied) exits non-zero with a usage error, no writes | `CONFIRMED` check passes, then `[ -n "$REVIEWERS" ]` fails → "missing --reviewers" — the exact regression path. | **Executed** (row 3 above): non-zero exit, exact "missing --reviewers" message, zero `gh` calls of any kind before the exit. |

---

## Autonomous Decisions

| # | Decision Point | Options Considered | Chose | Rationale |
|---|----------------|--------------------|-------|-----------|
| 1 | Verification row 5 (`--reviewers "" --confirmed`) surfaces bash's `${1:?--reviewers needs a value}` message rather than the `[ -n "$REVIEWERS" ]` guard's "missing --reviewers" message that the design's own message-table row 5 and inline prose describe for this exact input shape. | (a) Implement the design's copy-paste-ready code block verbatim, as directed, and note the resulting message-text nuance; (b) rewrite the flag-parsing loop's `--reviewers` case to defer the empty check to `[ -n "$REVIEWERS" ]` so the message matches the design's prose exactly. | **(a)** — implemented the code block byte-for-byte as given; logged the nuance here rather than silently deviating from the authoritative, explicitly-"copy-paste-ready" block. | Root cause: bash's `${var:?word}` expansion fires on both *unset* and *null* (empty-string) parameters — an intentional, well-known bash semantic, not a bug in my transcription. The design's code and its own descriptive prose are marginally inconsistent for this one sub-case (`--reviewers` given an explicit empty-string value, as opposed to `--reviewers` omitted entirely, which correctly still hits "missing --reviewers"). Behaviorally nothing is at risk: still a usage error, still non-zero exit, still zero network calls, and it is not one of AT-2's two mandated executed checks (`"-x alice"` / `"   "`) nor AT-3's case (`--reviewers` omitted) — both of those pass with the design's exact intended message text (rows 3/4/6 above). Rewriting the parsing loop to chase the prose would mean deviating from an explicitly authoritative, verbatim code block over a cosmetic message-text mismatch in a case none of the three ATs actually exercise — smallest-correct-change says implement the code as given and disclose the nuance for the composer/reviewer to see. |

No other decision forks were encountered — the design's file manifest, replacement blocks, and single-line diff were unambiguous and directly executable.

---

## Blockers / Deviations from the design

None. All three files match the design's manifest exactly; no scope was added or omitted; the one nuance above is a disclosed, non-blocking observation about message-text provenance, not a deviation from the specified code or a blocker.

## Status: ✅ COMPLETE
