# DESIGN — ISSUE_72_HARDEN_REPO_PLAN_LIMITATION_PHASE_C

**Requirements source:** Future-Gadgets-AI/agentic-dev#72 — "[TASK] harden-repo apply mode: special-case na_plan_limitation in Phase C"

> Phase 2 (DESIGN) artifact for issue #72 — apply mode's Phase C ("## C — Branch protection +
> ruleset" in `plugin/commands/harden-repo.md`) does not yet special-case the `na_plan_limitation`
> status Phase A (`repo-standard-diff.sh`) already writes to `plan.json` for a private repo on
> GitHub's free plan. Headless run. This is a documentation/procedure-text change to a Claude Code
> slash-command markdown file — the "implementation" is the exact prose an executing agent reads
> and follows literally; there is no application code and no test suite, only a simulated
> walkthrough against constructed `plan.json` fixtures (never a live `--apply` run — carried DoR
> assumption, honored below). No file was edited by this design phase; `plugin/commands/harden-repo.md`
> stays untouched until the build phase applies (b)/(d) below.

## Scope

**In (per the DEFINE, verbatim):** `plugin/commands/harden-repo.md`, Phase C only. Read `protection.status`
/ `ruleset.status` from `plan.json`, independently; when either is `na_plan_limitation`, skip that
field's confirmation gate entirely (no PUT/POST body presented, no write attempted); emit in the
Final report the `N/A (plan limitation)` status line plus the README-note/process-enforcement
fallback reminder from `repo-standard.md`'s "Free-plan carve-out" section.

**Out (per the DEFINE):** `plugin/scripts/repo-standard-diff.sh`'s classification logic (already
merged, #67/PR #71 — untouched, not re-opened). Paying for a GitHub plan, or making a repo public
(contract non-goals). Any live `--apply` run against a real repo (verification is a simulated
walkthrough only, per the carried DoR assumption). Any edit to a sentence describing non-limited-path
behavior (AT-3, non-negotiable).

## Prior art (grounds this design, re-verified against the live file/history, not taken on faith)

- Verify mode's two `Status` enum lines (`harden-repo.md` lines 31, 187) already carry
  `` `N/A (plan limitation)` `` — added by commit `cfb3b45` ("fix(repo-standard): free-plan carve-out
  — classify plan-limited 403s", PR merging issue #67), confirmed via `git show cfb3b45 -- plugin/commands/harden-repo.md`:
  a pure one-value append to an existing pipe-delimited list, nothing else on either line touched.
  This is the literal append-only pattern this design reuses for apply mode's own enum (line 164).
- `DESIGN_ISSUE_67_REPO_STANDARD_FREE_PLAN_CARVEOUT.md`'s own inline design decision, "Apply-mode
  Phase C gap — flagged, not fixed," named this exact gap and consciously deferred it — this design
  is that deferred follow-up, not a re-litigation of #67's scope.
- `plugin/contracts/repo-standard.md`'s "Free-plan carve-out" section — source of the mandated
  fallback text this design echoes (quoted verbatim where used below).

---

## Architecture — where the new handling sits in Phase C's decision flow

```text
Phase C — Branch protection + ruleset
│
├─ Pre-flight identity assertion (bash)              — unconditional, UNCHANGED
│     exits non-zero → BLOCKED (ambient identity check failed); stop sub-step
│
├─ Re-probe `main` exists (live gh api call)          — unconditional, UNCHANGED
│     missing (A2 didn't just create it) → BLOCKED (main branch does not exist) for
│       PROTECTION only; RULESET has no such dependency — proceeds independently (existing
│       bullet, untouched)
│     exists → continue
│
├─ [NEW — this issue, (a)/(b) below] Resolve na_plan_limitation, per half, independently
│     protection status == "na_plan_limitation" → resolved now: body never read/shown, write
│       never attempted; report N/A (plan limitation) + carve-out fallback; out of
│       consideration for the rest of this sub-step
│     ruleset status == "na_plan_limitation"    → same, independently (never assumes the other
│       half's outcome)
│     if nothing is left needing a write (every half now "match" or already resolved this way)
│       → skip straight to Final report, exactly like the existing both-"match" case does
│
├─ [EXISTING, byte-unedited] both remaining halves already "match"?
│     → NO-OP (already matches) for both; skip straight to Final report
│
└─ [EXISTING, byte-unedited] Otherwise: read the remaining half(s)' put/post bodies — a
      na_plan_limited half is already excluded by the step above, never reached here — pretty-
      print, confirm (AskUserQuestion) → Yes: run only the remaining write line(s) (a
      na_plan_limited half's write line is never among them) → No: DECLINED
```

---

## (a) Insertion point — exact anchor, copied verbatim from the file as it exists right now

**Goes immediately after** this line (the last bullet of the `main`-re-probe list) and the blank
line following it:

```markdown
- `main` exists → continue below.
```

**Goes immediately before** this paragraph (the existing combined match-skip check):

```markdown
If protection status is already `"match"` **and** ruleset status is already `"match"` — nothing to confirm; report `NO-OP (already matches)` for both and skip straight to the Final report without asking.
```

Nothing between these two lines today except a single blank line — the insertion adds two new
paragraphs (each followed by a blank line) into that gap; the blank line immediately before "If
protection status..." is preserved as-is (it becomes the blank line after the second new
paragraph).

---

## (b) The new paragraph text — verbatim, ready to paste as-is

Two paragraphs, inserted at (a)'s anchor, in this order:

```markdown
Before the combined match check below, handle `na_plan_limitation` the same way the check above handles a missing `main`: read protection status and ruleset status independently — one half's status never implies the other's. Whichever half's status is `"na_plan_limitation"` (the **protection** half, the **ruleset** half, or both) is fully resolved right here, for the rest of this sub-step: its put/post body is never read or shown, its write is never attempted, and it is reported as `N/A (plan limitation)` — never `NO-OP (already matches)`, which stays reserved for a genuine `"match"` — together with the Free-plan carve-out's mandated fallback (`plugin/contracts/repo-standard.md`, "Free-plan carve-out"): process enforcement (bot-authored PRs plus human merges) stands in for the missing technical guardrail, plus a note on the *target* repo's own README documenting the residual risk (no branch protection/ruleset on this repo; merges are enforced by process, not by GitHub).

A half resolved this way counts, everywhere below in this sub-step, exactly like a half already at `"match"`, even though the wording ahead never names this exception inline: the confirmation prompt's per-half blocks below omit it on the same terms as an already-`"match"` half, and it never runs its write line on **Yes** below either. If resolving `na_plan_limitation` this way leaves no half whose status still needs a write — both halves accounted for, or the one half left over is genuinely `"match"` — there is nothing to confirm at all: skip the confirmation prompt entirely and go straight to the Final report, exactly as the already-both-`"match"` case immediately below does.
```

### Clause-by-clause rationale (maps each sentence back to the DEFINE's point 2/3 asks)

| Clause | Satisfies |
|---|---|
| "read protection status and ruleset status independently — one half's status never implies the other's" | Point 2's "never assume one implies the other"; explicitly ties to the `main`-missing precedent's own established voice (point 2's instruction to match it). |
| "its put/post body is never read or shown, its write is never attempted" | Point 2's "never reads or presents that field's put/post body ... never attempts its write" — stated **before** the existing "Otherwise, read the put/post bodies..." paragraph, i.e. forward-declared. |
| "reported as `N/A (plan limitation)` — never `NO-OP (already matches)`" | Point 2's exact requirement, verbatim status string, explicit negative case. |
| "process enforcement (bot-authored PRs plus human merges) stands in ... note on the *target* repo's own README ... (no branch protection/ruleset on this repo; merges are enforced by process, not by GitHub)" | Point 2's fallback mention — echoes `repo-standard.md`'s "Free-plan carve-out" wording closely enough to be traceable to it (see Constraints self-check). |
| "counts ... exactly like a half already at `"match"`, even though the wording ahead never names this exception inline" | Point 3's explicit instruction: "forward-declare the exception earlier, don't retrofit it into the existing sentence" — states outright that the unedited lines below apply to this case without being edited. |
| "the confirmation prompt's per-half blocks below omit it on the same terms as an already-`"match"` half" | Governs the existing `(omit this block if protection status is already "match")` / same-for-ruleset convention (129–137) without editing either line — see (c). |
| "it never runs its write line on **Yes** below either" | Governs the existing "Run only the write line(s) whose status isn't already `"match"`" sentence (143) and the bash block's `# only if ... != "match"` comments (149, 153) without editing them — see (c)'s named risk. |
| "If resolving `na_plan_limitation` this way leaves no half whose status still needs a write ... skip the confirmation prompt entirely" | Covers the **all-limited** case (DEFINE's Fixture A) explicitly — the existing both-`"match"` check's literal wording would never fire for this case (neither status string is literally `"match"`), so this sentence supplies the missing skip **before** reaching it. |

---

## (c) Why the two existing anchor paragraphs stay reachable, correct, and byte-unedited

Quoted again for this proof (identical bytes to (a)'s quotes):

```markdown
If protection status is already `"match"` **and** ruleset status is already `"match"` — nothing to confirm; report `NO-OP (already matches)` for both and skip straight to the Final report without asking.
```

```markdown
Otherwise, read `$PLAN_DIR/protection-put-body.json` and (if present) `$PLAN_DIR/ruleset-post-body.json`, pretty-print them, and **end your turn and wait for the human's next message**:
```

**(a) Neither half is `na_plan_limitation`** — (b)'s two paragraphs' own trigger condition ("Whichever half's status is `na_plan_limitation`" / "resolving `na_plan_limitation`") never fires for either half; they contribute zero action. Execution reaches the both-`"match"` check exactly as today: if both are literally `"match"` → `NO-OP`; otherwise → falls to "Otherwise, read the bodies..." — reached, evaluated, and rendered with **no** field omitted beyond what the pre-existing `"match"`-omission convention already omits. Fully unchanged behavior.

**(b) Mixed — one half `na_plan_limitation`, the other still needs a write** (e.g. protection `na_plan_limitation`, ruleset `absent`): (b)'s paragraph 1 resolves protection now (reported, excluded). Paragraph 2's skip condition is false (ruleset still needs a write) → falls through. The both-`"match"` check is **reached**: its condition reads protection status literally — `"na_plan_limitation"` is not `"match"` — so the check correctly evaluates false (exactly the outcome required; a NO-OP here would be wrong), and falls to "Otherwise, read the bodies...". That paragraph is **reached** too, and its instruction to read/pretty-print/present is followed for **ruleset only** — protection's block is governed by (b) paragraph 2's earlier "omit it on the same terms as an already-`"match"` half" declaration, so the reader omits it there without that later paragraph's own wording needing to say so. Both existing paragraphs: reached, correct, byte-unedited.

**All-limited (both halves `na_plan_limitation`, DEFINE's Fixture A)**: (b) resolves both halves; paragraph 2's skip condition is now true (nothing left needing a write) → execution goes straight to the Final report. The both-`"match"` check and the "Otherwise, read the bodies..." paragraph are **not evaluated** for this run at all — same outcome DEFINE's own verification approach names explicitly ("Fixture A → no confirmation prompt"). This does not violate reachability: DEFINE's point 3 only requires reachability for cases (a) and (b) above; both hold. Neither existing paragraph's bytes are touched regardless of which case a given run hits.

**Named risk, addressed directly**: the sentence "Run only the write line(s) whose status isn't already `"match"`" (143) and its bash block's `# only if protection status != "match"` / `# only if ruleset status != "match"` comments (149, 153) are, read in isolation, ambiguous for a `na_plan_limitation` half — literally, `na_plan_limitation` "isn't already match" too. This sentence is intentionally **not** edited (it describes non-limited-path wording word-for-word, and mixing a third status into a binary-sounding phrase would risk exactly the kind of edit AT-3 forbids). (b) paragraph 2's "it never runs its write line on **Yes** below either" is the forward declaration that resolves this ambiguity **before** the reader gets there — consistent with DEFINE's own instruction that "those lines' own wording won't mention the exception inline." A field resolved as `na_plan_limitation` is never a candidate for that later sentence's selection in the first place, by the earlier paragraph's own terms.

**Asymmetry worth flagging** (why this is real, necessary work, not defensive redundancy): `protection-put-body.json` is written to the plan dir **unconditionally** by Phase A regardless of status (confirmed in `repo-standard-diff.sh` and the DEFINE's grounding facts) — so for a `na_plan_limitation` protection half, the file exists on disk with inert content, and the existing "read `$PLAN_DIR/protection-put-body.json`" clause carries **no** `(if present)` qualifier the way the ruleset clause does. Without (b)'s omission rule, that inert body **would** be read and shown. `ruleset-post-body.json`, by contrast, is written only when a POST is actually needed — for `na_plan_limitation` it is **not** written at all — so the existing "(if present)" qualifier already, incidentally, keeps a plan-limited ruleset half from being read even without this design's rule. This design applies the omission symmetrically to both halves anyway, rather than relying on that incidental file-absence as the actual safety mechanism for ruleset.

**Ordering with the pre-existing `main`-missing/BLOCKED path**: untouched. If `main` is missing, protection is already resolved as `BLOCKED (main branch does not exist)` by the existing bullet **before** (b)'s insertion point is even reached — (b) then has nothing left to do for protection in that run (purely a consequence of textual position, not new logic); ruleset proceeds to (b) as usual, independently, exactly as the existing bullet already says it should.

---

## (d) Report block extension — `Status:` enum append + `Changed:` additive lines

Both are pure additions to `harden-repo.md`'s existing "### Branch protection + ruleset" Report
block (lines 160–170); no existing line is reworded.

**`Status:` line — before:**
```
Status:    APPLIED (confirmed) | NO-OP (already matches) | AWAITING CONFIRMATION | DECLINED | BLOCKED (main branch does not exist) | BLOCKED (ambient identity check failed)
```

**`Status:` line — after** (append-only, mirrors the verify-mode precedent's mechanism — one new
value appended to an existing pipe-delimited list; no inline parenthetical added, matching this
specific line's own established convention of zero per-value scope annotations, e.g.
`BLOCKED (main branch does not exist)` already carries no inline "(protection-only)" note either —
that nuance lives in prose above, not in this line):
```
Status:    APPLIED (confirmed) | NO-OP (already matches) | AWAITING CONFIRMATION | DECLINED | BLOCKED (main branch does not exist) | BLOCKED (ambient identity check failed) | N/A (plan limitation)
```

**`Changed:` block — before:**
```
Changed:
  protection.required_status_checks.contexts: <before> -> <after>
  (all other observed protection fields — restrictions, required_conversation_resolution,
   required_linear_history, block_creations, lock_branch, allow_fork_syncing — preserved verbatim)
  ruleset: created "branch-naming-convention" (new id <n>) | already present, no-op | DRIFT (not modified — see plan.json ruleset.diff_fields)
```

**`Changed:` block — after** (two wholly new lines appended below the existing three; nothing
above them edited):
```
Changed:
  protection.required_status_checks.contexts: <before> -> <after>
  (all other observed protection fields — restrictions, required_conversation_resolution,
   required_linear_history, block_creations, lock_branch, allow_fork_syncing — preserved verbatim)
  ruleset: created "branch-naming-convention" (new id <n>) | already present, no-op | DRIFT (not modified — see plan.json ruleset.diff_fields)
  protection: N/A (plan limitation) — not written; see plan.json protection.reason for the 403 body; fallback: process enforcement (bot-authored PRs + human merges) plus a README note on <owner/repo> documenting the residual risk (no branch protection — merges enforced by process, not by GitHub)   (only if protection status is "na_plan_limitation")
  ruleset: N/A (plan limitation) — not written; see plan.json ruleset.reason for the 403 body; fallback: process enforcement (bot-authored PRs + human merges) plus a README note on <owner/repo> documenting the residual risk (no branch-naming ruleset — merges enforced by process, not by GitHub)   (only if ruleset status is "na_plan_limitation")
```

**Why two new lines, not an inline extension of the existing `ruleset:` pipe list**: the `ruleset:`
line's three alternatives are pipe-delimited and *could* structurally accept a fourth, but AT-3's
sanctioned append-only carve-out is scoped to "existing pipe-delimited **enum lists** ... exactly
the pattern already used for verify mode's two `Status` enum lines" — true status enums, not an
outcome-description template with embedded parameters (`<n>`). Symmetry also matters: `protection:`
has no equivalent pipe list to extend (its line is a single `<before> -> <after>` template), so it
necessarily gets a new line regardless — giving `ruleset:` a matching new line, rather than an
inline addition, keeps both halves' plan-limited case rendered identically instead of two different
shapes for the same underlying case. Both new lines carry a plan.json `reason`-pointer, mirroring
the existing `ruleset:` line's own "(not modified — see plan.json ruleset.diff_fields)" pointer
convention, and their own trailing `(only if ... status is "na_plan_limitation")` conditional,
mirroring the confirmation prompt's existing `(omit this block if ...)` convention.

---

## Composite view (informational — the exact same edits as (a)/(b)/(d), assembled in context, for the build phase to diff against)

```markdown
Re-probe that `main` exists before rendering the confirmation (Decision D7 — Phase A's snapshot can be stale either direction: CODEOWNERS may just have created `main`, or A2 may have been skipped/blocked): `gh api "repos/<owner/repo>/branches/main" >/dev/null 2>&1`.
- `main` missing and A2 didn't just create it (declined, blocked, or a non-empty repo with no `main`) → skip the **protection** half only, report `BLOCKED (main branch does not exist)`. The **ruleset** half has no such dependency (its `ref_name` conditions are pattern-based, not tied to an existing branch) — proceed with it independently.
- `main` exists → continue below.

Before the combined match check below, handle `na_plan_limitation` the same way the check above handles a missing `main`: read protection status and ruleset status independently — one half's status never implies the other's. Whichever half's status is `"na_plan_limitation"` (the **protection** half, the **ruleset** half, or both) is fully resolved right here, for the rest of this sub-step: its put/post body is never read or shown, its write is never attempted, and it is reported as `N/A (plan limitation)` — never `NO-OP (already matches)`, which stays reserved for a genuine `"match"` — together with the Free-plan carve-out's mandated fallback (`plugin/contracts/repo-standard.md`, "Free-plan carve-out"): process enforcement (bot-authored PRs plus human merges) stands in for the missing technical guardrail, plus a note on the *target* repo's own README documenting the residual risk (no branch protection/ruleset on this repo; merges are enforced by process, not by GitHub).

A half resolved this way counts, everywhere below in this sub-step, exactly like a half already at `"match"`, even though the wording ahead never names this exception inline: the confirmation prompt's per-half blocks below omit it on the same terms as an already-`"match"` half, and it never runs its write line on **Yes** below either. If resolving `na_plan_limitation` this way leaves no half whose status still needs a write — both halves accounted for, or the one half left over is genuinely `"match"` — there is nothing to confirm at all: skip the confirmation prompt entirely and go straight to the Final report, exactly as the already-both-`"match"` case immediately below does.

If protection status is already `"match"` **and** ruleset status is already `"match"` — nothing to confirm; report `NO-OP (already matches)` for both and skip straight to the Final report without asking.

Otherwise, read `$PLAN_DIR/protection-put-body.json` and (if present) `$PLAN_DIR/ruleset-post-body.json`, pretty-print them, and **end your turn and wait for the human's next message**:

[... unchanged confirmation-prompt fenced block, "On **Yes**" paragraph + bash block, "On **No**" line — all byte-identical to today, omitted here for brevity; see (a)/(c) above, nothing there is touched ...]

**Report block:**
```
### Branch protection + ruleset
Identity:  ambient human (<CURRENT_LOGIN>) — asserted != configured bot (asserted <timestamp>)
Status:    APPLIED (confirmed) | NO-OP (already matches) | AWAITING CONFIRMATION | DECLINED | BLOCKED (main branch does not exist) | BLOCKED (ambient identity check failed) | N/A (plan limitation)
Changed:
  protection.required_status_checks.contexts: <before> -> <after>
  (all other observed protection fields — restrictions, required_conversation_resolution,
   required_linear_history, block_creations, lock_branch, allow_fork_syncing — preserved verbatim)
  ruleset: created "branch-naming-convention" (new id <n>) | already present, no-op | DRIFT (not modified — see plan.json ruleset.diff_fields)
  protection: N/A (plan limitation) — not written; see plan.json protection.reason for the 403 body; fallback: process enforcement (bot-authored PRs + human merges) plus a README note on <owner/repo> documenting the residual risk (no branch protection — merges enforced by process, not by GitHub)   (only if protection status is "na_plan_limitation")
  ruleset: N/A (plan limitation) — not written; see plan.json ruleset.reason for the 403 body; fallback: process enforcement (bot-authored PRs + human merges) plus a README note on <owner/repo> documenting the residual risk (no branch-naming ruleset — merges enforced by process, not by GitHub)   (only if ruleset status is "na_plan_limitation")
```
```

---

## (e) File manifest

| File | Action | Reason |
|------|--------|--------|
| `plugin/commands/harden-repo.md` | Modify | Insert (b)'s two new paragraphs at (a)'s anchor (between "`main` exists → continue below." and the both-`"match"` check); append `N/A (plan limitation)` to the apply-mode Report block's `Status:` enum line (164); append two new `Changed:` lines (d). |

**Explicitly not touched**: `plugin/scripts/repo-standard-diff.sh`, `plugin/contracts/repo-standard.md`, `plugin/scripts/repo-standard-apply-codeowners.sh`, `plugin/scripts/repo-standard-apply-labels.sh`, `plugin/.claude-plugin/plugin.json` (no version bump — composer's job, after build). Nothing in Phase A, A2, B, or Bot-wiring — none of those sub-steps' own status enums or report templates carry `na_plan_limitation` at all (confirmed by grepping the file for every `MATCH|DRIFT|ABSENT|BLOCKED|NO-OP` occurrence — only line 164, already covered, and lines 31/187, already handled by PR #71, are protection/ruleset-scoped).

---

## (f) Acceptance-criteria mapping, with simulated fixture walkthroughs

Per the carried DoR assumption, verification is a **simulated walkthrough** against constructed
`plan.json` fixtures — never a live `--apply` run. Three fixtures (A and B are the DEFINE's own
named pair; C is this design's addition, proving the mixed case DEFINE's point 3(b) requires):

**Fixture A** (`protection.status` = `ruleset.status` = `"na_plan_limitation"`, both):
```json
{"protection": {"status": "na_plan_limitation", "reason": "HTTP 403: Upgrade to GitHub Pro or make this repository public to enable this feature.", "main_branch_exists": true, "blocked_on": null, "diff_fields": []},
 "ruleset":    {"status": "na_plan_limitation", "reason": "HTTP 403: Upgrade to GitHub Pro or make this repository public to enable this feature.", "diff_fields": []}}
```
Walkthrough: identity assertion passes; `main` exists → continue. (b) paragraph 1 resolves **both**
halves now — no body read, no write, both reported `N/A (plan limitation)` + the carve-out fallback.
(b) paragraph 2: nothing left needing a write → skip the confirmation entirely, go straight to the
Final report. **No** `AskUserQuestion` is ever presented; **no** `gh api --method PUT/POST` line
ever runs. Matches AT-1 and DEFINE's own "Fixture A → no confirmation prompt, no write" exactly.

**Fixture B** (healthy — both `"match"`):
```json
{"protection": {"status": "match", "reason": null, "main_branch_exists": true, "blocked_on": null, "diff_fields": []},
 "ruleset":    {"status": "match", "reason": null, "diff_fields": []}}
```
Walkthrough (this is the AT-3 regression proof — see below for the line-by-line trace).

**Fixture C** (mixed — protection plan-limited, ruleset genuinely absent):
```json
{"protection": {"status": "na_plan_limitation", "reason": "HTTP 403: Upgrade to GitHub Pro or make this repository public to enable this feature.", "main_branch_exists": true, "blocked_on": null, "diff_fields": []},
 "ruleset":    {"status": "absent", "reason": null, "diff_fields": ["all"]}}
```
Walkthrough: identity assertion passes; `main` exists → continue. (b) paragraph 1 resolves
**protection only** (reported `N/A (plan limitation)`, excluded); ruleset is untouched by (b)
(status isn't `na_plan_limitation`). (b) paragraph 2: ruleset still needs a write → do **not** skip.
Both-`"match"` check (unedited, 125): protection status is `"na_plan_limitation"`, not `"match"` →
false → don't take the NO-OP shortcut. "Otherwise, read the bodies..." (unedited, 127): per (b)
paragraph 2's earlier declaration, protection's planned-PUT block is omitted from the rendered
prompt exactly like an already-`"match"` half would be; ruleset's planned-POST block **is** shown
(`ruleset-post-body.json` exists on disk — Phase A writes it for `"absent"`). Human is asked to
confirm **ruleset only**. On **Yes**: per (b) paragraph 2, protection's write line never runs
regardless of the later "isn't already match" phrasing; only the ruleset POST executes. Report:
`Status:` line records `N/A (plan limitation)` for protection (new value) and whatever ruleset's
own outcome is (`APPLIED (confirmed)`, an existing value) — the file's pre-existing convention for
rendering a per-half-divergent single `Status:` line (already latent in the `BLOCKED (main branch
does not exist)` + "ruleset proceeds independently" case) is reused unchanged, not newly invented
here. `Changed:` shows the new `protection: N/A (plan limitation) — ...` line plus the existing
`ruleset: created "branch-naming-convention" ...` line. Matches AT-1 for protection, ordinary
apply-and-report flow for ruleset — proves DEFINE's point 3(b) mixed case end to end.

### AT-1 — "NO confirmation prompt for the affected field(s), no write for them"

Satisfied by (b) paragraph 1 ("its put/post body is never read or shown, its write is never
attempted") and paragraph 2 (per-half omission from the prompt; per-half exclusion from the write
lines that run on **Yes**; the all-resolved case skips the whole prompt). Proven concretely by
Fixture A (whole-prompt skip) and Fixture C (per-half omission within a still-rendered prompt).

### AT-2 — "Final report shows `N/A (plan limitation)`, mentions the process-enforcement fallback"

Satisfied by (d): the `Status:` enum gains the literal string `N/A (plan limitation)`; the two new
`Changed:` lines literally contain "process enforcement", "bot-authored PRs", "human merges",
"README", and "residual risk" — grep-checkable against the mandated fallback text in
`plugin/contracts/repo-standard.md`'s "Free-plan carve-out" section. Fixture A's walkthrough shows
both lines firing for a fully-limited run; Fixture C's shows the protection-only line firing for a
mixed run.

### AT-3 — "byte-identical for any status other than `na_plan_limitation`" — full walkthrough for Fixture B

Tracing every line Phase C reaches for Fixture B, in order, confirming each is reached with
identical bytes to the file as it exists today:

1. Pre-flight identity assertion bash block (105–117) — reached, unedited, unconditional.
2. "This block never sources `bot-auth.sh`..." (119) — reached, unedited.
3. "Re-probe that `main` exists..." (121) + both bullets (122–123) — reached; `main` exists (per
   the fixture) → "continue below." bullet taken, unedited.
4. **(b)'s two new paragraphs** — reached (they are now physically present in the file at this
   point for every run), but contribute **zero** action: neither `protection.status` nor
   `ruleset.status` is `"na_plan_limitation"` in Fixture B, so paragraph 1's "whichever half's
   status is `na_plan_limitation`" never selects anything, and paragraph 2's "if resolving
   `na_plan_limitation` this way leaves no half..." is vacuous (nothing was resolved this way).
   Execution falls through with no side effect — this is new *text*, not new *behavior*, for this
   fixture.
5. "If protection status is already `"match"`..." (125) — reached; both are literally `"match"`
   → **true** → `NO-OP (already matches)` for both, skip straight to the Final report. Identical to
   today's outcome for a healthy repo. (Bytes of this line: unedited — confirmed by (a)/(c) above.)
6. Everything after (the confirmation prompt template, the `On **Yes**`/`On **No**` paragraphs, the
   bash write block) is **not reached** for Fixture B — exactly as today (a healthy repo's `--apply`
   run has always gone straight from the both-`"match"` check to the Final report; this design adds
   no new path that changes that for a non-limited plan.json).
7. Report block (161–170): `Status:` renders `NO-OP (already matches)` — one of the six pre-existing
   values, unaffected by the newly-appended seventh (`N/A (plan limitation)`) sitting unused at the
   end of the same line. `Changed:` renders its existing three lines (or their placeholders) exactly
   as today; the two new lines added by (d) each carry their own `(only if ... status is
   "na_plan_limitation")` condition, which is false for both halves in Fixture B — neither new line
   renders.

Every line Fixture B's walkthrough reaches is byte-identical to the file today. The only file-level
change reached-but-inert for this fixture is the growth of the `Status:` enum line and the two new
`Changed:` lines — both sanctioned by AT-3 itself ("append-only extensions to existing enum lists" /
pure additions), and neither alters what gets *rendered* for a non-limited plan.json. `git diff`
for this change is: two new paragraphs inserted at one point (a), one pipe-delimited append (d), two
new lines appended (d) — no existing line's bytes are reworded, reflowed, or reordered.

---

## Constraints honored (self-check)

- Insertion point (a) quoted verbatim from the file as read in this session, not from any prior
  citation — re-derived directly, per the task's own instruction not to trust line-number claims. ✓
- New paragraph text (b) is complete, self-contained, and pasteable as-is — no `<TODO>` or
  unresolved placeholder inside it. ✓
- Every existing line identified as an AT-3 anchor (125, 127, 129–141, 143, 145–156, 158, 164 before
  the append point, 165–169 before the two new lines) is quoted and confirmed untouched. ✓
- Only append-only extensions to two things: the `Status:` enum line (164) and the `Changed:` block
  (two new lines) — everything else is pure new-paragraph insertion. ✓
- Mandated fallback text (process enforcement, bot-authored PRs + human merges, target-repo README
  note, residual-risk wording) is echoed close enough to `repo-standard.md`'s own "Free-plan
  carve-out" section to be traceable to it, in both (b)'s prose and (d)'s Report-block lines. ✓
- No file other than `plugin/commands/harden-repo.md` is in the file manifest — `repo-standard-diff.sh`
  and `repo-standard.md` are read-only grounding inputs for this design, not edited. ✓
- No `--apply` run, no `gh`/`git` write, performed by this design phase — only this design document
  was written. ✓
- No version bump (`plugin/.claude-plugin/plugin.json` untouched) — composer's job, after build. ✓
- This document cites `Future-Gadgets-AI/agentic-dev#72` (the source issue, verbatim title) as its
  requirements source; the gitignored per-run synthesized-input file this design was assembled from
  is never named by path anywhere above (grep for the literal token that would flag it: zero
  matches). ✓
