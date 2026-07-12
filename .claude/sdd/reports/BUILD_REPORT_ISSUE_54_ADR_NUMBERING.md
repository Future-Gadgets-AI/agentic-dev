# BUILD REPORT: ISSUE_54_ADR_NUMBERING

**Requirements source:** Future-Gadgets-AI/agentic-dev#54 — "[BUG] create-adr/publish-issue: documented ADR numbering (number = issue number) contradicts the board's sequential practice"

**Design:** [`../features/DESIGN_ISSUE_54_ADR_NUMBERING.md`](../features/DESIGN_ISSUE_54_ADR_NUMBERING.md)
**Date:** 2026-07-12
**Branch:** `fix/adr-sequential-numbering`
**Status:** **Complete**

> Headless build (Phase 3) applying the design's two exact Before/After prose edits — one bullet in
> `plugin/skills/create-adr/SKILL.md`, one section in `plugin/skills/publish-issue/SKILL.md`. Docs-only,
> no code, no tests, no `gh` writes. This report cites the issue above as its requirements source; no
> gitignored, fresh-clone-unreachable local working file is named anywhere in this document.

---

## Summary

| Metric | Value |
|--------|-------|
| **Manifest execution** | 2/2 files (0 created, 2 modified) — exactly the design's manifest |
| **Edits applied** | 2/2 — (1) `create-adr` `**Number**` bullet, (2) `publish-issue` `### ADRs specifically` section — both located by the design's quoted Before text, matched verbatim on first try |
| **Agents used** | 0 (direct — design assigns `(general)` to both files; verbatim transcription of the design's exact Before/After blocks, no code generation, no rephrasing) |
| **Git commits / pushes / `gh` calls** | 0 (worked only in the local tree; composer commits — no `gh` command was even needed, since the design's own Verification section already proved the allocator snippet read-only) |
| **Files touched** | 2 (`plugin/skills/create-adr/SKILL.md`, `plugin/skills/publish-issue/SKILL.md`) |
| **Verification commands run** | 5 (grep/inspection + `git diff --stat`/`git status`), all passed |

---

## Files touched

| File | Action |
|---|---|
| `plugin/skills/create-adr/SKILL.md` | Modify — replaced the `**Number**` bullet's numbering-rule clause (issue-number claim → sequential-from-the-board claim); every other clause of the bullet, and every other line in the file, unchanged |
| `plugin/skills/publish-issue/SKILL.md` | Modify — replaced `### ADRs specifically`'s single wrong-rule sentence with the design's 4-step allocate / re-check / retitle / never-reuse mechanism; every other line in the file unchanged |

### Per-edit landing

| Edit | Design section | File | What changed | Landed |
|---|---|---|---|---|
| (1) | "(1) `create-adr/SKILL.md`" | `plugin/skills/create-adr/SKILL.md` line 20 | `**Number**` bullet: "the real number is assigned when published as an issue" → explicit sequential-at-publish-time rule, naming `publish-issue` as the mechanism owner, plus an explicit negation of the old (issue-number) rule | Yes |
| (2) | "(2) `publish-issue/SKILL.md`" | `plugin/skills/publish-issue/SKILL.md` lines 42–43 | `### ADRs specifically`: one wrong-rule sentence → header sentence + 4-step mechanism (allocate max+1 / re-check before retitle / retitle+substitute / never reuse) | Yes |

**Scope confirmation:** no other files touched. `git status --short` shows exactly the two modified tracked files above, plus the pre-existing untracked `.claude/sdd/features/DESIGN_ISSUE_54_ADR_NUMBERING.md` (already present before this build phase started, part of the SDD artifact trail, not created or moved by this build). `plugin/skills/refine-issue/*` was not read, opened, or touched — confirmed out of scope per the design and the task's hard constraints (a separate, parallel PR for issue #75 covers it).

---

## Verification

All commands run for real, from the working directory, against the two edited files.

| # | Check | Command | Real output | Result |
|---|---|---|---|---|
| 1 | AT-001 — no numbering-rule claim left | `grep -rn "issue number" plugin/skills/create-adr plugin/skills/publish-issue` | *(no output, exit code 1 = zero matches)* | Pass |
| 1b | AT-001 — case-insensitive sweep (extra rigor, per design's own verification note) | `grep -rni "issue number" plugin/skills/create-adr plugin/skills/publish-issue` | *(no output, exit code 1 = zero matches)* | Pass |
| 2 | Placeholder still present, correct spelling (three X's, per Decision 4) | `grep -c "ADR-XXX" plugin/skills/create-adr/SKILL.md plugin/skills/publish-issue/SKILL.md` | `plugin/skills/create-adr/SKILL.md:2` / `plugin/skills/publish-issue/SKILL.md:1` | Pass — placeholder retained in both files |
| 3 | Scope — exactly the two manifest files changed | `git diff --stat` | ` plugin/skills/create-adr/SKILL.md \| 2 +-` / ` plugin/skills/publish-issue/SKILL.md \| 12 +++++++++++-` / `2 files changed, 12 insertions(+), 2 deletions(-)` | Pass — exactly the two manifest files |
| 4 | Working tree — no stray untracked/staged changes, nothing committed | `git status --short` | ` M plugin/skills/create-adr/SKILL.md` / ` M plugin/skills/publish-issue/SKILL.md` / `?? .claude/sdd/features/DESIGN_ISSUE_54_ADR_NUMBERING.md` | Pass — only the two edits + the pre-existing DESIGN doc; nothing staged or committed |
| 5 | `refine-issue` untouched | `git status --short plugin/skills/refine-issue` | *(empty)* | Pass |

`git diff` for both files was also read back in full after applying the edits and compared line-by-line against the design's "After" blocks (sections "(1)" and "(2)") — byte-for-byte match, including the nested ` ```bash ` fence inside `publish-issue`'s new numbered list.

No `gh` command of any kind was run during this build (not even the read-only sanity check the task permitted) — the design's own Verification section had already proven the allocator snippet against the live board read-only, so no re-check was necessary to satisfy this build's scope.

---

## Autonomous Decisions

| # | Decision Point | Options Considered | Chose | Rationale |
|---|----------------|--------------------|-------|-----------|
| 1 | Outer 4-backtick fence in the design's "After" block for edit (2) | Copy the design's literal 4-backtick fence (` ```` `) into the actual `SKILL.md` file vs. treat it as the design doc's own display-escaping device (needed only because the block contains a nested 3-backtick ` ```bash ` block) and write plain markdown | Treated it as display-escaping; wrote the section as normal markdown containing one native 3-backtick `bash` fence, matching the file's existing fence style elsewhere in the document | The design uses 3-backtick fences everywhere else (including in edit (1)'s Before/After and the "Verification" section's own `gh` transcript); the 4-backtick fence in section "(2)" only appears because Markdown requires a longer outer fence to literally display a block that itself contains a 3-backtick fence — a formatting convention for the design *document*, not target content to reproduce in the *destination* file. Reproducing 4 backticks in the actual `SKILL.md` would have broken that file's own fenced code rendering |
| 2 | Whether to run the permitted read-only `gh issue list` sanity check | Run it again (redundant self-check) vs. skip it since the design already ran and transcribed the identical read-only verification | Skipped — relied on the design's own already-executed, transcribed verification (max=`0009`) | The task explicitly frames this as optional ("If you choose to..."), not required; the design's Verification section already produced and logged the exact transcript this build would reproduce byte-for-byte, so re-running adds no new information and only adds an unnecessary `gh` call against the live board |
| 3 | Whether to update a DESIGN/DEFINE "Status" field to "Built" (per this agent's general quality-gate checklist) | Add a `Status: Built` line to the DESIGN doc vs. leave it as-is | Left it as-is — no edit made to the DESIGN doc | `DESIGN_ISSUE_54_ADR_NUMBERING.md` carries no `Status` field at all (confirmed by reading it in full); the task's own numbered instructions (1–3) are exhaustive for this run and do not include a DESIGN-doc edit, and the hard constraints say "Do not create any files other than the BUILD_REPORT" — editing the DESIGN doc's status was not requested and risks scope creep on a docs-only fix whose target files are explicitly named |

No decision fork rose to CRITICAL risk; nothing was halted or escalated.

---

## Deviations from design

None. Both edits were applied character-for-character from the design's "After" blocks (sections "(1)" and "(2)"). The design's own Decision 3 and Decision 4 already reconciled the DEFINE-vs-ground-truth discrepancies (bracket-free `grep -oE 'ADR-[0-9]+'`, `ADR-XXX` three-X placeholder) *before* this build phase — those were design-time corrections, not build-time deviations, and the build reproduced the design's resulting text exactly, including the corrected regex and placeholder spelling.

---

## Acceptance criteria mapping

| AT | Satisfied by | Proof |
|----|--------------|-------|
| **AT-001** | Both edits | `grep -rn "issue number" plugin/skills/create-adr plugin/skills/publish-issue` → no output (verification table, row 1); case-insensitive sweep also clean (row 1b) |
| **AT-002** | Edit (2), inherited from the design's Decision 3 | Not re-run in this build (no `gh` call made — see Autonomous Decision 2); the design's own Verification section already ran the corrected snippet read-only against the live board and recorded `0009`, which is what the shipped "After" text (now live in `plugin/skills/publish-issue/SKILL.md`) encodes verbatim |
| **AT-003** | Scope of this entire build | No `gh issue create` / `edit` / `close` was run at any point during this build — verified by this build's own command history (grep, git-only) and `git status --short` showing zero interaction with GitHub state |

---

## Status: ✅ COMPLETE
