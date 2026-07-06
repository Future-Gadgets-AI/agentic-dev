# DESIGN — ISSUE_65_IMPLEMENT_SKILL_CITATION

**Requirements source:** Future-Gadgets-AI/agentic-dev#65 — "[TASK] implement skill: committed DESIGN/BUILD_REPORT must cite the source issue, not the gitignored synthesized DEFINE"

> Phase 2 (DESIGN) artifact for issue #65 — the `implement` skill's committed traceability
> artifacts (`DESIGN_*.md`, `BUILD_REPORT_*.md`) must cite the source issue, never the gitignored
> `.claude/sdd/_synthesized/DEFINE_*.md` they're assembled from. Headless run. This document is
> itself the first dogfood proof: it cites the issue above, not this run's own synthesized input.

## Scope

**In** — five text edits to `plugin/skills/implement/SKILL.md`, all prose/instruction-only (no
code, no other files touched):

1. **(a) Step 1** — a required `Source issue` header field (+ a minimal template) on the
   synthesized `DEFINE_<SLUG>.md` doc. Satisfies AT-3.
2. **(b) Step 2** — instructs whichever surface runs (skill, or a briefed agent) to cite that
   field — never the `_synthesized/` path — as `DESIGN_<SLUG>.md`'s requirements source; for an
   agent-only surface, restate the rule explicitly in its spawn briefing. Feeds AT-1.
3. **(c) Step 3** — the identical rule, carried into `BUILD_REPORT_<SLUG>.md`. Feeds AT-2.
4. **(d) DOs/DON'Ts** — one line added to each, turning the rule into an explicit behavioral
   contract rather than only Step-embedded prose. *(Judgment call, per the task's own invitation —
   taken; see Decision 5.)*
5. **(e) Smoke procedure** — one new bullet: a `grep`-based check proving both committed artifacts
   cite the issue and neither leaks a `_synthesized` reference. *(Same judgment call as (d).)*

**Out** (explicitly not touched):

- `## Artifact placement` — the committed/gitignored split itself stays structurally as-is; only
  referenced below, never edited.
- Step 0 (env pre-check), Step 4 (parse/return), `## What this skips, and why`,
  `## Method attribution` — none are touch points this task named.
- Retrofitting `DESIGN_ISSUE_34_WHATS_NEEDED_ME.md`, `DESIGN_ISSUE_36_REPO_HARDENING.md`, or
  `BUILD_REPORT_ISSUE_34_WHATS_NEEDED_ME.md` — historical, already-merged artifacts; cited below as
  defect evidence, not modified.
- Any git/gh write — this design phase produces only this file.

---

## Prior art

- **`gear#17`** (PR `fix/tldr-dedupe-post-template`) — already dogfooded this exact citation
  pattern: both of its committed artifacts cite the issue, not a synthesized file.
- **This repo's own PR #70** (issue #66 → `DESIGN_ISSUE_66_REPO_STANDARD_SCRIPT_INTERFACES.md`)
  **and PR #71** (issue #67 → `DESIGN_ISSUE_67_REPO_STANDARD_FREE_PLAN_CARVEOUT.md`) — both already
  cite their source issue directly in the header blockquote ("Phase 2 (DESIGN) artifact for issue
  #NN"), and neither carries a `DEFINE` metadata-table row at all. (The earlier
  `DESIGN_ISSUE_34`/`36` template did carry one, pointed at `../_synthesized/...` — that row is
  exactly where the dead link lived.) This design follows that same structural fix — no
  metadata-table row to point anywhere, full stop — rather than inventing a third citation style.
  This issue's job is to encode that already-proven practice into the skill's own instructions, so
  it's guaranteed on every future run rather than incidental to whoever remembers.
- **Confirmed defect evidence, already committed in this repo** (predating the PR #70/#71 practice
  above): `.claude/sdd/features/DESIGN_ISSUE_34_WHATS_NEEDED_ME.md` and
  `.claude/sdd/features/DESIGN_ISSUE_36_REPO_HARDENING.md` both cite
  `../_synthesized/DEFINE_ISSUE_*.md` in a `DEFINE` metadata-table row; and
  `.claude/sdd/reports/BUILD_REPORT_ISSUE_34_WHATS_NEEDED_ME.md` cites the same dead path. Each is
  unreachable from a fresh clone — exactly the failure a blind reviewer of `cc-plugins#4` hit first
  (per the DEFINE). **Not retrofitted by this change** (explicit non-goal, per the DEFINE and
  repeated here): this design is prospective — it shapes what the *next* `implement` run produces,
  not what already merged.

---

## Architecture — pipeline & touch points

```text
Step 0 — env pre-check                                              [UNCHANGED]
  resolves the design/build entrypoints at runtime, never hardcoded
        │
        ▼
Step 1 — synthesize .claude/sdd/_synthesized/DEFINE_<SLUG>.md  ◀──── EDIT (a)
  header GAINS a required `Source issue` field: `owner/repo#N` + title
        │
        ▼
Step 2 — invoke design (skill, or agent briefed)  ─────────────────── EDIT (b)
  writes .claude/sdd/features/DESIGN_<SLUG>.md
  MUST cite Step 1's `Source issue` field — never the _synthesized/ path
  (agent-only surface: rule restated explicitly in the briefing)
        │
        ▼
Step 3 — invoke build (same surface rules as Step 2)  ─────────────── EDIT (c)
  writes .claude/sdd/reports/BUILD_REPORT_<SLUG>.md
  SAME citation rule carries over — never the _synthesized/ path
        │
        ▼
Step 4 — parse BUILD_REPORT, return to caller                       [UNCHANGED]

DOs/DON'Ts ── one line added to each (EDIT d)   ─┐  makes the rule
Smoke procedure ── one new grep check (EDIT e)  ─┘  explicit + checkable
```

---

## Key Decisions

### Decision 1: Field name and placement — `Source issue` as a required header field, not new ceremony

**Context:** AT-3 asks Step 1's template to show the issue reference as a required header field;
Step 1's own text is explicit that the synthesized doc is deliberately "thinner" than a full
interactive DEFINE (no clarity score, no target-users table, no assumptions ledger).

**Choice:** add exactly one required field, `Source issue`, to the header — matching the field name
already used, unprompted, by this very run's own synthesized input (its own header reads
`**Source issue:** \`Future-Gadgets-AI/agentic-dev#65\` — ...`) — plus a minimal template block
showing where it sits (H1, then this field, on the very next line).

**Rationale:** one field is proportionate to "assemble, don't invent" — it doesn't reopen the
"thinner than DEFINE" decision, it just names the one fact Steps 2/3 need to read back out. Reusing
the field name already present in the wild keeps this design consistent with what's already
happening rather than inventing a second, competing name for the same fact.

**Alternatives Rejected:** a full Metadata table (disproportionate ceremony for one fact, and
reopens "thinner" without cause); a separate `## Source` section (same problem, plus splits one
field awkwardly across a whole heading).

**Consequences:** Step 1 gains one required field to populate; Steps 2/3 gain one field to read.

### Decision 2: Citation instruction lives as `implement`'s own prose, not an edit to another plugin's template

**Context:** Step 0 is explicit that the design/build entrypoints are "not vendored in this
plugin" and instructs "Never hardcode a specific plugin's namespace" — `implement` doesn't own or
control whichever separately-installed SDD plugin resolves at runtime, so it cannot reach into that
plugin's own DESIGN/BUILD_REPORT template file.

**Choice:** express the citation requirement as an instruction `implement` itself carries and passes
along at invocation time (skill-surface: implicit in what's read; agent-surface: explicit in the
spawn briefing) — never as an edit to a template file this skill doesn't own.

**Rationale:** this is the only mechanism available to a skill whose own contract is "discovers the
design/build entrypoints at runtime rather than hardcoding a plugin namespace" (SKILL.md
frontmatter). An instruction requiring an edit to another plugin's internals would break the moment
a different machine installs a different SDD plugin.

**Alternatives Rejected:** patching the resolved design/build plugin's own template (violates the
no-hardcoding contract, and isn't this skill's file to edit); relying on the phase to already do
this unprompted (rejected — issue #65 exists precisely because that assumption already failed in
practice, per the `cc-plugins#4` blind-review finding cited in the DEFINE).

**Consequences:** the rule is carried by `implement`'s own prompt text, so it travels with every
invocation regardless of which SDD plugin is installed — matching the skill's existing
runtime-discovery design.

### Decision 3: Agent-only surface must have the rule restated explicitly in its briefing

**Context:** Step 0 already distinguishes a skill surface (no enforced tool list, judged by framing)
from an agent surface (harness-enforced `Tools:` list); Step 2 already briefs an agent-only surface
with only a file path and "run headlessly, do not ask questions" — a short, literal instruction
set, not a guarantee the agent will read this skill's own file or its conventions.

**Choice:** add "restate the citation requirement... explicitly in that briefing" to the
agent-only bullet, so the rule travels in exactly the same channel (the briefing text) the agent
surface already relies on for every other instruction (headlessness, no questions).

**Rationale:** an agent spawned fresh has no guaranteed access to `implement`'s own SKILL.md text —
only what's in its briefing. A rule that lives only in prose the agent never sees isn't a rule at
all, just a hope.

**Alternatives Rejected:** trust the agent to already follow this convention (same failure mode
#65 documents); make the restatement conditional/optional ("should" degrades to silent
non-compliance, exactly like the current bug).

**Consequences:** the agent-only bullet gains one clause; every future agent-surface briefing must
carry the citation requirement verbatim (or in substance) going forward.

### Decision 4: Step 3 cross-references Step 2's rule rather than restating it in full

**Context:** Step 3's existing text already leans on this pattern — "Call the Step 0 build
entrypoint the same way" defers to Step 2 for invocation mechanics rather than re-explaining them.

**Choice:** Step 3's edit states the BUILD_REPORT "carries the same citation requirement as the
DESIGN artifact" and restates the rule itself only briefly (source, target file, never-the-
synthesized-path) rather than repeating Decision 2/3's full rationale a second time.

**Rationale:** keeps the diff minimal and matches the file's own existing economy of expression; a
reader who wants the full rationale already has it two paragraphs up, in Step 2.

**Alternatives Rejected:** fully duplicate Step 2's citation paragraph verbatim in Step 3 (needless
repetition, working against the instruction to keep the diff minimal and targeted).

**Consequences:** Step 3 gains one sentence, not a full paragraph; the build rule is inseparable
from (and unambiguously identical to) the design rule.

### Decision 5: Make the rule checkable, not just documented

**Context:** the DEFINE's own acceptance tests (AT-1/AT-2) are framed as verifiable end-states
("names the source issue... contains no `_synthesized/` path references"), not documentation goals
alone. A rule that exists only as prose with no corresponding check is exactly the kind of thing
that regresses silently — which is how issue #65 itself arose: the citation habit already existed
informally (gear#17, PR #70/71), but nothing forced or verified it, so `DESIGN_ISSUE_34`/`36` and
`BUILD_REPORT_ISSUE_34` still shipped with the dead-link pattern.

**Choice:** add one bullet each to DOs/DON'Ts (making the rule an explicit behavioral rule, next to
the skill's other DOs/DON'Ts) and to the Smoke procedure (one `grep`-based check, alongside the
existing `git check-ignore` check that already proves the committed/gitignored split the same way).

**Rationale:** matches the file's existing pattern of pairing a behavioral rule with a concrete,
run-it-for-real verification step — the smoke procedure's whole stated purpose ("this repo has no
unit-test harness... the smoke run is the verification").

**Alternatives Rejected:** leave DOs/DON'Ts and Smoke procedure untouched, relying on Steps 1–3's
prose alone (rejected — the task explicitly invites this as a judgment call, and the judgment here
is that an unchecked rule is a rule likely to regress, per the evidence already sitting in this
repo).

**Consequences:** two more single-line additions beyond the three mandatory touch points; both are
purely additive (no existing line removed or reworded) — smallest possible expansion of blast
radius.

---

## (a) Step 1 — required `Source issue` header field

**Insert immediately after** the existing final paragraph of Step 1 (before the `## Step 2`
heading).

**Before** (current, unchanged text — the last paragraph of Step 1):
```markdown
Write the synthesized doc to `.claude/sdd/_synthesized/DEFINE_<SLUG>.md` — `SLUG` = a short, stable, readable tag such as `ISSUE_<N>_<UPPER_SNAKE first few words of the title>` (e.g. issue #52 → `ISSUE_52_IMPLEMENT_SKILL`; the exact casing isn't load-bearing, only stability across this run is). This is the throwaway half of the artifact split — see **Artifact placement**.
```

**After** (same paragraph, unchanged, plus two new paragraphs + a template block appended right
after it, still before `## Step 2`):

````markdown
Write the synthesized doc to `.claude/sdd/_synthesized/DEFINE_<SLUG>.md` — `SLUG` = a short, stable, readable tag such as `ISSUE_<N>_<UPPER_SNAKE first few words of the title>` (e.g. issue #52 → `ISSUE_52_IMPLEMENT_SKILL`; the exact casing isn't load-bearing, only stability across this run is). This is the throwaway half of the artifact split — see **Artifact placement**.

The doc's header **must** carry a required `Source issue` field — `owner/repo#N` plus the issue's title, copied verbatim from the issue you're implementing (never invented, never left out):

```markdown
# DEFINE — <short, human-readable title>

**Source issue:** `<owner>/<repo>#<N>` — <issue title, verbatim>
```

This field is the one durable, reviewable anchor Step 2 and Step 3 read back out, so the committed `DESIGN_<SLUG>.md` / `BUILD_REPORT_<SLUG>.md` they produce can cite **the issue** — not this gitignored file — as their requirements source. This file lives under `.claude/sdd/_synthesized/`, unreachable from a fresh clone; the issue is the durable record a reviewer can actually open.
````

---

## (b) Step 2 — design phase must cite the issue, agent briefing must restate it

Two sub-edits in the same section.

### (b1) — bullet list + new citation-requirement paragraph

**Before:**
```markdown
Call the Step 0 design entrypoint with the Step 1 file as its input:
- **Skill surface** → call it with the Step 1 file's path as the argument.
- **Agent-only surface** → spawn it (never `subagent_type: fork` — this is a fresh phase run, not a continuation of your context), briefing it with the file path and "run headlessly, do not ask questions."

If both surfaces resolved in Step 0, prefer the skill surface — it keeps artifact capture in the main conversation.
```

**After:**
```markdown
Call the Step 0 design entrypoint with the Step 1 file as its input:
- **Skill surface** → call it with the Step 1 file's path as the argument.
- **Agent-only surface** → spawn it (never `subagent_type: fork` — this is a fresh phase run, not a continuation of your context), briefing it with the file path, "run headlessly, do not ask questions," and — since an agent-only surface has no guaranteed read of this skill's own file conventions — restate the citation requirement below explicitly in that briefing, rather than assuming it travels with the file.

**Citation requirement (either surface):** the design phase's own `DESIGN_<SLUG>.md` must cite **the source issue** — the `Source issue` field carried in the Step 1 file's header (`owner/repo#N` + title) — as its requirements source, never `.claude/sdd/_synthesized/DEFINE_<SLUG>.md`'s own path. That file is gitignored and unreachable from a fresh clone; citing it leaves a reviewer checking out the branch with a dead link — the exact defect this rule exists to close.

If both surfaces resolved in Step 0, prefer the skill surface — it keeps artifact capture in the main conversation.
```

### (b2) — capture-the-artifact sentence gains a citation check

**Before:**
```markdown
It writes its artifact to `.claude/sdd/features/DESIGN_<SLUG>.md` — this project's fixed SDD working-area convention, independent of which plugin is providing the phase. Capture the path (if it reports a different one, use that instead and note the deviation) and skim it for the inline decisions it recorded — you'll want the highlights for the PR body later.
```

**After:**
```markdown
It writes its artifact to `.claude/sdd/features/DESIGN_<SLUG>.md` — this project's fixed SDD working-area convention, independent of which plugin is providing the phase. Capture the path (if it reports a different one, use that instead and note the deviation), skim it for the inline decisions it recorded — you'll want the highlights for the PR body later — and confirm its citation names the issue, not this skill's synthesized file, while you're in there.
```

---

## (c) Step 3 — same citation rule carries into `BUILD_REPORT_<SLUG>.md`

**Before:**
```markdown
Call the Step 0 build entrypoint the same way, with the Step 2 design artifact as its input. It writes code per the design's file manifest, plus `.claude/sdd/reports/BUILD_REPORT_<SLUG>.md`.
```

**After:**
```markdown
Call the Step 0 build entrypoint the same way, with the Step 2 design artifact as its input — including, for an agent-only surface, restating the citation requirement in its briefing, exactly as Step 2 does. It writes code per the design's file manifest, plus `.claude/sdd/reports/BUILD_REPORT_<SLUG>.md`, which carries the same citation requirement as the DESIGN artifact: it must cite **the source issue** (`owner/repo#N` + title, from the Step 1 file's header) as its requirements source, never `.claude/sdd/_synthesized/DEFINE_<SLUG>.md`'s own path.
```

---

## (d) DOs / DON'Ts — one line each

**Before:**
```markdown
**DO:** resolve the design/build entrypoints fresh every run, by matching what's actually available · treat a missing or interactive-only phase as a stop, not a workaround · assemble the design-input from the issue's own DoR content, never invent requirements · keep the native DESIGN/BUILD_REPORT as the full record and the summary as the handback contract · gitignore only the synthesized input.

**DON'T:** hardcode a plugin namespace (e.g. `agentspec:...`) as if it's the only possible one · run brainstorm/define/ship · let build's autonomous decisions become questions back to you · round a Blocked or partially-failing build report up to "done" · commit the synthesized design-input.
```

**After:**
```markdown
**DO:** resolve the design/build entrypoints fresh every run, by matching what's actually available · treat a missing or interactive-only phase as a stop, not a workaround · assemble the design-input from the issue's own DoR content, never invent requirements · keep the native DESIGN/BUILD_REPORT as the full record and the summary as the handback contract · gitignore only the synthesized input · require the source issue (never the synthesized file) as the cited requirements source in both DESIGN and BUILD_REPORT.

**DON'T:** hardcode a plugin namespace (e.g. `agentspec:...`) as if it's the only possible one · run brainstorm/define/ship · let build's autonomous decisions become questions back to you · round a Blocked or partially-failing build report up to "done" · commit the synthesized design-input · let a committed artifact cite `_synthesized/DEFINE_<SLUG>.md`'s own path as its requirements source.
```

---

## (e) Smoke procedure — one new checkable bullet

**Before** (item 3's bullet list, plus item 4 for insertion-point context):
```markdown
3. Run Steps 1–4 end to end on that issue; capture:
   - the synthesized `DEFINE_<SLUG>.md` path and a 2–3 line excerpt;
   - the resolved `DESIGN_<SLUG>.md` path and a 2–3 line excerpt;
   - the resolved `BUILD_REPORT_<SLUG>.md` status field;
   - `git status --short` showing the code changes plus the two committed artifacts, with the synthesized input absent;
   - `git check-ignore -v .claude/sdd/_synthesized/DEFINE_<SLUG>.md` (expect: matched) **and** `git check-ignore -v .claude/sdd/features/DESIGN_<SLUG>.md` (expect: not matched) — this is what actually proves the committed/gitignored split, not just the `.gitignore` file's text.
4. Paste the full transcript (commands + output, including the Blocked path if you deliberately trigger one by renaming a plugin) as the smoke evidence.
```

**After** (one new bullet appended to item 3's list, before item 4):
```markdown
3. Run Steps 1–4 end to end on that issue; capture:
   - the synthesized `DEFINE_<SLUG>.md` path and a 2–3 line excerpt;
   - the resolved `DESIGN_<SLUG>.md` path and a 2–3 line excerpt;
   - the resolved `BUILD_REPORT_<SLUG>.md` status field;
   - `git status --short` showing the code changes plus the two committed artifacts, with the synthesized input absent;
   - `git check-ignore -v .claude/sdd/_synthesized/DEFINE_<SLUG>.md` (expect: matched) **and** `git check-ignore -v .claude/sdd/features/DESIGN_<SLUG>.md` (expect: not matched) — this is what actually proves the committed/gitignored split, not just the `.gitignore` file's text.
   - `grep -n "Source issue" .claude/sdd/_synthesized/DEFINE_<SLUG>.md` (expect: one match) **and** `grep -rn "_synthesized" .claude/sdd/features/DESIGN_<SLUG>.md .claude/sdd/reports/BUILD_REPORT_<SLUG>.md` (expect: no matches) — proves the citation rule end to end: both committed artifacts name the source issue, neither leaks a reference to this gitignored file.
4. Paste the full transcript (commands + output, including the Blocked path if you deliberately trigger one by renaming a plugin) as the smoke evidence.
```

---

## File Manifest

| # | File | Action | Purpose | Agent |
|---|------|--------|---------|-------|
| 1 | `plugin/skills/implement/SKILL.md` | Modify | Six precise text edits across five sections: (a) Step 1 required header field + template, (b1)/(b2) Step 2 citation instruction + agent-briefing restatement + capture-check, (c) Step 3 same rule carried into BUILD_REPORT, (d) DOs/DON'Ts one-liners, (e) Smoke procedure one new check | (general — direct prose edit; faithful transcription of this DESIGN's exact Before/After blocks, no code generation requiring a specialist, matching this repo's own precedent for markdown-only design docs — see `BUILD_REPORT_ISSUE_67`'s "Agents used: 0 (direct...)" note) |

**Total Files:** 1. No new files created; no script/code touched. No test harness applicable — this
is a prompt-text change to a Markdown skill file; verification is direct inspection plus the
Smoke procedure's own `grep`/`git check-ignore` checks (edit (e)), matching this repo's established
convention for `.md`-only changes.

---

## Acceptance-test mapping & verification plan

| AT | DEFINE text (summarized) | How this design satisfies it | Verification |
|----|---------------------------|-------------------------------|---------------|
| **AT-1** | Next `implement`-produced `DESIGN_*.md` names the source issue as its requirements source, no `_synthesized/` references. | Edit (b) instructs every surface (skill or briefed agent) to cite the `Source issue` field from Step 1's header, never the synthesized path. **This very document is the first proof — with one honest caveat**: its own header carries the mandatory `Requirements source: Future-Gadgets-AI/agentic-dev#65` line, and it never cites its own synthesized input file. Because this design's *subject matter* is the `_synthesized/` convention itself, the literal string necessarily appears in its prose and quoted Before/After blocks — the meta case. The plain string-absence grep (edit (e)) is the right check for every *normal* future run, whose artifacts have no reason to mention the path at all. | `grep -n "Requirements source" .claude/sdd/features/DESIGN_ISSUE_65_IMPLEMENT_SKILL_CITATION.md` → expect the header line naming `Future-Gadgets-AI/agentic-dev#65`; `grep -c "DEFINE_ISSUE_65[_]IMPLEMENT" .claude/sdd/features/DESIGN_ISSUE_65_IMPLEMENT_SKILL_CITATION.md` → expect `0` (this doc never names its own gitignored input file; the `[_]` keeps the check from matching its own command text). |
| **AT-2** | Next `implement`-produced `BUILD_REPORT_*.md` names the source issue, no `_synthesized/` references. | Edit (c) carries the identical rule into `BUILD_REPORT_<SLUG>.md`. Not this design phase's artifact to produce — the build phase that consumes this DESIGN is the proof point, exactly as edit (c) specifies. | Once build runs: the same two checks against `.claude/sdd/reports/BUILD_REPORT_ISSUE_65_IMPLEMENT_SKILL_CITATION.md` — requirements-source line names the issue; the report never cites its own run's synthesized input file (same meta-case caveat as AT-1). Edit (e) makes the plain string-absence grep a standing check for every future normal run. |
| **AT-3** | Skill's Step 1 template shows the issue reference as a required header field. | Edit (a)'s inserted template block (`# DEFINE — <title>` / `**Source issue:** ...`) plus its "must carry a required `Source issue` field" sentence. | Inspection — once edit (a) is applied to `plugin/skills/implement/SKILL.md`, confirm the template block and the word "required" both appear in Step 1. |

---

## Constraints honored (self-check)

- Exactly three mandatory touch points designed (Step 1, Step 2, Step 3) — nothing added beyond
  them except the two explicitly-optional, explicitly-invited additions (DOs/DON'Ts, Smoke
  procedure), both single-bullet. ✓
- `## Artifact placement` (committed/gitignored split) — not touched, not quoted as an edit target. ✓
- Step 0, Step 4, `## What this skips, and why`, `## Method attribution` — not touched. ✓
- No retrofit of `DESIGN_ISSUE_34_WHATS_NEEDED_ME.md`, `DESIGN_ISSUE_36_REPO_HARDENING.md`, or
  `BUILD_REPORT_ISSUE_34_WHATS_NEEDED_ME.md` — cited only as evidence, not edited, not in the file
  manifest. ✓
- No `agentspec:...` or any other plugin namespace hardcoded anywhere in the new text — the
  citation instruction is surface-agnostic prose, consistent with Step 0's own "never hardcode"
  rule. ✓
- No git commit, no git push, no `gh`/GitHub API call made during this design phase — only this
  file was written. ✓
- File manifest is exactly the one file this task named, no more, no less. ✓
- This document's own header cites `Future-Gadgets-AI/agentic-dev#65` as its requirements source
  and never cites its own synthesized input file (`grep -c` for that file's name → 0). Generic
  `_synthesized/` mentions remain, unavoidably — they are this design's subject matter (prose and
  quoted Before/After blocks), not a citation of an unreachable source. ✓

---

## Next Step

**Ready for:** build phase, applying the six Before/After edits in `plugin/skills/implement/SKILL.md`
exactly as specified in sections (a)–(e) above, then producing
`.claude/sdd/reports/BUILD_REPORT_ISSUE_65_IMPLEMENT_SKILL_CITATION.md` — which, per edit (c), must
itself cite `Future-Gadgets-AI/agentic-dev#65` as its requirements source (AT-2's proof point).
