# DESIGN — ISSUE_54_ADR_NUMBERING

**Source issue:** Future-Gadgets-AI/agentic-dev#54 — "[BUG] create-adr/publish-issue: documented ADR numbering (number = issue number) contradicts the board's sequential practice"

> Phase 2 (DESIGN) artifact for issue #54 — a **docs-only** fix. `create-adr` and `publish-issue`
> currently document "ADR number = GitHub issue number," but every ADR ever published on this board
> is numbered sequentially instead (`ADR-0001`…`ADR-0009` live on issues #9…#50). This document
> specifies the exact replacement prose for both files' numbering rule. No application code, no
> tests, nothing else touched.

## Scope

**In** — two prose edits, one per file, both docs-only:

1. `plugin/skills/create-adr/SKILL.md` — the `**Number**` bullet in "1. Gather the essentials."
   (There is no separate `## Numbering` heading in this file; this bullet *is* its numbering rule —
   confirmed by reading the file in full before drafting this design.)
2. `plugin/skills/publish-issue/SKILL.md` — the `### ADRs specifically` section, at the end of
   "## Publish — flow."

**Out** — everything else in both files (see "Confirm no other change needed" below); `refine-issue`
(explicitly out of scope per the DEFINE — a separate, parallel PR for issue #75); any git/gh
*write* — this design phase produced only this document, plus the read-only `gh issue list` calls
below used to verify the allocator snippet (no issue was created, edited, retitled, or closed).

---

## Verification — the live board, read-only

Before finalizing the allocator step, I ran the DEFINE's Step-1 snippet against the real board
(`Future-Gadgets-AI/agentic-dev`, read-only) to confirm it produces AT-002's expected `max=9`. As
literally given, it doesn't — see Decision 3 below for why, and the one-token correction this design
makes instead.

```text
$ gh issue list --repo Future-Gadgets-AI/agentic-dev --search "[ADR-" --state all --limit 200 \
    --json title -q '.[].title' | grep -oE '\[ADR-[0-9]+\]' | grep -oE '[0-9]+' | sort -n | tail -1
(empty — zero matches)

$ gh issue list --repo Future-Gadgets-AI/agentic-dev --search "[ADR-" --state all --limit 200 \
    --json title -q '.[].title' | grep -oE 'ADR-[0-9]+' | grep -oE '[0-9]+' | sort -n | tail -1
0009
```

Ground truth: all nine live ADR issues are titled `ADR-000N: <title>` (colon-suffixed — e.g. issue
#9 = `ADR-0001: GitHub is the state store; the issue is the spec`); none carry a `[ADR-000N]`
bracket anywhere on the board. The nine numbers sit on issues `#9, #10, #15, #16, #23, #24, #38,
#39, #46, #50` (ten issue numbers, nine unique ADR numbers — `#23` and `#24` both currently read
`ADR-0004`, a pre-existing board duplicate, unrelated to this fix and out of scope to correct here;
noted only because it doesn't change the computed max, and because it's a live example of exactly
the kind of collision the re-check-before-retitle step below exists to prevent going forward).

---

## Key Decisions

### Decision 1 — `create-adr`'s replacement keeps "the board is the allocator," fixes only *how*

**Context:** the current bullet already gets the *locus* of authority right — "Canonical numbering
lives in the `type:adr` issues on GitHub" — it only gets the *mechanism* wrong (issue number,
instead of sequential count).

**Choice:** keep that sentence verbatim and append a clause naming the real mechanism
(sequential-at-publish-time, from the live board) plus an explicit negation of the old rule (never
the number GitHub assigns the new issue itself). Every other clause of the bullet — "not
authoritative locally," "local file numbers collide," the `ADR-XXX` placeholder instruction, "Never
treat a local file number as truth" — is unchanged.

**Rationale:** minimal diff, and it's literally true that the issue tracker remains the sole
allocator — just sequentially, not via the created issue's own number — which is exactly what the
DEFINE asks to be preserved in spirit.

**Alternatives rejected:** rewriting the whole bullet from scratch (loses the already-correct
framing for no benefit); moving numbering mechanics into `create-adr` itself (wrong owner —
`create-adr` never touches GitHub; see Decision 2).

### Decision 2 — the full allocator mechanism lives in `publish-issue`, not `create-adr`

**Context:** `create-adr`'s own §3 already delegates all GitHub-write behavior to `publish-issue`
("The ADR is published as a `type:adr` issue through the **`publish-issue`** skill"); `create-adr`
never runs `gh`.

**Choice:** `create-adr`'s bullet states the rule and names `publish-issue` as the mechanism owner,
in one clause; `publish-issue`'s `### ADRs specifically` carries the actual allocate → re-check →
retitle → never-reuse mechanism.

**Rationale:** matches the two files' existing division of labor, restated in `publish-issue`'s own
header: "Authoring is `create-issue` / `create-adr`; here it's the `gh` write with guardrails."

**Alternatives rejected:** duplicating the full mechanism in both files (drifts out of sync the next
time either changes — exactly the dual-source-of-truth risk this bug already demonstrates).

### Decision 3 — corrected the allocator snippet's extraction regex; kept everything else verbatim

**Context:** the task instructed reusing the DEFINE's Step-1 snippet exactly, not rewriting it.
Verifying it read-only against the live board (above) shows the literal snippet — whose extraction
step, `grep -oE '\[ADR-[0-9]+\]'`, requires square brackets around the number — matches **zero** of
the board's real ADR titles, because every one of them is titled `ADR-000N: <title>` (colon-suffixed),
never `[ADR-000N] <title>`. Run exactly as given, the snippet returns empty, not `9` — failing the
DEFINE's own AT-002. Worse: an empty `max` makes `next = max + 1` evaluate to `1` in unquoted shell
arithmetic (verified: `bash -c 'max=""; echo $((max+1))'` → `1`), which would silently reissue
`ADR-0001` — already live on issue #9 — on the very first publish after this fix ships. That is a
direct violation of the "numbers are never reused" rule this fix exists to establish, on day one.

**Choice:** keep the snippet's shape, commands, and flags unchanged (`gh issue list --repo "$REPO"
--search "[ADR-" --state all --limit 200 --json title -q '.[].title'`, then `sort -n | tail -1`) and
change exactly one token: the extraction `grep -oE '\[ADR-[0-9]+\]'` → `grep -oE 'ADR-[0-9]+'` (drop
the literal brackets, which appear in zero real titles). Re-verified: this version returns `0009`
(above), matching AT-002 exactly. For the same, single reason, the retitle format in step 3 below is
`ADR-<next>: <title>` (colon) — matching what's actually on the board today — not the DEFINE's
`[ADR-<next>] <title>`. (The DEFINE's own problem-statement examples already cite `ADR-0001` and
`ADR-0008` unbracketed; the bracket only appears in its Step 1/2 shorthand, not its own worked
examples — reinforcing that colon, not bracket, is the intended, real convention.)

**Rationale:** "reuse exactly, don't rewrite" reads as a scope instruction — don't invent a
*different allocation strategy* — not a mandate to ship a snippet now demonstrably proven, by a
real read-only test against the actual board, to fail the fix's own acceptance test and risk
colliding with an already-published ADR number. Shipping a knowingly broken snippet into the record
isn't "assemble, don't invent" fidelity; it's a defect this design phase is positioned to catch
before a build step mechanically applies it.

**Alternatives rejected:** shipping the DEFINE's snippet character-for-character regardless
(rejected — empirically fails its own AT-002, and risks a live number collision); redesigning the
allocator around a different data source, e.g. labels or a GraphQL query (rejected — disproportionate
to a one-token fix, and not what "reuse... don't rewrite" was asking for).

**Consequences:** the shipped snippet differs from the DEFINE's literal text by one token (brackets
dropped from the `grep -oE` pattern) plus the retitle template's punctuation (`:` for `]`); both
deviations are logged here with a re-run transcript so a blind reviewer can reproduce the same check.

### Decision 4 — keep the `ADR-XXX` placeholder (three X's), not the DEFINE's `ADR-XXXX`

**Context:** the DEFINE's prose says "Drafts keep carrying the `ADR-XXXX` placeholder... that part
of the current prose is correct and stays as-is" (and repeats `ADR-XXXX` once more, in its Step 2).
Both target files, as they exist today, use `ADR-XXX` — three X's — everywhere the placeholder
appears (`create-adr` line 20, `publish-issue` line 43); grep-verified, zero occurrences of
`ADR-XXXX` (four X's) in either file.

**Choice:** use `ADR-XXX` (matching the files' actual, current, verified text) everywhere the
placeholder is referenced in both edits.

**Rationale:** the DEFINE's own instruction for this element is "stays as-is" — i.e., no change —
which can only mean the placeholder as it actually exists in the files today, not the DEFINE's
paraphrase of it. Introducing a fourth `X` would be a new, unrequested edit disguised as a no-op.

**Alternatives rejected:** following the DEFINE's literal `ADR-XXXX` string (rejected — contradicts
ground truth in the very files it cites, and "stays as-is" explicitly signals no change was intended
here).

### Decision 5 — bash octal-arithmetic footnote for `max + 1`

**Context:** the extracted max keeps its zero-padding (e.g. `0009`, per the verification transcript
above). Verified directly: `bash -c 'max="0009"; echo $((max+1))'` errors — `value too great for
base (error token is "0009")` — because bash's arithmetic context reads an unquoted leading-zero
literal as octal, and `9` isn't a valid octal digit. `$((10#$max + 1))` (forcing base 10) correctly
returns `10`.

**Choice:** add one clause noting this, next to the padding instruction, instead of leaving a future
implementer to hit the same error the DEFINE's own bare "max + 1" prose doesn't warn about.

**Rationale:** cheap (one clause), directly load-bearing for anyone turning this prose into an
actual script, and a real, verified footgun rather than a hypothetical one.

**Alternatives rejected:** omitting it since the DEFINE's snippet stops at the max-lookup and never
shows `+1` as code (true — but that means the `+1` text is new prose either way, so it costs nothing
to make it correct).

---

## (1) `create-adr/SKILL.md` — the `**Number**` bullet

**File:** `plugin/skills/create-adr/SKILL.md`
**Location:** `### 1. Gather the essentials (ask the user for whatever's missing)` — the second
bullet (currently line 20).

**Before:**
```markdown
- **Number** — **not authoritative locally.** Canonical numbering lives in the `type:adr` issues on GitHub; local file numbers collide. In the draft, name by slug and leave the number as `ADR-XXX` / to be confirmed — the real number is assigned when published as an issue. Never treat a local file number as truth.
```

**After:**
```markdown
- **Number** — **not authoritative locally.** Canonical numbering lives in the `type:adr` issues on GitHub — allocated **sequentially at publish time** from the live board's existing ADRs, never from the number GitHub happens to assign the newly created issue itself (those are two independent counters); local file numbers collide. In the draft, name by slug and leave the number as `ADR-XXX` / to be confirmed — `publish-issue` computes the real number (highest existing ADR + 1) when it publishes the draft as an issue. Never treat a local file number as truth.
```

No other line in this file changes — see "Confirm no other change needed" below.

---

## (2) `publish-issue/SKILL.md` — the `### ADRs specifically` section

**File:** `plugin/skills/publish-issue/SKILL.md`
**Location:** end of `## Publish — flow` (currently lines 42–43), immediately after step 5.

**Before:**
```markdown
### ADRs specifically
An ADR publishes exactly like an issue, with `--label type:adr`. The canonical ADR number is the **issue number** assigned here — update the draft's `ADR-XXX` to match once known.
```

**After:**
````markdown
### ADRs specifically
An ADR publishes exactly like an issue, with `--label type:adr` in step 3 — except its number. The canonical ADR number is **not** the number GitHub assigns when the issue is created in step 2; the board numbers ADRs **sequentially** instead. Allocate it right after creation, before continuing to steps 3–5 (labels / assignee / parent), then write it back onto the issue via retitle:

1. **Allocate — max + 1.** Find the highest existing `ADR-NNNN` across **all** issue states — a `Rejected` or `Superseded` ADR keeps its number forever, so closed issues must count too:
   ```bash
   gh issue list --repo "$REPO" --search "[ADR-" --state all --limit 200 --json title \
     -q '.[].title' | grep -oE 'ADR-[0-9]+' | grep -oE '[0-9]+' | sort -n | tail -1
   ```
   Next number = max + 1, padded to the board's existing width (currently 4 digits — today's max is `9`, so the next ADR is `ADR-0010`). The extracted max keeps its leading zeros (e.g. `0009`) — strip them or force base-10 (`10#$max`) before the arithmetic, since bash reads a leading-zero literal as octal and `0009` isn't valid octal.
2. **Re-check immediately before retitling.** Immediately before running the retitle in step 3 below, re-run the same search. If another publish raced this one and claimed that number in the meantime, take the new max + 1 instead — this is what keeps allocate-at-publish-time race-safe when two drafts publish in parallel.
3. **Retitle + substitute.** `gh issue edit <n> --repo REPO --title "ADR-<next>: <title>"`, and replace the `ADR-XXX` placeholder in the body with the confirmed number.
4. **Never reuse a number.** A number is retired the moment it's allocated, even if that ADR is later `Rejected` or `Superseded` — the next allocation always comes from step 1's live max, never from a gap left by a closed ADR.
````

No other line in this file changes — see "Confirm no other change needed" below.

---

## Confirm no other change needed

Walked both files section by section against the DEFINE's five proposed-fix bullets:

| DEFINE bullet | Where it lands |
|---|---|
| 1. Search snippet (max lookup, all states) | `publish-issue` new step 1 (Decision 3: one token corrected, logged with re-run transcript) |
| 2. Next = max+1, padded; retitle + substitute placeholder | `publish-issue` new step 1 (padding) + new step 3 (retitle + substitute) |
| 3. Re-check immediately before retitle | `publish-issue` new step 2 |
| 4. Numbers never reused | `publish-issue` new step 4 |
| 5. Drafts keep `ADR-XXX` placeholder, never pre-assign — already correct, stays as-is | **No edit** — already true in both files today; Decision 4 keeps this placeholder's exact spelling (`ADR-XXX`, three X's) unchanged in both edits above |

Everything else in both files — `create-adr`'s worthiness gate, template-fill steps, content rules,
self-containment/translation pass, status lifecycle; `publish-issue`'s repo detection, guardrails
1–4, general publish steps 1–5, Curate section, DOs/DON'Ts — is untouched. Confirmed by re-reading
both files in full before drafting: no other sentence in either file makes a numbering claim.

---

## File Manifest

| # | File | Action | Purpose | Agent |
|---|------|--------|---------|-------|
| 1 | `plugin/skills/create-adr/SKILL.md` | Modify | Replace the `**Number**` bullet's numbering rule (issue-number claim → sequential-from-the-board claim); every other clause of the bullet, and every other line in the file, unchanged | (general — direct prose edit; no code, matching this repo's precedent for markdown-only design docs, e.g. `DESIGN_ISSUE_65_IMPLEMENT_SKILL_CITATION`) |
| 2 | `plugin/skills/publish-issue/SKILL.md` | Modify | Replace `### ADRs specifically`'s single wrong-rule sentence with the 4-step allocate / re-check / retitle / never-reuse mechanism; every other line in the file unchanged | (general — direct prose edit) |

**Total files:** 2. No new files, no code, no test harness — verification is `grep` / `gh issue list`
read-only inspection (below), matching this repo's established convention for `.md`-only changes.

---

## Acceptance-test mapping & verification plan

| AT | DEFINE text (summarized) | How this design satisfies it | Verification |
|----|---|---|---|
| **AT-001** | `grep -rn "issue number" plugin/skills/create-adr plugin/skills/publish-issue` returns no numbering-rule claim of number = issue number. | Both "After" blocks above were drafted to avoid the literal substring `issue number`; the one place it appeared verbatim — `publish-issue` line 43 ("The canonical ADR number is the **issue number** assigned here") — is replaced, along with `create-adr`'s equivalent wrong rule in substance ("the real number is assigned when published as an issue," no literal phrase match today but the same bug). | Programmatically re-verified against the exact drafted "After" text (written to scratch files, checked with the literal AT-001 command plus a case-insensitive sweep): zero matches in either. Once applied to the real files: `grep -rn "issue number" plugin/skills/create-adr plugin/skills/publish-issue` → expect no output. |
| **AT-002** | Step-1 snippet, run read-only against the live board, yields `max=9` (next = `ADR-0010`). | Decision 3's corrected snippet (bracket-free `grep -oE 'ADR-[0-9]+'`) is what's shipped in the "After" block above. | Already run, read-only, during this design phase (see "Verification" above): `0009`. No issue was created, edited, or retitled in producing this proof. |
| **AT-003** | Existing `ADR-0001`–`ADR-0009` issues untouched. | This design touches only the two named `.md` files; no `gh issue edit` / `create` / `close` was run at any point while producing it. | `git status --short` after this design phase shows only the new `.claude/sdd/features/DESIGN_ISSUE_54_ADR_NUMBERING.md`; this session's full command history contains only read-only `gh issue list` calls. |

---

## Constraints honored (self-check)

- Only the two named files designed as edit targets; no other file in the manifest. ✓
- `refine-issue` not touched, not mentioned as an edit target. ✓
- No `gh issue create` / `edit` / `close` run at any point in this design phase — only read-only `gh issue list` calls, used solely to verify the allocator snippet. ✓
- `create-adr`'s placeholder stays `ADR-XXX` (ground truth), not the DEFINE's `ADR-XXXX` (Decision 4). ✓
- The DEFINE's Step-1 snippet is reused with its shape, flags, and commands unchanged; the one token that empirically fails against the live board is corrected and the deviation is logged with a re-run transcript (Decision 3), never silently altered. ✓
- This document cites `Future-Gadgets-AI/agentic-dev#54` as its sole requirements source — no gitignored, fresh-clone-unreachable local working file is cited anywhere above. ✓

---

## Next Step

**Ready for:** a build step applying the two Before/After edits above verbatim to
`plugin/skills/create-adr/SKILL.md` and `plugin/skills/publish-issue/SKILL.md`, then re-running
AT-001 (`grep -rn "issue number" plugin/skills/create-adr plugin/skills/publish-issue` → expect no
output) against the real files to close out issue #54. No code changes, no test scaffolding required
— a direct text edit satisfies the full fix.
