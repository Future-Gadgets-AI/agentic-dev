# DESIGN — ISSUE_58_RECONCILE_LIFECYCLE_REVIEW

**Source issue:** `Future-Gadgets-AI/agentic-dev#58` — [TASK] Reconcile lifecycle.md's Review step: table mandates a human review; prose makes it optional

Surgical docs reconciliation, not a system design: `plugin/contracts/lifecycle.md`'s Review-state
table row and its "Ownership boundary" prose currently state opposite rules about whether a human
review is mandatory. This design brings both into agreement with `CONSTITUTION.md`. The rule itself
was already decided on the issue and is restated below, not re-derived.

## The rule being encoded

Already decided (carried verbatim from the issue, not re-litigated here): **blind review always
precedes the human merge decision; the human merge decision is always required, at Ready-to-merge;
a separate human review pass (`/review-pr`) is optional by explicit choice, never a mandated
lifecycle step.**

`CONSTITUTION.md` is the cited source for that rule, by principle number:

- **Principle IV** (*The Human Boundary: Author, Decide, Approve-and-Merge*) — "A human MUST own
  three — and only these three — points in the lifecycle: authoring/refining an issue, resolving an
  escalated... question, and approving-and-merging the final PR." Review is not one of the three, so
  nothing there requires a human by mandate.
- **Principle V** (*Verify Before Merge: the Smoke Gate and Blind Review*) — "Every PR MUST then
  receive a blind review... before the PR goes to the human for approval. The blind review informs
  the human's required approving review (Principle IV); it never substitutes for it." This is what
  makes blind review the one always-mandated Review-state procedure, and fixes its order (always
  before the merge decision).

Neither principle is edited by this change — both are cited only, per the issue's own non-goal.

## Exact new text — state table Review row

Location: `plugin/contracts/lifecycle.md`, the `## States` table. Only this row's cell contents
change — it keeps its position between **Escalated** and **Ready to merge**.

**Before** (current row, verbatim):
```
| **Review** | 🤖 blind-review, then 🧑 `/review-pr` | the blind reviewer runs the test plan + comments; the other human reviews the PR | Ready-to-merge · or → In Progress (changes requested) |
```

**After** (replace the entire row with):
```
| **Review** | 🤖 blind-review | the blind reviewer runs the test plan + comments — the only mandated Review procedure; a human may optionally run `/review-pr` for a second pass before the merge decision, but it is never required (`CONSTITUTION.md` Principles IV–V) | Ready-to-merge · or → In Progress (changes requested) |
```

Column-by-column rationale:
- **Owner** (`🤖 blind-review, then 🧑 \`/review-pr\`` → `🤖 blind-review`): the file's own opening
  paragraph states "Each column has one owner" — the old cell already broke that rule by naming two
  owners joined by "then." Trimming to the single mandated owner fixes both problems (the table/prose
  split named in the issue, and this internal one-owner-per-column rule) with one edit. `/review-pr`
  is not deleted from the row — it moves into Procedure, explicitly marked optional, so it stays
  "mentioned as an available tool" per the task's instruction.
- **Procedure**: keeps "the blind reviewer runs the test plan + comments" verbatim from the original,
  adds "— the only mandated Review procedure" to state the mandate explicitly, then replaces "the
  other human reviews the PR" (a second mandate) with an optional, cited clause naming `/review-pr`.
- **Exits to**: unchanged, carried over verbatim — the transition targets were never part of the
  contradiction and the task doesn't ask this column to change.

## Exact new text — "Ownership boundary — where humans stay"

Heading is unchanged (`## Ownership boundary — where humans stay`). Only the paragraph body changes.

**Before** (current paragraph, verbatim):
```
Humans own **Refinement**, **Escalated**, and **Ready-to-merge** (and may own Review). Everything between Ready and the PR is autonomous. **The merge is always human.** Escalation is **async**: the card waits in a column behind a label; the human reviews a "brownfield" card when they get to it, then fire-and-forgets again.
```

**After** (replace the entire paragraph with):
```
Humans own exactly three points — **Refinement**, **Escalated**, and **Ready-to-merge** — not Review (`CONSTITUTION.md` Principle IV). Everything between Ready and Ready-to-merge, Review included, is autonomous by default: the blind review is Review's only mandated procedure, and a human may optionally run `/review-pr` for a second pass, but it is never required. **The merge is always human.** The blind review that precedes it only informs that decision — it never substitutes for it (`CONSTITUTION.md` Principle V). Escalation is **async**: the card waits in a column behind a label; the human reviews a "brownfield" card when they get to it, then fire-and-forgets again.
```

Two things worth flagging about this edit, since it touches more than the literal
"(and may own Review)" hedge:

1. **Why "between Ready and the PR" became "between Ready and Ready-to-merge."** The original
   phrase's stated boundary ("...and the PR") ends at PR creation — which is *before* Review even
   starts (a PR already exists once the state machine enters Review). So that sentence never actually
   made a claim about Review's ownership either way; the parenthetical hedge was the *only* place
   addressing it, which is why deleting just the hedge wouldn't have been enough to make the paragraph
   agree with the table. Extending the boundary to Ready-to-merge is the minimal fix that actually
   closes the gap, and it now matches the table's reconciled scope exactly (autonomous through Review,
   human again only at Ready-to-merge).
2. **The escalation-is-async sentence is carried over character-for-character**, as instructed — not
   touched, not reworded.

Checked, left unchanged: the file's top enforcement blockquote, every other table row, "The two gates
on the happy path," and "Minimalism" — none of them assert a mandate that conflicts with the
reconciled rule above.

## File manifest

| File | Action | Agent |
|---|---|---|
| `plugin/contracts/lifecycle.md` | Edit — the two blocks above (Review row; Ownership-boundary paragraph). No other line in the file changes. | general — direct text edit, exact before/after blocks given above, no specialist judgment needed |

No other file in `plugin/contracts/` requires an edit — see the cross-check below.

## Contracts cross-check (all 5 files)

| File | Verdict | Why |
|---|---|---|
| `lifecycle.md` | **Contradictory (fixed above)** | Review row's Owner/Procedure columns mandated a human step ("then 🧑 `/review-pr`", "the other human reviews the PR"); the Ownership-boundary prose hedged the same step as optional ("and may own Review"). Same rule, two different answers — the defect this design closes. |
| `README.md` (contracts index) | **Not contradictory** | No mention of review, merge, or human ownership anywhere in the file — it's a file index plus the enforcement-honesty note. Nothing to reconcile. |
| `dor-rubric.md` | **Not contradictory** | Scoped entirely to the pre-pickup DoR gate. Its one relevant phrase — "the shadow-trick + human merge cap the ceiling" — reinforces "merge is always human"; it says nothing about whether a Review-state human pass is mandatory. |
| `labels.md` | **Not contradictory — descriptive, not a mandate** | `phase:review`: "PR open; awaiting blind / human review." This is a one-line label gloss, not a procedure statement — `contracts/README.md`'s own file table assigns *procedure* to `lifecycle.md` and *the label scheme* to `labels.md`; a mandate wouldn't be stated in a label description in this repo's own document taxonomy. The "/" reads naturally as "and/or" (either kind of review may happen while this label is set), not "both are required." No MUST/required language appears. Verdict: ambiguous-but-descriptive, not a contradiction — left unedited, out of scope for this issue (the issue itself is silent on this exact phrase, not an explicit non-goal — worth stating precisely). |
| `repo-standard.md` | **Not contradictory** | Same `phase:review` phrase reappears in the label-rollout manifest, suffixed "(P6-P7)." `a2a-workflow/SKILL.md`'s canonical P0–P8 phase list maps P6 to PR and P7 specifically to BLIND REVIEW (P7's own asset file states blind-review "is *not*... the other agent's `review-pr`") — there is no numbered phase for a human review pass at all, so "(P6-P7)" actually scopes *away* from a human-review mandate rather than asserting one. Separately, `required_approving_review_count: 1` in the branch-protection JSON operationalizes the Ready-to-merge/Principle-IV mandate (branch protection blocks the merge button without one code-owner approval) — that's the platform enforcement of the *merge* gate, not a claim that the Review-state `/review-pr` skill must run; a code owner's native GitHub "Approve" click satisfies it without ever invoking `/review-pr`. Same phrase, same verdict and reasoning as `labels.md` — left unedited. |

## Out of scope — found but not fixed

None. All five contracts files were read in full for this cross-check; no inconsistency unrelated to
the Review-step rule was found.

One minor observation, noted for completeness only — explicitly **not** a finding, not actionable,
not in the file manifest: `labels.md`'s `phase:` namespace has four values (`triage`, `in-progress`,
`review`, `done`) against `lifecycle.md`'s seven states, so "Ready" and "Ready to merge" have no
listed 1:1 `phase:` label of their own (`labels.md`'s composition section frames its mappings as
illustrative examples, not an exhaustive table). This isn't a rule contradiction, and it's already
self-disclosed elsewhere in the repo as pending work — both `lifecycle.md` and `labels.md` point at
the still-open GitHub Projects board-mapping issue (#19) for exactly this kind of label-to-column
gap. Raised here only so the composer isn't caught off guard if a reviewer asks about it.
