# DESIGN — ISSUE_66_REPO_STANDARD_SCRIPT_INTERFACES

> Phase 2 (DESIGN) artifact for issue #66 — unify the `repo-standard-*.sh` confirmation/reviewer
> CLI shapes and close the owner-handle-validation gap that let `apply-codeowners.sh OWNER/REPO
> --confirmed` silently write `* @--confirmed`. Headless run. The synthesized DEFINE's pinned
> direction (**unify-interface**, closing D3) is honored as fixed — not re-litigated, only
> translated into an implementable spec. `plugin/contracts/repo-standard.md`'s canonical Decisions
> D1–D10 (recorded in `DESIGN_ISSUE_36_REPO_HARDENING.md`) are referenced, not renumbered; this
> issue only **updates D9's header text** (per the pinned direction) and adds unnumbered,
> issue-scoped design notes below — it does not extend the D-series.

## Scope

**In scope (per the pinned direction):**
- New flag-based argument interface for `repo-standard-apply-codeowners.sh`.
- Offline owner-handle validation (reject `-`-prefixed tokens, reject an empty reviewer list),
  fully resolved before any network call.
- The one live call site: `plugin/commands/harden-repo.md`'s A2 CODEOWNERS sub-step.
- Documenting the shared CLI convention — and its one deliberate asymmetry — in
  `plugin/contracts/repo-standard.md`.

**Out of scope (explicitly, per the DEFINE doc):**
- `repo-standard-apply-labels.sh`'s argument shape — stays exactly as-is; only cross-referenced.
- `repo-standard-diff.sh` — unchanged in every respect, including its own `--reviewers`
  credential-fallback default.
- API-based existence verification of owner handles (offline, syntactic validation only).
- `.claude/sdd/features/DESIGN_ISSUE_36_*` / `.claude/sdd/reports/BUILD_REPORT_ISSUE_36_*` —
  historical, already-shipped records; not call sites, not touched.
- Any git/gh operation — this design phase produces only this artifact.

## Architecture — call graph

```
plugin/commands/harden-repo.md (A2 sub-step)
        │  bash .../repo-standard-apply-codeowners.sh "<owner/repo>" --reviewers "$REVIEWERS" --confirmed
        ▼
plugin/scripts/repo-standard-apply-codeowners.sh   ◀── CLI shape documented in ──┐
        │  (validate  →  source bot-auth.sh  →  gh api reads/writes)             │
        ▼                                                                         │
GitHub (Contents + Git Data API)                                                  │
                                                                                    │
plugin/contracts/repo-standard.md ── new "CLI convention" section ────────────────┘
   (cross-references apply-labels.sh + repo-standard-diff.sh too — neither changes)
```

## Architecture — validation flow (the fix, in order)

```
repo-standard-apply-codeowners.sh OWNER/REPO --reviewers "..." --confirmed
        │
        ▼
 [1] OWNER/REPO positional present? ───no──▶ usage error (bash ${1:?..}), exit≠0
        │ yes
        ▼
 [2] parse flags in a loop: --reviewers <val> | --confirmed | * ──unknown──▶ usage error, exit≠0
        │ ok
        ▼
 [3] --confirmed seen? ───no──▶ usage error, exit≠0
        │ yes
        ▼
 [4] --reviewers value non-empty? ───no──▶ usage error, exit≠0
        │ yes
        ▼
 [5] split on whitespace → any token starts with "-"? ──yes──▶ usage error, exit≠0 (names the token)
        │ no
        ▼
 [6] resulting token count > 0? ───no──▶ usage error, exit≠0 ("no reviewers resolved")
        │ yes
        ▼
 [7] python3 on PATH? ───no──▶ dependency error, exit≠0
        │ yes
        ══════════════════════════ NETWORK BOUNDARY ══════════════════════════
        ▼
 source bot-auth.sh  (gh auth setup-git, gh api user)         [UNCHANGED]
        ▼
 TARGET_LINE construction → current-content read → empty-repo vs
 has-history branch → direct commit | branch+draft PR          [ALL UNCHANGED — D8/D9]
```

Every check above the network boundary is offline and lexically precedes `source
"$HERE/bot-auth.sh"` — this is what makes AT-2/AT-3's "zero network calls" provable by construction,
not convention (same proof style `repo-standard-diff.sh`'s own header already uses for its own
zero-write claim).

## Inline design decisions (issue #66 — not part of the D1–D10 canon)

- **Validation order matches the DEFINE's own enumeration**: `--confirmed` is checked *before*
  `--reviewers`, so AT-3's regression (`OWNER/REPO --confirmed` alone) fails specifically on
  "missing `--reviewers`" — exactly how the DEFINE doc characterizes that acceptance test.
- **Two independent "empty" checks, not one**: `--reviewers` omitted or passed as `""` is caught by
  a plain `[ -n "$REVIEWERS" ]` guard (message: "missing --reviewers"); `--reviewers "   "`
  (non-empty string, but whitespace-only) passes that guard and is instead caught after
  word-splitting yields zero tokens (message: "no reviewers resolved", reused verbatim from the
  script's existing text). Both are real, distinct ways to trigger AT-2's "empty owner list" case.
- **Dash-check and empty-count-check share one loop** over the whitespace-split tokens — simplest
  correct implementation, no second pass needed.
- **The existing post-bot-auth.sh script body (TARGET_LINE construction → empty-repo/has-history
  branches) is preserved BYTE-IDENTICAL**, per the instruction that this logic stay "unchanged in
  behavior." Its own `[ "$TARGET_LINE" != "*" ]` empty-check therefore becomes unreachable dead
  code (the new pre-flight gate already guarantees a non-empty, validated `REVIEWERS` by the time
  execution reaches it). This is intentional belt-and-suspenders from the minimal-diff instruction,
  **not** a bug — the build phase should not "clean up" or remove it.
- **No `usage()` helper function and no `-h`/`--help` flag added.** Not requested by the DEFINE's
  enumerated checks; inline `echo ... >&2; exit 1` messages are used instead, matching
  `apply-labels.sh`'s existing convention for the one message the two scripts now share verbatim
  (`refusing — missing --confirmed (the confirmation gate is the caller's job).`) — this satisfies
  AT-1 at the literal string level, not just structurally. Adding a shared-message function or a
  help flag would be scope beyond the pinned direction.
- **No `OWNER/REPO` shape check** (e.g. `repo-standard-diff.sh`'s `case "$REPO" in */*) ;; ... esac`)
  is added here. It is not part of the DEFINE's enumerated validation sequence for this script;
  deliberately left out to avoid scope creep beyond the pinned direction.
- **New contract section placed between "CODEOWNERS — format" and "Bot wiring — pointer"** — it is
  cross-cutting script-mechanics content, like Bot wiring, and sits immediately after the section it
  most overlaps with (CODEOWNERS reviewers). The existing "CODEOWNERS — format" section's own text
  ("Reviewers come from the tool's `--reviewers` argument, defaulting to `AGENTIC_REVIEWERS`.") is
  left **untouched** — it remains an accurate end-to-end (contract-level) statement; the new section
  adds the script-level precision (which script defaults internally vs. which requires an
  already-resolved value) that the DEFINE asks to be named explicitly.
- **`harden-repo.md`'s "gate: NONE" heading and its D9 cross-reference paragraph are left
  UNCHANGED** — per the pinned direction, `--confirmed` does not create a human gate at this
  sub-step. Only the invocation line changes, plus one clarifying sentence is added so a future
  reader isn't confused by seeing `--confirmed` inside a "gate: NONE" sub-step.
- **In the normal `/harden-repo` call path, the new validation should never actually trip.**
  `harden-repo.md` already gates on `plan.json`'s `codeowners.status == "blocked_no_reviewers"`
  *before* it ever constructs `REVIEWERS` or invokes the script (see its A2 section), so by the time
  the script runs, `REVIEWERS` is always a real, already-resolved login list. The new validation is
  a defense-in-depth safety net for **direct/manual invocation** — exactly how the original #66 bug
  was triggered (a human running the script by hand from muscle memory on `apply-labels.sh`'s
  shape). No `harden-repo.md` "Report block" Status value changes as a result.

---

## (a) `plugin/scripts/repo-standard-apply-codeowners.sh` — new argument interface

**Replace lines 1–29 of the current file (shebang through `source "$HERE/bot-auth.sh" || exit 1`)
with the block below. Leave line 30 (blank) and everything from line 31 (`TARGET_LINE="*"`) through
EOF (current line 177) byte-for-byte unchanged** — that is the existing TARGET_LINE construction,
current-content read, effective-rules compare, empty-repo-vs-has-history detection, and both write
branches.

```bash
#!/usr/bin/env bash
# repo-standard-apply-codeowners.sh OWNER/REPO --reviewers "reviewer1 reviewer2 ..." --confirmed
#
# Phase A2 of /harden-repo: write .github/CODEOWNERS so it lists every given
# reviewer login. `--confirmed` is REQUIRED, but it is not a new human-safety
# gate (Decision D9 — fully reversible: a PR still needs a human merge
# regardless, and a direct commit on a repo with zero prior history disturbs
# nothing, both stay true). The flag exists purely so this script's CLI shape
# matches apply-labels.sh's (OWNER/REPO ... --confirmed) — interface
# consistency across the repo-standard-*.sh family (see #66), not a gate the
# caller must earn. Idempotent either way (Decision D8): no-op if current
# content already equals the target line; an already-open PR from the
# deterministic branch is reused, never duplicated.
#
# Argument validation — ALL of the below happens before bot-auth.sh is
# sourced (sourcing it already performs network calls of its own: `gh auth
# setup-git`, `gh api user`), so a bad invocation never touches the network:
#   - OWNER/REPO positional required.
#   - --reviewers "..." and --confirmed both required, order-independent;
#     any other argument is an unknown-argument usage error.
#   - --reviewers's value is split on whitespace; the resulting list must be
#     non-empty, and no token may start with "-" — a flag silently absorbed
#     as an owner handle (e.g. `apply-codeowners.sh OWNER/REPO --confirmed`
#     alone, the original #66 bug) is exactly the mistake this closes.
#   - API-based existence-checking of the handles themselves is out of scope
#     (offline, syntactic validation only).
#
# Runs as the BOT: self-sources bot-auth.sh (fail-fast, structural — Decision
# D6). Pure `gh api` (Contents + Git Data API) for BOTH the empty-repo direct
# commit and the has-history branch+PR path — no local `git clone` needed,
# matching the empty-repo path's own technique (Pattern 4) rather than
# introducing a filesystem side effect this script would otherwise not need.
set -uo pipefail

REPO="${1:?usage: repo-standard-apply-codeowners.sh OWNER/REPO --reviewers \"reviewer1 reviewer2 ...\" --confirmed}"
shift || true

REVIEWERS=""
CONFIRMED=0
while [ $# -gt 0 ]; do
  case "$1" in
    --reviewers) shift; REVIEWERS="${1:?--reviewers needs a value}" ;;
    --confirmed) CONFIRMED=1 ;;
    *)
      echo "repo-standard-apply-codeowners: unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift || true
done

[ "$CONFIRMED" -eq 1 ] || {
  echo "repo-standard-apply-codeowners: refusing — missing --confirmed (the confirmation gate is the caller's job)." >&2
  exit 1
}

[ -n "$REVIEWERS" ] || {
  echo "repo-standard-apply-codeowners: refusing — missing --reviewers (a space-separated list of GitHub logins is required)." >&2
  exit 1
}

REVIEWER_COUNT=0
for r in $REVIEWERS; do
  case "$r" in
    -*)
      echo "repo-standard-apply-codeowners: refusing — reviewer token '$r' looks like a flag (starts with '-'), not a GitHub login." >&2
      exit 1
      ;;
  esac
  REVIEWER_COUNT=$((REVIEWER_COUNT + 1))
done
[ "$REVIEWER_COUNT" -gt 0 ] || {
  echo "repo-standard-apply-codeowners: no reviewers resolved — refusing to write an empty CODEOWNERS rule." >&2
  exit 1
}

command -v python3 >/dev/null 2>&1 || {
  echo "repo-standard-apply-codeowners: python3 is required (decodes the current CODEOWNERS content) and is not on PATH." >&2
  exit 1
}

HERE="$(cd "$(dirname "$0")" && pwd)"
# Act as the bot (fail-fast; never fall back to a personal account).
# shellcheck source=/dev/null
source "$HERE/bot-auth.sh" || exit 1
```

### Exact new messages introduced/changed

| # | Trigger | Exact stderr text | Exit |
|---|---------|--------------------|------|
| 1 | `OWNER/REPO` positional missing | bash's own `${1:?..}` prefix + `usage: repo-standard-apply-codeowners.sh OWNER/REPO --reviewers "reviewer1 reviewer2 ..." --confirmed` | non-zero |
| 2 | `--reviewers` is the last token, no value follows | bash's own `${1:?..}` prefix + `--reviewers needs a value` | non-zero |
| 3 | Unrecognized argument | `repo-standard-apply-codeowners: unknown argument: <token>` | 1 |
| 4 | `--confirmed` never supplied | `repo-standard-apply-codeowners: refusing — missing --confirmed (the confirmation gate is the caller's job).` | 1 |
| 5 | `--reviewers` value is `""` (omitted or explicitly empty) | `repo-standard-apply-codeowners: refusing — missing --reviewers (a space-separated list of GitHub logins is required).` | 1 |
| 6 | A whitespace-split token starts with `-` | `repo-standard-apply-codeowners: refusing — reviewer token '<token>' looks like a flag (starts with '-'), not a GitHub login.` | 1 |
| 7 | `--reviewers` value is non-empty but splits to zero tokens (e.g. all whitespace) | `repo-standard-apply-codeowners: no reviewers resolved — refusing to write an empty CODEOWNERS rule.` (reused verbatim) | 1 |

Messages 1 and 2 use bash's native `${var:?message}` mechanism (identical technique the current
script and `repo-standard-diff.sh` already use for their own required-value checks) — no manual
script-name prefix on those two, matching `repo-standard-diff.sh`'s own `--reviewers needs a value`
precedent exactly.

---

## (b) `plugin/commands/harden-repo.md` — call-site update

**Before** (current lines 43–48):
```markdown
Otherwise, resolve the reviewer list once — the **same** list Phase A used: the `--reviewers` value if the invocation carried one; else extract `AGENTIC_REVIEWERS` from the bot credentials file without sourcing it (never reconstruct it by parsing `plan.json`'s composed `codeowners.target` rendering):

```bash
CFG="${AGENTIC_DEV_CONFIG_DIR:-$HOME/.config/agentic-dev}/credentials"
REVIEWERS="$(grep -E '^[[:space:]]*AGENTIC_REVIEWERS[[:space:]]*=' "$CFG" | tail -1 | sed -E 's/^[^=]*=[[:space:]]*//; s/^["'"'"']//; s/["'"'"']$//')"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/repo-standard-apply-codeowners.sh" "<owner/repo>" "$REVIEWERS"
```
It self-sources `bot-auth.sh` — if bot wiring isn't ready, it fails fast; report `BLOCKED (bot wiring absent)` with the exact fix command from its stderr.
```

**After:**
```markdown
Otherwise, resolve the reviewer list once — the **same** list Phase A used: the `--reviewers` value if the invocation carried one; else extract `AGENTIC_REVIEWERS` from the bot credentials file without sourcing it (never reconstruct it by parsing `plan.json`'s composed `codeowners.target` rendering):

```bash
CFG="${AGENTIC_DEV_CONFIG_DIR:-$HOME/.config/agentic-dev}/credentials"
REVIEWERS="$(grep -E '^[[:space:]]*AGENTIC_REVIEWERS[[:space:]]*=' "$CFG" | tail -1 | sed -E 's/^[^=]*=[[:space:]]*//; s/^["'"'"']//; s/["'"'"']$//')"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/repo-standard-apply-codeowners.sh" "<owner/repo>" --reviewers "$REVIEWERS" --confirmed
```
`--confirmed` here is a required literal for the script's own CLI interface (unifying its shape with `apply-labels.sh`'s — Decision D9), not a human-facing prompt — this sub-step's gate stays `NONE`, unchanged.

It self-sources `bot-auth.sh` — if bot wiring isn't ready, it fails fast; report `BLOCKED (bot wiring absent)` with the exact fix command from its stderr.
```

**Single-line diff, for an exact find-replace:**
- `- bash "${CLAUDE_PLUGIN_ROOT}/scripts/repo-standard-apply-codeowners.sh" "<owner/repo>" "$REVIEWERS"`
- `+ bash "${CLAUDE_PLUGIN_ROOT}/scripts/repo-standard-apply-codeowners.sh" "<owner/repo>" --reviewers "$REVIEWERS" --confirmed`
- plus one new sentence inserted immediately after the closing ` ``` ` of that code block, before the existing "It self-sources `bot-auth.sh`..." line (shown in **After** above).

**Surrounding prose — explicitly checked, no change needed:**
- Heading `## A2 — CODEOWNERS (identity: bot · gate: NONE)` (line 35) — **UNCHANGED**. Per the
  pinned direction, `--confirmed` does not introduce a human gate; the heading stays accurate.
- Line 37's "No human gate: fully reversible ... (Decision D9)" paragraph — **UNCHANGED**; still
  true, and is exactly the rationale the script header now also carries.
- Frontmatter `argument-hint` (line 3) and the "Parse arguments" section's own `--reviewers`
  description (lines 10–17) — **UNCHANGED**; those describe `/harden-repo`'s own slash-command
  arguments, an unrelated CLI surface from the internal script's flags.
- "Report block" template (lines 50–56) — **UNCHANGED**; none of its possible `Status` values
  change (see the design-notes bullet above on why the new validation shouldn't trip in normal
  `/harden-repo` operation).

---

## (c) `plugin/contracts/repo-standard.md` — new section

**Insert the section below immediately after** the "## CODEOWNERS — format" section's last line
(`Observed live example (agentic-dev, exported 2026-07-04): `* @gustavomoura628 @lucasbrandao4770 @thallersubtil`\``) **and immediately before** the line `## Bot wiring — pointer (never re-derive credential logic here)`.

```markdown
## repo-standard-*.sh family — CLI convention

All three `repo-standard-*.sh` scripts share one invocation shape: a required positional
`OWNER/REPO` first, then named flags, order-independent. This section is the single source of
truth for that shape — do not re-derive it from any one script's own comments.

| Script                                | Positional   | Flags                                                      | `--confirmed`        | `--reviewers`                                                          |
|----------------------------------------|--------------|--------------------------------------------------------------|-----------------------|--------------------------------------------------------------------------|
| `repo-standard-diff.sh`                | `OWNER/REPO` | `--reviewers "..."` (optional)                                | n/a — read-only, nothing to gate | optional; **falls back** to `AGENTIC_REVIEWERS` from the bot credentials file when omitted |
| `repo-standard-apply-codeowners.sh`    | `OWNER/REPO` | `--reviewers "..."` (required), `--confirmed` (required)      | **required**          | **required** — never defaults from credentials                           |
| `repo-standard-apply-labels.sh`        | `OWNER/REPO` | `--confirmed` (required)                                      | **required**          | n/a — no reviewer concept                                                 |

**The `--reviewers` asymmetry is deliberate, not a bug.** `repo-standard-diff.sh` is read-only — it
never writes anything, so a convenience default (falling back to `AGENTIC_REVIEWERS` when
`--reviewers` is omitted) carries no risk of an unintended write. `repo-standard-apply-codeowners.sh`
performs real writes (a direct commit or a branch + PR) — it never resolves a reviewer list on the
caller's behalf; the caller (`/harden-repo`) must pass `--reviewers` explicitly, every time. Do not
"fix" this asymmetry by adding a credential fallback to the apply script, and do not remove
`diff.sh`'s fallback for "consistency" — they serve different modes (read vs. write) on purpose.

**`--confirmed` is required by both apply scripts** (`apply-codeowners.sh`, `apply-labels.sh`) —
never optional, never defaulted. It is a CLI-interface consistency marker across the family, not by
itself a human-safety gate: for `apply-labels.sh`, the actual human confirmation happens one layer
up, in `/harden-repo`'s Phase B prompt; for `apply-codeowners.sh` there has never been a human gate
at this sub-step (Decision D9 — full reversibility makes one unnecessary) and `--confirmed` does not
add one. Either way, the script itself never prompts — the caller decides; the script only refuses
to run silently un-confirmed.

**Owner-handle validation** (`apply-codeowners.sh` only, offline, before any network call): the
`--reviewers` value is split on whitespace; the resulting list must be non-empty, and no token may
start with `-` (a flag silently absorbed as an owner handle — e.g. invoking with `--confirmed` where
`--reviewers` was expected — is exactly the bug this rule closes; see #66). Both checks fail with a
usage error and a non-zero exit **before** `bot-auth.sh` is sourced, since sourcing it already
performs network calls (`gh auth setup-git`, `gh api user`) independent of the target repo.
API-based existence verification of the handles themselves is explicitly out of scope — this is
offline, syntactic validation only.
```

---

## (d) File manifest

| File | Action | Reason |
|------|--------|--------|
| `plugin/scripts/repo-standard-apply-codeowners.sh` | Modify | Rewrite argument parsing/validation (usage header + lines 1–29 per section (a)); rest of the script is unchanged behavior. |
| `plugin/commands/harden-repo.md` | Modify | Update the one live A2 CODEOWNERS invocation line to the new flag interface + add one clarifying sentence (section (b)). |
| `plugin/contracts/repo-standard.md` | Modify | Add the new "CLI convention" section documenting the shared shape, the `--confirmed` requirement, the `--reviewers` asymmetry, and the owner-handle validation rule (section (c)). |

**Explicitly NOT in this manifest** (behavior unchanged, per the hard constraints):
`plugin/scripts/repo-standard-apply-labels.sh` and `plugin/scripts/repo-standard-diff.sh` — both
are only cross-referenced/quoted inside the new contract section, never modified themselves.

---

## (e) Acceptance-test mapping & verification plan

| AT | DEFINE text (summarized) | How this design satisfies it | Verification |
|----|---------------------------|-------------------------------|---------------|
| **AT-1** | Both scripts share one documented confirmation convention. | New `repo-standard.md` "CLI convention" section (c) documents both apply scripts requiring `--confirmed`; both scripts' usage headers state it; both use the **identical** refusal message `refusing — missing --confirmed (the confirmation gate is the caller's job).`, differing only in the script-name prefix (`repo-standard-apply-codeowners:` vs. `repo-standard-apply-labels:`). | **Inspection** — read the new contract section side-by-side with both scripts' top-of-file comment + validation code; confirm they match. Not executed — this AT is a documentation/interface-consistency check per the DEFINE's own framing. |
| **AT-2** | `apply-codeowners.sh` rejects (a) a `-`-prefixed owner token and (b) an empty owner list, each: usage error, non-zero exit, **zero network calls** — proven against a dummy slug. | Pre-flight validation block (section (a), checks [5] and [6] in the flow diagram) sits strictly before `source "$HERE/bot-auth.sh"`. | **Execution**, against a non-existent dummy slug, e.g.: `bash plugin/scripts/repo-standard-apply-codeowners.sh example-org/example-repo --reviewers "-x alice" --confirmed` → expect non-zero exit, stderr `reviewer token '-x' looks like a flag...`. `bash plugin/scripts/repo-standard-apply-codeowners.sh example-org/example-repo --reviewers "   " --confirmed` → expect non-zero exit, stderr `no reviewers resolved...`. In both: no `bot-auth:`-prefixed line anywhere in the output (success or failure) and no observable network latency — corroborating zero `gh` calls, true by construction since both checks are lexically before the `source bot-auth.sh` line. |
| **AT-3** | The exact original bad invocation (`OWNER/REPO --confirmed`, `--reviewers` never supplied) exits non-zero with a usage error, no writes — run for real against a dummy slug. | `CONFIRMED` check passes (flag was given), then `[ -n "$REVIEWERS" ]` fails → the "missing `--reviewers`" message — exactly the failure mode the DEFINE names. | **Execution**: `bash plugin/scripts/repo-standard-apply-codeowners.sh example-org/example-repo --confirmed` → expect non-zero exit, stderr `refusing — missing --reviewers (a space-separated list of GitHub logins is required).`, no `.github/CODEOWNERS` write (trivially true — no `gh` call of any kind occurs before this exit). |

---

## Constraints honored (self-check)

- `repo-standard-apply-labels.sh` argument shape — not touched, only quoted in the new contract
  section. ✓
- `repo-standard-diff.sh` — not touched at all. ✓
- `.claude/sdd/features/DESIGN_ISSUE_36_*` / `.claude/sdd/reports/BUILD_REPORT_ISSUE_36_*` — not
  read for editing purposes beyond confirming there is no other live call site (grepped, one found:
  `harden-repo.md`); not modified. ✓
- No git commit, no git push, no `gh`/GitHub API call made during this design phase — only this
  file was written. ✓
- File manifest is exactly the three files named in the task, no more, no less. ✓
- Every validation check in (a) is placed before `source "$HERE/bot-auth.sh"`, verified by tracing
  the flow diagram against the replacement code block line-by-line. ✓
