# DESIGN — ISSUE_69_DRAFT_PR_CONVENTION

**Source issue:** `Future-Gadgets-AI/agentic-dev#69` — [TASK] Document the draft-PR + ready-flip convention for reviewers

Docs-only reconciliation, not a system design: the draft-PR + ready-flip convention already governs
the codebase's behavior (`/pickup`, `a2a-workflow`, `create-pr`'s `--draft` flag) but is stated nowhere
a reviewer would read it before hitting a draft PR. This design adds one canonical statement to
`plugin/contracts/lifecycle.md` and two short references to it, in `plugin/skills/review-pr/SKILL.md`
and `ARCHITECTURE.md` — exactly the three files and the "one statement, two references" shape the
issue asks for. No behavior changes; only additive text in three files.

## The convention being encoded

Already decided on the issue, restated here, not re-derived: **the autonomous engine opens its PR as
a draft → the blind review runs on the draft (not a ready-for-merge PR) → the human flips it ready and
merges at the Ready-to-merge step. The flip and the merge are the same human action, not two separate
steps.**

This is not a new rule — it already governs the codebase, confirmed by direct reads (not assumed):

- `plugin/commands/pickup.md` step 7: *"Draft is the headless default — the human flips it ready."*
- `plugin/commands/pickup.md`'s Exit section: *"never merge, and never mark the draft ready yourself."*
- `plugin/skills/a2a-workflow/SKILL.md`: *"Default for headless until trust is earned: **draft PR
  always**."*
- `CONSTITUTION.md` Principle VI's rationale presupposes it as an existing norm: *"...the shadow-trick,
  draft-PR defaults, and the human merge correctly carry the weight..."* (cited only here — not edited;
  `CONSTITUTION.md` is out of scope per the issue).

The gap this issue closes: `pickup.md` states the convention for the engine's own operator, but neither
`review-pr` (the reviewer's own protocol) nor the two files a reviewer meeting the flow for the first
time would read (`lifecycle.md`, `ARCHITECTURE.md`) say it.

## Constraint check — the two protected spots in `lifecycle.md`

`plugin/contracts/lifecycle.md` was reconciled immediately before this run by PR #82 (issue #58, merged
as commit `eb32ab6` — confirmed via `git log -- plugin/contracts/lifecycle.md` and `git show eb32ab6`,
not just asserted). Two spots now carry deliberate wording citing `CONSTITUTION.md` Principles IV–V and
must not be touched: the **Review** table row, and the **"Ownership boundary — where humans stay"**
paragraph.

**Conclusion: not blocked.** AT-1 is fully satisfiable by adding a new `##` section to `lifecycle.md` —
the file already grows by whole sections (States → gates → Ownership boundary → Minimalism), so one
more is a natural, zero-risk extension. Neither protected spot needs to change: the Review row already
names the blind review as the mandated procedure (silent on draft status, which is fine — draft-vs-ready
is a PR-level flag, not a lifecycle-column-owner fact); the Ownership-boundary paragraph already
establishes "the merge is always human," which the new section operationalizes without restating or
contradicting it. **No `CONSTITUTION.md` edit, no edit to either protected spot.**

*Alternative considered and rejected:* extending the **Ready to merge** row's Procedure cell
(`merge the PR` → e.g. `flip it ready and merge`) — explicitly allowed by the issue (that row was
untouched by PR #82). Rejected because a three-word table cell can't carry "who + when + what draft
implies for Review" without compressing awkwardly, and a dedicated section is strictly lower-risk
against the table PR #82 just reconciled. The new section references the table by name instead of
editing it.

## Exact new text, per file

Convention used below: **Anchor (before)** and **Anchor (after)** are existing, unmodified lines that
bound the insertion point; **Insert** is the complete new text placed between them, with the file's
normal blank-line spacing on both sides. Anchors are quoted verbatim and must not change.

### File 1 — `plugin/contracts/lifecycle.md`

**Anchor (before)** — existing, unmodified (tail of the Ownership-boundary paragraph):
```
Humans own exactly three points — **Refinement**, **Escalated**, and **Ready-to-merge** — not Review (`CONSTITUTION.md` Principle IV). Everything between Ready and Ready-to-merge, Review included, is autonomous by default: the blind review is Review's only mandated procedure, and a human may optionally run `/review-pr` for a second pass, but it is never required. **The merge is always human.** The blind review that precedes it only informs that decision — it never substitutes for it (`CONSTITUTION.md` Principle V). Escalation is **async**: the card waits in a column behind a label; the human reviews a "brownfield" card when they get to it, then fire-and-forgets again.
```

**Anchor (after)** — existing, unmodified:
```
## Minimalism
```

**Insert** (new section, complete text):
```markdown
## The draft-PR + ready-flip convention
The autonomous engine opens every PR as a **draft** — the headless default (`/pickup`, `a2a-workflow`). The blind review in the **Review** row above runs against that draft, not a ready-for-merge PR: draft status there is expected, never itself a review finding. The human flips the PR ready and merges it — the same action, not two separate steps — at **Ready-to-merge**.
```

**Rationale → AT-1:** names the convention, the human, and the Ready-to-merge step in one new section,
without touching either protected spot in the same file.

### File 2 — `plugin/skills/review-pr/SKILL.md`

**Anchor (before)** — existing, unmodified (the `Identity` blockquote):
```
> **Identity.** `review-pr` posts as **your own** GitHub account (the reviewer) — it does *not* assume the bot and has no `bot-auth` step, because a review is the counterparty's act, not the author's. (The bot's *automated* first-pass — P7 blind-review — does post as the bot; see `a2a-workflow` → `assets/blind-review.md`.)
```

**Anchor (after)** — existing, unmodified:
```
## Detect the repo first (never hardcode)
```

**Insert** (new blockquote, complete text):
```markdown
> **Draft status is expected — not a finding.** The autonomous engine opens every headless PR as a **draft** — you're typically reviewing a draft, not a ready-for-merge PR, and that alone is never a reason to request changes or hold off. The human flips it ready and merges at the Ready-to-merge step, informed by your review, never blocked on it (`plugin/contracts/lifecycle.md`).
```

**Rationale → AT-2:** states plainly, before Step 1, that draft status is expected and never a
request-changes reason — read before the reviewer ever looks at the PR, alongside the file's two other
pre-Step-1 framing blockquotes (skepticism, identity).

### File 3 — `ARCHITECTURE.md`

**Anchor (before)** — existing, unmodified (tail of `## The issue lifecycle`):
```
**Readiness** (`readiness:draft | needs-refinement | ready`) is an orthogonal dimension that gates Draft→Ready; scheduling (backlog vs active) is orthogonal again. An issue's state is encoded in its `phase:` × `readiness:` × `status:` labels. (A GitHub Projects board *can't* make columns from labels — it surfaces these as columns via a single-select **Status** field that mirrors them; that mapping is designed in #19.)
```

**Anchor (after)** — existing, unmodified:
```
## The gates
```

**Insert** (new paragraph, complete text):
```markdown
**PR status.** Every PR the engine opens is a **draft** by default; the Review row's blind-review runs against that draft, and draft status there is expected, not a finding. The human flips it ready and merges — one action, not two — at Ready-to-merge (`plugin/contracts/lifecycle.md`).
```

The ASCII diagram itself is **not** touched — it states columns and owners, not PR-level flags, and
editing fixed-width ASCII art precisely is exactly the kind of thing Build shouldn't have to re-decide;
AT-3 requires only the section's *description* to match.

**Rationale → AT-3:** restates the same convention in `lifecycle.md`'s own words, scaled to this file's
terser register (matching its existing "**Two kinds of entrypoint.**" lead-in pattern), inside the
lifecycle section AT-3 names, citing `lifecycle.md` as the source of record.

## File manifest

| File | Action | Note |
|---|---|---|
| `plugin/contracts/lifecycle.md` | Edit — insert one new `##` section | Canonical statement |
| `plugin/skills/review-pr/SKILL.md` | Edit — insert one new blockquote | Reference #1 |
| `ARCHITECTURE.md` | Edit — insert one new paragraph | Reference #2 |
| `CONSTITUTION.md` | **Not touched** | Cited only, in this design doc's own prose — never in a committed file; out of scope per the issue |

Total: 3 files, 3 insertions, 0 deletions, 0 edits to any existing line.

## Verification (for Build / blind review)

| AT | Check |
|---|---|
| AT-1 | `grep -A2 "draft-PR + ready-flip convention" plugin/contracts/lifecycle.md` finds the new section. `git diff HEAD -- plugin/contracts/lifecycle.md` shows only added (`+`) lines — the Review row and the Ownership-boundary paragraph are byte-identical to `HEAD`. |
| AT-2 | `grep -B1 -A2 "Draft status is expected" plugin/skills/review-pr/SKILL.md` finds the new blockquote positioned between `Identity` and `## Detect the repo first`. |
| AT-3 | `grep -A2 "PR status\." ARCHITECTURE.md` finds the new paragraph inside `## The issue lifecycle`. Manually confirm its key phrases — draft / expected, not a finding / flips ready and merges, one action — line up with `lifecycle.md`'s new section. |

## Out of scope — found but not fixed

`ARCHITECTURE.md`'s lifecycle ASCII diagram marks the **Review** column's owner as `(🤖+🧑)` — a joint
bot+human owner. This is stale against the post-PR-#82 `lifecycle.md`, whose Review row owner is now
`🤖 blind-review` alone (`/review-pr` is optional, not a co-owner). It predates issue #69 — a side
effect of #58's reconciliation never propagating to `ARCHITECTURE.md`'s diagram — and it's not what
AT-3 tests (AT-3 is about the draft-PR/ready-flip convention, not the Review-owner icon). Not fixed
here; flagged so the composer or a reviewer isn't caught off guard. Candidate for a small follow-up
issue if it's worth a dedicated fix.

---

**Status: ready for Build.** Three additive-only edits, zero touches to the two protected spots in
`lifecycle.md`, zero touches to `CONSTITUTION.md`. No blocking finding.
