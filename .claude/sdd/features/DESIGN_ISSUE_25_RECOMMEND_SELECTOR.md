# DESIGN — ISSUE_25_RECOMMEND_SELECTOR

> Phase 2 artifact for issue #25 — read-only board recommender (`/recommend`). Input: synthesized DEFINE (issue #25 refined body, DoR READY). Headless run; refinement-settled constraints honored as fixed.

## Architecture overview

```
user (own gh auth)
   │  /recommend
   ▼
plugin/commands/recommend.md          (model-driven command — the only new file)
   │
   ├─ GATHER  (read-only gh calls)
   │    issues+labels:  gh issue list --json number,title,url,labels,createdAt
   │    WIP count:      filter phase:in-progress
   │    relationships:  gh api graphql subIssues { open dependents } per ready issue
   │
   ├─ PARTITION (eligibility)
   │    ready → candidates · draft/needs-refinement → refine-first ·
   │    blocked/needs-decision → waiting-on-human
   │
   ├─ RANK (tiered, transparent — no numeric score)
   │    T1 priority: high > medium > low > unlabeled
   │    T2 unblocking power: open sub-issues/dependents count (desc)
   │    T3 quick-win tie-break: smaller blast-radius/effort from issue text
   │
   └─ REPORT (markdown digest; top lines actionable as /pickup #N)
```

## Decisions

### Decision: command-only, model-driven (no script, no agent)
**Status:** Accepted (settled at refinement; recorded here) · **Context:** `/needs-me` split mechanical gathering into a script; this feature's core is judgment (rationale per line, effort read from prose). · **Choice:** one command file; the model runs the `gh` reads directly. · **Alternatives rejected:** command+script (adds a moving part before reuse exists); agent (needs a command wrapper anyway; a future board-watcher can spawn this command's logic then). · **Consequence:** ranking runs are model-judged within fixed tiers — deterministic *ordering rules*, non-deterministic only in the T3 prose-reading tie-break, which must always print its reasoning.

### Decision: tier rules are the contract, output format is presentation
**Status:** Accepted · **Context:** anti-theater stance (DoR rubric): rationale, not scores. · **Choice:** the tier order and the "every line names its deciding tier" rule are normative; exact wording/layout may evolve. · **Consequence:** acceptance tests assert ordering + tier-attribution, not exact strings.

### Decision: unblocking power = count of the candidate's OPEN native sub-issues
**Status:** Accepted · **Context:** the board uses native sub-issue relationships (no "blocks" text convention). · **Choice:** one GraphQL read per candidate (`subIssues(first:50){nodes{number,state}}`); count OPEN only. · **Alternative rejected:** parsing "blocked-by" prose — no such convention on this board.

### Decision: identity = invoking user's own gh auth
**Status:** Accepted (mirrors `/needs-me`) · **Context:** read-only command; the bot identity exists for writes. · **Consequence:** no `bot-auth.sh` anywhere in the command; hook unaffected (reads pass ambient).

## File manifest

| # | File | Action | Purpose | Deps |
|---|------|--------|---------|------|
| 1 | `plugin/commands/recommend.md` | Create | the entire feature | none |

(Version bump + SDD artifacts are the outer chain's files, not this design's.)

## Command-body pattern (copy-paste anchor for build)

```markdown
---
description: Recommend which ready issue(s) to pick up next — ranked, with per-line rationale
argument-hint: (no arguments — reads the current repo's board)
---
# /recommend — what to pull next
Read-only. Run as the invoking user's own gh auth — never source bot auth.
1. GATHER: repo = gh repo view; one gh issue list --state open --json number,title,url,labels,createdAt;
   WIP = count(phase:in-progress). For each readiness:ready issue: GraphQL subIssues → open-dependent count.
2. PARTITION: ready → candidates; draft|needs-refinement → "Needs refinement first";
   blocked|needs-decision → "Waiting on a human". Never promote across groups.
3. RANK candidates: priority tier → open-dependent count → quick-win tie-break (blast-radius/effort
   from the issue text; when used, print the reading). Every line: #N · title · URL · deciding tier.
4. REPORT: digest opens with the WIP count (reported, never a gate); top line actionable as /pickup #N;
   empty candidate list is stated plainly (never an error) with the other two groups still printed.
```

## Testing strategy

| AT | How verified |
|----|--------------|
| AT-1 ranked path | fixture label-set (disclosed per A2) if live board lacks ≥2 ready issues; assert tier ordering + attribution |
| AT-2 no cross-group promotion | live board (has drafts + escalation labels available) + fixture |
| AT-3 empty ready queue | LIVE smoke — board's ready queue is empty during this run |
| AT-4 WIP count opens digest | live smoke output |
| AT-5 read-only | before/after byte-compare of issue state (needs-me's proof pattern) |
| AT-6 self-contained | inspect digest top line = `/pickup #N`-actionable |

## Quality gate check
Architecture diagram ✓ · decisions with rationale ✓ · manifest complete (1 file) ✓ · pattern copy-paste ready ✓ · testing covers AT-1..6 ✓ · no circular deps (single file) ✓
