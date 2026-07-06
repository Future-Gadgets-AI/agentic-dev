# BUILD REPORT: ISSUE_65_IMPLEMENT_SKILL_CITATION

**Requirements source:** Future-Gadgets-AI/agentic-dev#65 — "[TASK] implement skill: committed DESIGN/BUILD_REPORT must cite the source issue, not the gitignored synthesized DEFINE"

**Design:** [`../features/DESIGN_ISSUE_65_IMPLEMENT_SKILL_CITATION.md`](../features/DESIGN_ISSUE_65_IMPLEMENT_SKILL_CITATION.md)
**Date:** 2026-07-06
**Branch:** `fix/implement-skill-issue-citation`
**Status:** **Complete**

> Headless build (Phase 3) applying the design's six precise Before/After text edits to
> `plugin/skills/implement/SKILL.md`. Prose-only change, one file, no code. This report is itself
> the first dogfood proof of the rule it ships: it cites the issue above, not this run's own
> gitignored synthesized input file (which is not named anywhere in this document).

---

## Summary

| Metric | Value |
|--------|-------|
| **Manifest execution** | 1/1 file (0 created, 1 modified) — exactly the design's manifest |
| **Edits applied** | 6/6 — (a), (b1), (b2), (c), (d), (e) — all located by the design's quoted Before text, all matched on first try |
| **Agents used** | 0 (direct — design assigns `(general)`; faithful transcription of exact Before/After blocks, no code generation) |
| **Git commits / pushes / `gh` calls** | 0 (worked only in the local tree; composer commits) |
| **Files touched** | 1 (`plugin/skills/implement/SKILL.md`) |
| **Verification commands run** | 15 (grep/inspection), all passed |

---

## Files touched

| File | Action |
|---|---|
| `plugin/skills/implement/SKILL.md` | Modify — six text edits across five sections, prose-only |

### Per-edit landing

| Edit | Section | What changed | Landed |
|---|---|---|---|
| (a) | Step 1 | Pure insertion after the existing final paragraph: two new paragraphs + a `# DEFINE — <title>` / `**Source issue:** ...` template block, making `Source issue` a required header field on the synthesized doc | Yes |
| (b1) | Step 2 — invocation bullets | Agent-only bullet extended to require restating the citation rule in its briefing; new `**Citation requirement (either surface):**` paragraph added | Yes |
| (b2) | Step 2 — capture-artifact sentence | Appended a clause instructing confirmation that the DESIGN artifact's citation names the issue, not the synthesized file | Yes |
| (c) | Step 3 | Added an agent-briefing citation carry-over clause, plus a sentence stating the BUILD_REPORT carries the same citation requirement as DESIGN | Yes |
| (d) | DOs/DON'Ts | One clause appended to the `DO:` chain and one to the `DON'T:` chain | Yes |
| (e) | Smoke procedure | One new `grep`-based bullet added to item 3's list, before item 4 | Yes |

**Scope confirmation:** no other files touched. `git status --short` shows only this one modified tracked file (the pre-existing untracked `DESIGN_ISSUE_65_IMPLEMENT_SKILL_CITATION.md` is unrelated, already present before this build phase started, and was not moved or edited).

---

## Verification

All commands run for real, from the working directory, against `plugin/skills/implement/SKILL.md`.

| # | Edit | Command | Real output | Result |
|---|------|---------|--------------|--------|
| 1 | (a) | `grep -n "header \*\*must\*\* carry a required" SKILL.md` | `52:The doc's header **must** carry a required \`Source issue\` field...` | Pass |
| 2 | (a) | `grep -n "^# DEFINE — <short, human-readable title>$" SKILL.md` | `55:# DEFINE — <short, human-readable title>` | Pass — template block present |
| 3 | (a) | `grep -n '^\*\*Source issue:\*\* \`<owner>/<repo>#<N>\`' SKILL.md` | `57:**Source issue:** \`<owner>/<repo>#<N>\` — <issue title, verbatim>` | Pass |
| 4 | (b1) | `grep -n 'file path and "run headlessly, do not ask questions\."' SKILL.md` (old ending) | no match | Pass — superseded text gone |
| 5 | (b1) | `grep -n "^\*\*Citation requirement (either surface):\*\*" SKILL.md` | `68:**Citation requirement (either surface):** the design phase's own \`DESIGN_<SLUG>.md\` must cite **the source issue**...` | Pass |
| 6 | (b2) | `grep -n "the deviation) and skim it" SKILL.md` (old fragment) | no match | Pass — superseded text gone |
| 7 | (b2) | `grep -n "confirm its citation names the issue" SKILL.md` | `72:...and confirm its citation names the issue, not this skill's synthesized file, while you're in there.` | Pass |
| 8 | (c) | `grep -n "design artifact as its input\. It writes code" SKILL.md` (old fragment) | no match | Pass — superseded text gone |
| 9 | (c) | `grep -n "carries the same citation requirement as the DESIGN artifact" SKILL.md` | `78:...which carries the same citation requirement as the DESIGN artifact: it must cite **the source issue**...` | Pass |
| 10 | (d) | `grep -n "gitignore only the synthesized input\.$" SKILL.md` (old DO ending) | no match | Pass — superseded, DO line now continues |
| 11 | (d) | `grep -n "commit the synthesized design-input\.$" SKILL.md` (old DON'T ending) | no match | Pass — superseded, DON'T line now continues |
| 12 | (d) | `grep -n "require the source issue (never the synthesized file)" SKILL.md` | `142:**DO:** ...· require the source issue (never the synthesized file) as the cited requirements source in both DESIGN and BUILD_REPORT.` | Pass |
| 13 | (d) | `grep -n "let a committed artifact cite" SKILL.md` | `144:**DON'T:** ...· let a committed artifact cite \`_synthesized/DEFINE_<SLUG>.md\`'s own path as its requirements source.` | Pass |
| 14 | (e) | `grep -n 'grep -n "Source issue" .claude/sdd/_synthesized' SKILL.md` | `132:   - \`grep -n "Source issue" .claude/sdd/_synthesized/DEFINE_<SLUG>.md\`...proves the citation rule end to end...` | Pass — new bullet present, item 4 still immediately follows at line 133 |
| 15 | scope | `git status --short` / `git diff --stat` | ` M plugin/skills/implement/SKILL.md` (only tracked change); `1 file changed, 18 insertions(+), 5 deletions(-)` | Pass — exactly the one manifest file |

Full file also re-read end to end after all six edits (not just grep) to confirm no stray changes outside the six intended hunks.

---

## Autonomous Decisions

| # | Decision Point | Options Considered | Chose | Rationale |
|---|----------------|--------------------|-------|-----------|
| 1 | Edit-table granularity | Five rows, one per design letter (a)–(e) vs. six rows honoring the design's own internal split | Six rows: (a), (b1), (b2), (c), (d), (e) | The design itself frames (b) as "two sub-edits in the same section" with two distinct Before/After blocks at two different sentences in Step 2; collapsing them into one row would hide that Step 2 changed in two separate places |
| 2 | Verification approach | Re-run the DESIGN's own AT-1/AT-2 grep commands (those target `DESIGN_*.md`/`BUILD_REPORT_*.md` citation strings) vs. targeted before/after-phrase greps against the actual edit target | Targeted before/after-phrase greps against `plugin/skills/implement/SKILL.md` | AT-1/AT-2's commands verify a *future* run's produced artifacts, not this build's own edit target; this task's own instructions asked for a distinctive-phrase grep per edit plus confirmation the superseded Before-only text is gone — that is what edits (b1)/(b2)/(c)/(d) required (in-place replacement), while (a)/(e) are pure insertions verified by presence alone |

---

## Acceptance criteria mapping

| AT | Satisfied by | Proof |
|----|--------------|-------|
| **AT-3** — Step 1 template shows the issue reference as a required header field | Edit (a) | New template line now in Step 1: `**Source issue:** \`<owner>/<repo>#<N>\`` — <issue title, verbatim>`, preceded by "The doc's header **must** carry a required `Source issue` field" |
| **AT-1** — next `DESIGN_*.md` cites the source issue, no `_synthesized/` references | Edits (b1)/(b2), prospectively | Next `implement` run is now instructed to cite the issue per Step 2's new `**Citation requirement**` paragraph. Dogfood proof available today: `DESIGN_ISSUE_65_IMPLEMENT_SKILL_CITATION.md` already cites `Future-Gadgets-AI/agentic-dev#65` as its requirements source and never names its own gitignored input file |
| **AT-2** — next `BUILD_REPORT_*.md` cites the source issue, no `_synthesized/` references | Edit (c), prospectively | Next `implement` run's build phase now carries the identical rule per Step 3's new sentence. Dogfood proof: this very document — see the **Requirements source** line at the top, naming `Future-Gadgets-AI/agentic-dev#65`; this report likewise never names its own run's gitignored synthesized input file |

---

## Status: ✅ COMPLETE
