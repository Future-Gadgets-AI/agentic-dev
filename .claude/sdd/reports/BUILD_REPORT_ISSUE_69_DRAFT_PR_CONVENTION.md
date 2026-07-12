# BUILD REPORT: ISSUE_69_DRAFT_PR_CONVENTION

**Source issue:** `Future-Gadgets-AI/agentic-dev#69` — [TASK] Document the draft-PR + ready-flip convention for reviewers

**Design:** [`../features/DESIGN_ISSUE_69_DRAFT_PR_CONVENTION.md`](../features/DESIGN_ISSUE_69_DRAFT_PR_CONVENTION.md)
**Date:** 2026-07-12
**Branch:** `docs/draft-pr-convention`
**Status:** **Complete**

> Headless build (Phase 3), executed autonomously with no questions asked, per the run's own
> instructions. Docs-only reconciliation: three additive-only insertions, one per file, exactly
> as specified in the design's Anchor(before)/Anchor(after)/Insert blocks. No deletions, no edits
> to any existing line, no file beyond the three named.

---

## Summary

| Metric | Value |
|--------|-------|
| **Manifest execution** | 3/3 files (0 created, 3 modified) — exactly the design's manifest |
| **Insertions applied** | 3/3 — one new `##` section in `lifecycle.md`, one new blockquote in `review-pr/SKILL.md`, one new paragraph in `ARCHITECTURE.md` — every Anchor(before)/Anchor(after) pair matched the live file verbatim on first read |
| **Agents used** | 0 (direct — task explicitly calls for no sub-delegation on three insertions; verbatim transcription of the design's exact Insert blocks) |
| **Git commits / pushes / `gh` calls** | 0 (worked only in the local tree; composer commits/pushes) |
| **Files touched** | 3 (`plugin/contracts/lifecycle.md`, `plugin/skills/review-pr/SKILL.md`, `ARCHITECTURE.md`) |
| **Lines changed** | +7 / −0 total (3/0, 2/0, 2/0 per file) |
| **Verification commands run** | 5 (3 grep AT checks, 1 numstat, 1 `-U0` diff), all passed |

---

## Files touched

| File | Action | Insertion point |
|---|---|---|
| `plugin/contracts/lifecycle.md` | Insert new `## The draft-PR + ready-flip convention` section | Between the tail of the "Ownership boundary — where humans stay" paragraph and `## Minimalism` |
| `plugin/skills/review-pr/SKILL.md` | Insert new `> **Draft status is expected — not a finding.**` blockquote | Between the `> **Identity.**` blockquote and `## Detect the repo first (never hardcode)` |
| `ARCHITECTURE.md` | Insert new `**PR status.**` paragraph | Between the `**Readiness**` paragraph and `## The gates`, inside `## The issue lifecycle` |

**Blank-line spacing:** each insertion used the host file's own existing section-spacing convention, confirmed by reading the surrounding lines before editing, not assumed: `lifecycle.md`'s `##` sections have no blank line between the heading and its first content line (matching e.g. `## Ownership boundary — where humans stay` → content on the very next line), so the new section follows the same shape; `review-pr/SKILL.md`'s framing blockquotes (skepticism, identity) are each separated by exactly one blank line, so the new blockquote slots in the same way; `ARCHITECTURE.md`'s prose paragraphs inside `## The issue lifecycle` are blank-line separated, so the new paragraph follows suit. One blank line before and after every insertion, in all three files.

**Scope confirmation:** `git status --short` shows exactly these three tracked files modified, plus the pre-existing untracked `.claude/sdd/features/DESIGN_ISSUE_69_DRAFT_PR_CONVENTION.md` (the design artifact this build read from — not created or touched by this build). `CONSTITUTION.md` was not touched (grep for it in `git diff --name-only` returns nothing). The ASCII diagram in `ARCHITECTURE.md` (lines 14–19) was not touched — the new paragraph lands after it, inside the same `## The issue lifecycle` section but outside the fenced diagram block, per the design's explicit instruction not to hand-edit fixed-width ASCII art.

---

## Verification

All commands run for real, from the working directory, after all three edits landed.

### AT-1 — `lifecycle.md` new section present, protected spots untouched

```
$ grep -n "draft-PR + ready-flip convention" plugin/contracts/lifecycle.md
26:## The draft-PR + ready-flip convention
```
Hit — pass.

### AT-2 — `review-pr/SKILL.md` new blockquote present

```
$ grep -n "Draft status is expected" plugin/skills/review-pr/SKILL.md
14:> **Draft status is expected — not a finding.** The autonomous engine opens every headless PR as a **draft** — you're typically reviewing a draft, not a ready-for-merge PR, and that alone is never a reason to request changes or hold off. The human flips it ready and merges at the Ready-to-merge step, informed by your review, never blocked on it (`plugin/contracts/lifecycle.md`).
```
Hit — pass.

### AT-3 — `ARCHITECTURE.md` new paragraph present

```
$ grep -n "PR status\." ARCHITECTURE.md
23:**PR status.** Every PR the engine opens is a **draft** by default; the Review row's blind-review runs against that draft, and draft status there is expected, not a finding. The human flips it ready and merges — one action, not two — at Ready-to-merge (`plugin/contracts/lifecycle.md`).
```
Hit — pass. Its key phrases (draft / expected, not a finding / flips ready and merges, one action) line up with `lifecycle.md`'s new section and `review-pr/SKILL.md`'s new blockquote, citing `lifecycle.md` as the source of record, per the design's rationale.

### `git diff --numstat` — additive-only across all three files

```
$ git diff --numstat
2	0	ARCHITECTURE.md
3	0	plugin/contracts/lifecycle.md
2	0	plugin/skills/review-pr/SKILL.md
```
Pass — 3 files, 7 lines added total, **0 deletions on all three**.

### `git diff -U0 -- plugin/contracts/lifecycle.md` — protected wording byte-identical

```diff
diff --git a/plugin/contracts/lifecycle.md b/plugin/contracts/lifecycle.md
index 2cab3fd..ec7251c 100644
--- a/plugin/contracts/lifecycle.md
+++ b/plugin/contracts/lifecycle.md
@@ -25,0 +26,3 @@ Humans own exactly three points — **Refinement**, **Escalated**, and **Ready-t
+## The draft-PR + ready-flip convention
+The autonomous engine opens every PR as a **draft** — the headless default (`/pickup`, `a2a-workflow`). The blind review in the **Review** row above runs against that draft, not a ready-for-merge PR: draft status there is expected, never itself a review finding. The human flips the PR ready and merges it — the same action, not two separate steps — at **Ready-to-merge**.
+
```
Pass — only `+` lines; no `-` lines anywhere in the file. The **Review** table row and the **"Ownership boundary — where humans stay"** paragraph (both reconciled by the sibling PR for issue #58, commit `eb32ab6`) are untouched — the diff context line (`Humans own exactly three points…`) is the paragraph's own trailing line, present only as unchanged context, confirming the new section was appended strictly after it.

---

## Autonomous Decisions

| # | Decision Point | Options Considered | Chose | Rationale |
|---|----------------|--------------------|-------|-----------|
| 1 | Blank-line spacing around each insertion (design specifies "the file's normal blank-line spacing on both sides" but leaves the exact shape to Build) | (a) Always insert with a blank line between heading and content; (b) match each file's own observed convention per-section | (b) — read each file's surrounding sections first, then mirrored the exact pattern found (no blank between `##` heading and its content line in `lifecycle.md`; blank-line-separated blockquotes in `review-pr/SKILL.md`; blank-line-separated paragraphs in `ARCHITECTURE.md`) | Smallest-correct-change: making the new content visually indistinguishable from its neighbors, rather than imposing a single spacing rule the file doesn't otherwise use |

No other decision forks arose. All three Anchor(before)/Anchor(after) pairs matched the live files verbatim on the first read, and all three Insert blocks were transcribed character-for-character from the design.

---

## Acceptance-test verification against the design's own AT table

| AT | Design's check | Result |
|---|---|---|
| AT-1 | `grep -A2 "draft-PR + ready-flip convention" plugin/contracts/lifecycle.md` finds the new section; `git diff HEAD -- plugin/contracts/lifecycle.md` shows only added (`+`) lines | Pass — new section at line 26; `-U0` diff (above) confirms zero `-` lines |
| AT-2 | `grep -B1 -A2 "Draft status is expected" plugin/skills/review-pr/SKILL.md` finds the new blockquote positioned between `Identity` and `## Detect the repo first` | Pass — new blockquote at line 14, directly between the Identity blockquote (line 12) and `## Detect the repo first (never hardcode)` (line 16) |
| AT-3 | `grep -A2 "PR status\." ARCHITECTURE.md` finds the new paragraph inside `## The issue lifecycle`; key phrases line up with `lifecycle.md`'s new section | Pass — new paragraph at line 23, inside `## The issue lifecycle` (spans lines 11–30), directly before `## The gates` (line 25) |

---

## Blockers

None. All three insertions landed exactly as designed; no design gap, no CRITICAL risk, no retry needed.

---

## Status: COMPLETE
