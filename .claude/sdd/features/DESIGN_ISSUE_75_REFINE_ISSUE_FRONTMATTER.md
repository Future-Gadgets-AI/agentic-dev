# DESIGN — ISSUE_75_REFINE_ISSUE_FRONTMATTER

**Requirements source:** Future-Gadgets-AI/agentic-dev#75 — "[BUG] refine-issue SKILL.md frontmatter fails strict YAML parse (unquoted ': ' in description)"

> Phase 2 (DESIGN) artifact for issue #75 — a pure YAML re-encoding fix (Part A, required) plus a
> bounded-attempt CI gate (Part B, may be dropped cleanly by the build phase per the issue's own
> "~2 honest tries" clause). Headless run. No code written, no git/gh writes performed — the
> Before/After blocks below are for the build phase to apply; everything this design phase itself
> verified was run against a **scratch copy** outside the working tree (see (a)), never the real
> `plugin/skills/refine-issue/SKILL.md`.

## Scope

**In (Part A — required):**
1. `plugin/skills/refine-issue/SKILL.md`'s `description:` field: unquoted plain scalar → `>-`
   (folded) block scalar, matching `night-shift/SKILL.md`'s exact style. Wording untouched — this
   is a pure YAML-encoding change.

**In (Part B — attempt, boundable per the issue's own instruction):**
2. A new `plugin-validate` job added to the existing `.github/workflows/bump-gate.yml`, installing
   the Claude Code CLI and running `claude plugin validate plugin/`, failing the job on non-zero
   exit.

**Out (non-goals):**
- Rewording the `refine-issue` description — semantics must stay identical (DEFINE AT-3).
- Editing `night-shift/SKILL.md` — read-only style reference only (DEFINE AT-4).
- `plugin/.claude-plugin/plugin.json` version bump — the composer's job, after build (DEFINE).
- Promoting the new CI job to `required_status_checks` — a separate `/harden-repo` follow-up, not
  this fix (see Decision 3 — touching that live setting is a distinct, higher-blast-radius action).
- Any other skill's frontmatter, any other workflow file, any git commit/push/gh write.

## Root cause — re-confirmed empirically, not just by inspection

Reproduced in a scratch copy of `plugin/` (never the real working tree) with the real `claude` CLI
(v2.1.207, native install, already present in this environment) and PyYAML:

```text
$ claude plugin validate plugin/
Validating plugin manifest: <scratch>/plugin/.claude-plugin/plugin.json
Validating skill: <scratch>/plugin/skills/refine-issue/SKILL.md

✘ Found 1 error:
  ❯ frontmatter: YAML frontmatter failed to parse: YAML Parse error: Unexpected token. At runtime
    this skill loads with empty metadata (all frontmatter fields silently dropped).
✘ Validation failed
$ echo $?
1
```

```text
$ python3 -c "import yaml; yaml.safe_load(open(frontmatter_block).read())"
yaml.scanner.ScannerError: mapping values are not allowed here
  in "<unicode string>", line 2, column 118:
     ... ub issue up to `readiness:ready`: grounds it against the repo, a ...
                                         ^
```

Both point at the identical mid-string `` `readiness:ready`: `` — the colon-space right after the
closing backtick reads as a YAML mapping-key separator inside what's meant to be one plain scalar.
This confirms DEFINE's diagnosis mechanically, and sharpens one detail: it isn't only the Claude
Code validator that rejects this — a second, independent, widely-used YAML implementation
(PyYAML) rejects it too, for the same reason, but with a **hard parse error**, not a silent field
drop. DEFINE's "lenient loaders silently drop all frontmatter fields" claim is confirmed
separately, by the *Claude Code runtime's own* loader (per the validator's own error text quoted
above) — two different consumers, two different failure modes, one root cause.

---

## (a) `plugin/skills/refine-issue/SKILL.md` — the frontmatter fix

**Before** (current file, lines 1–4, verbatim):

```yaml
---
name: refine-issue
description: Refines a `readiness:draft` or bounced `readiness:needs-refinement` GitHub issue up to `readiness:ready`: grounds it against the repo, applies the Definition-of-Ready rubric, resolves the gaps the codebase can answer itself, asks the human only for genuine intent gaps, rewrites it self-contained, and flips the label — auto, within blast-radius bounds. The human-side mirror of `/pickup`'s autonomy gate. Use when the user wants to refine, ready, grade, or flesh out a draft issue, DoR-check it, or prepare the board's drafts for autonomous pickup. Authoring a brand-new issue is create-issue; executing a ready one is /pickup.
---
```

**After** (replace those 4 lines with):

```yaml
---
name: refine-issue
description: >-
  Refines a `readiness:draft` or bounced `readiness:needs-refinement` GitHub issue up to
  `readiness:ready`: grounds it against the repo, applies the Definition-of-Ready rubric,
  resolves the gaps the codebase can answer itself, asks the human only for genuine intent gaps,
  rewrites it self-contained, and flips the label — auto, within blast-radius bounds. The
  human-side mirror of `/pickup`'s autonomy gate. Use when the user wants to refine, ready,
  grade, or flesh out a draft issue, DoR-check it, or prepare the board's drafts for autonomous
  pickup. Authoring a brand-new issue is create-issue; executing a ready one is /pickup.
---
```

Nothing below line 4 (the rest of the skill body) changes. `plugin/skills/night-shift/SKILL.md` is
**not edited** — read only, as the style reference (its own `description: >-` block, lines 3–15,
is what fixes the wrap width and 2-space continuation-indent convention above: measured at
90–98 cols including indent; the fix above wraps at 88–96, inside that band — see Decision 2).

**Verification performed at design time** (scratch copy of `plugin/`, outside the working tree):
1. Applied the exact After block above to the scratch copy only.
2. `claude plugin validate plugin/` on the scratch copy → `✔ Validation passed`, exit `0`.
3. `python3` + `yaml.safe_load` on the fixed frontmatter block → `name == 'refine-issue'`,
   `description` non-empty.
4. Direct string equality: the parsed `description` from the fixed block equals the original plain-
   scalar value **byte-for-byte** (`True`) — confirming the `>-` fold reconstructs the exact
   original text (every inserted line break lands on a pre-existing space in the original, which
   YAML folding replaces with exactly one space on parse — no wording, spacing, or punctuation
   changed).

This directly satisfies DEFINE's AT-1, AT-2, and AT-3 for Part A; the build phase's own smoke gate
should re-run the same three checks against the real file as its executed proof (this design's run
was against a disposable copy, not the deliverable).

---

## (b) CI gate — new `plugin-validate` job in `.github/workflows/bump-gate.yml`

### What's already there (read before designing, per instruction)

Three workflows exist today, none of which install any CLI tool or touch Node/npm:

| File | Trigger | Purpose |
|------|---------|---------|
| `bump-gate.yml` | `pull_request` → `main` | version-bump enforcement, scoped to `plugin/` changes via `bump.sh --check`'s own `git diff -- plugin/` |
| `closing-keyword-gate.yml` | `pull_request` → `main` | requires an issue-closing keyword or opt-out marker in the PR body |
| `release.yml` | `push` → `main` (post-merge) | tags + cuts a GitHub Release when the version changed |

### Research grounding (time-sensitive facts, checked live — not assumed)

- **`npm install -g @anthropic-ai/claude-code`** — the exact command named in the issue. As of
  Claude Code v2.1.15 (2026-01-21), Anthropic deprecated this install path in favor of a native
  installer (`curl -fsSL https://claude.ai/install.sh | bash`) or Homebrew. Evidence found: the CLI
  now prints a deprecation notice on npm-installed runs, but the install itself is still reported
  functional as of the most recent evidence found — not yet a hard removal. It is, however, no
  longer the *recommended* path, and its long-term reliability is explicitly flagged as degrading
  by upstream reports. This matters for a CI step that will be re-run on every plugin-touching PR
  indefinitely — see Decision 4.
- **`claude plugin validate <dir>`** is a documented, real subcommand (local/static: manifest
  required fields, semver, UTF-8, per-skill frontmatter) — confirmed both via docs and by directly
  running it (see (a)'s verification). No evidence it calls the model or needs network access
  beyond the install step itself.
- **Interactive-auth risk** (the specific infeasibility DEFINE names): the `claude` CLI runs a
  one-time interactive onboarding wizard (theme picker, API-key confirmation) on first launch,
  which would hang a non-interactive job. GitHub Actions runners set `CI=true` by default, and that
  variable is documented to suppress this wizard's prompts — so no interactive-auth block is
  expected for a fresh CI install, and no `ANTHROPIC_API_KEY` should be required for a purely local
  validation subcommand. This is **not yet proven** (no live Actions run has exercised it) — it is
  this design's best-grounded expectation, and Decision 4 below defines exactly what would falsify
  it.
- **No `ANTHROPIC_API_KEY` (or equivalent) secret is referenced anywhere in this repo's three
  existing workflows today.** If `claude plugin validate` turns out to need one, this repo has none
  provisioned — provisioning a new repo secret is outside a code PR's blast radius (needs a human
  with repo-admin access), which makes it a clean, concrete infeasibility signal rather than
  something the build phase could paper over.
- **Host runner:** `ubuntu-latest` GitHub-hosted runners ship Node.js preinstalled, but this design
  still pins Node explicitly via `actions/setup-node` for determinism (current major, `v6`, per
  live check — this repo has no prior `setup-node` usage to match, unlike `actions/checkout@v4`,
  which this design keeps matching for consistency with the two sibling jobs already in this file —
  see Decision 5). `npm install -g` needs no `sudo` on GitHub-hosted Ubuntu runners (standard,
  well-established behavior — the runner user owns the default global-install prefix).

### Flow

```text
PR opened/updated → main   (bump-gate.yml, on: pull_request — unchanged trigger)
   │
   ├── job: bump-gate            [UNCHANGED — id, steps, behavior all untouched; see Decision 3]
   │
   └── job: plugin-validate      [NEW — this design, runs independently/in parallel]
          │
          ├─ checkout (fetch-depth 0) + git diff vs origin/main -- plugin/
          │     no plugin/ change → later steps skipped, job passes (no-op)
          │     plugin/ changed   → continue
          │
          ├─ setup-node (lts/*) → npm install -g @anthropic-ai/claude-code      [Try 1]
          │     install fails → swap in the native installer step               [Try 2]
          │     both fail, or an auth/interactive block appears                 [infeasible → drop]
          │
          └─ claude plugin validate plugin/        (CI=1)
                exit 0  → job passes
                exit ≠0 → job fails (a real validation regression, or an infra problem — see below)
```

### Sketch — Try 1 (as literally specified in the issue)

Appended as a new, sibling job under the existing `jobs:` key — nothing above `jobs:` changes, and
the existing `bump-gate:` job block is untouched. Inherits the workflow-level `permissions:
contents: read` already declared in this file (sufficient — read-only checkout, no write needed).

```yaml
  plugin-validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0          # need full history to diff against origin/main (mirrors bump-gate)
      - name: Skip when plugin/ is untouched
        id: filter
        run: |
          git fetch -q origin "main:refs/remotes/origin/main" 2>/dev/null || git fetch -q origin main
          if git diff --quiet origin/main -- plugin/; then
            echo "changed=false" >> "$GITHUB_OUTPUT"
            echo "::notice::No plugin/ change vs main — skipping Claude Code plugin validation."
          else
            echo "changed=true" >> "$GITHUB_OUTPUT"
          fi
      - uses: actions/setup-node@v6
        if: steps.filter.outputs.changed == 'true'
        with:
          node-version: 'lts/*'
      - name: Install Claude Code CLI
        if: steps.filter.outputs.changed == 'true'
        run: npm install -g @anthropic-ai/claude-code
      - name: claude plugin validate plugin/
        if: steps.filter.outputs.changed == 'true'
        env:
          CI: "1"   # GitHub Actions already sets CI=true; asserted explicitly so the CLI's
                    # first-run onboarding wizard (theme picker, API-key prompt) never blocks
                    # on a prompt in a non-interactive runner.
        run: claude plugin validate plugin/
```

### Sketch — Try 2 (fallback, only if Try 1's *install* step fails)

Swap only the install step; everything else above is unchanged (drop the `setup-node` step too —
the native installer needs no Node/npm):

```yaml
      - name: Install Claude Code CLI (native installer — npm fallback)
        if: steps.filter.outputs.changed == 'true'
        run: |
          curl -fsSL https://claude.ai/install.sh | bash
          echo "$HOME/.local/bin" >> "$GITHUB_PATH"
```

### Bounded-attempt plan (mechanical, per the issue's "~2 honest tries")

| Attempt | Action | If it fails |
|---------|--------|-------------|
| **Try 1** | Node (`setup-node`) → `npm install -g @anthropic-ai/claude-code` → `claude plugin validate plugin/` (`CI=1`) | Install itself fails (network/registry/deprecation-removal) → go to Try 2. `claude plugin validate` runs but errors/hangs on an auth or interactive-login prompt → **skip Try 2** (a different installer won't fix an auth requirement) and go straight to Drop. |
| **Try 2** | Replace the install step with the native installer (`curl install.sh`); same validate step | Still fails to install or run non-interactively → Drop. |
| **Drop** (explicit infeasibility) | Remove the `plugin-validate` job from the PR; ship Part A alone. State this explicitly in the PR body **and** post a follow-up comment on #75 with the concrete reason (which attempt, what error) — per DEFINE AT-6. | — |

One property worth naming: because Part A's fix ships in the same PR whenever Part B is also
attempted, `plugin-validate`'s first-ever real run **validates the very fix this PR makes** — a
passing check on this PR is simultaneously the CI gate working *and* live proof the frontmatter bug
is fixed, satisfying DEFINE's AT-5 in one motion.

Recommended before touching the workflow file at all: smoke-test the exact `npm install -g
@anthropic-ai/claude-code && claude plugin validate plugin/` sequence somewhere disposable with
network egress (a scratch container, or the build sandbox itself) to catch an install-level failure
in seconds rather than burning a full Actions run on it — the CI-specific unknowns (onboarding-
wizard behavior under GitHub's `CI=true`, runner-image quirks) are the only parts that genuinely
need a live Actions run to confirm.

---

## Key Decisions

**1. Block-scalar style — `>-` (folded), not `|-` (literal).** The issue and DEFINE both name `>-`
explicitly, matching `night-shift`; `fable5-prompting` uses `|-` elsewhere in this same repo, so
both styles coexist by design, chosen per-field. `refine-issue`'s description is one continuous
sentence-flow paragraph with no meaningful internal line breaks, which is exactly what folding
(`>-`) is for — it space-joins wrapped lines back into one paragraph, which is what reproduces the
original text exactly (verified in (a)). `|-` would preserve line breaks literally, which is the
wrong tool for a value that has none in the source.

**2. Line-wrap width — target ≤96 cols including the 2-space indent.** `night-shift`'s own `>-`
block (measured directly) wraps at 90–98 cols across 11 lines. This fix wraps at 88–96 cols across
7 lines (`textwrap.fill(width=96)` on the original 628-char string). There's no byte-exact rule to
match — night-shift's own line lengths vary by ±8 cols depending on word boundaries — so "inside the
same band" is the right bar, not an exact column count, and this fix sits inside it.

**3. CI gate host — a new job in the existing `bump-gate.yml`, not a new workflow file, not
`closing-keyword-gate.yml` or `release.yml`.** The task instruction requires "a job/step in an
existing workflow," ruling out a new file. Of the three existing files: `release.yml` triggers on
`push` to `main` only (post-merge — too late to gate the PR itself, and wrong permission scope,
`contents: write`, for a read-only check); `closing-keyword-gate.yml` has no thematic tie (issue-
closing keywords, unrelated to plugin content); `bump-gate.yml` is already, conceptually, "the
plugin/-change PR gate" (`bump.sh --check` already scopes itself to `git diff -- plugin/`). **Safety
constraint driving this, not just taste:** `.claude/sdd/features/DESIGN_ISSUE_36_REPO_HARDENING.md`
records an *executed* `/harden-repo --apply` run against this exact repo (timestamped
2026-07-04T18:03Z) that set `branches/main/protection.required_status_checks.contexts` to
`["bump-gate","closing-keyword-gate"]` — i.e., the job-id strings `bump-gate` and
`closing-keyword-gate` are very likely **live required status checks on `main` right now**. GitHub
Actions required-status-check "contexts" key off the job id (or its `name:`, if set) — not the
workflow file name. Renaming or restructuring either existing job would leave every future PR stuck
("Expected — Waiting for status to be reported"). This design **only adds** a new, independently-
named job (`plugin-validate`) and touches **zero** lines of the existing `bump-gate:` job block —
additive, not a rename, so nothing live breaks. Trade-off accepted: the workflow-level `name:
bump-gate` at the top of the file now describes a file hosting two differently-themed jobs; a
follow-up rename of the file itself (e.g. to `plugin-gates.yml`) would be a nicer long-term shape
but is out of scope for this narrowly-bounded fix and isn't required (the id, not the filename or
the top-level `name:`, is what required-checks binds to).

**4. Auth/infeasibility trigger — defined concretely, not left to judgment under pressure.** DEFINE
explicitly anticipates "requires interactive auth that can't run in CI" as a valid reason to drop
Part B. This design makes that condition mechanical: (a) GitHub Actions sets `CI=true` by default,
documented to suppress the CLI's onboarding wizard, so Try 1 is expected to run non-interactively
without any new secret; (b) this repo has **zero** `ANTHROPIC_API_KEY`-style secrets referenced in
any existing workflow today, so if `claude plugin validate` unexpectedly needs one, there is nothing
to point it at without a separate, out-of-band repo-admin action; (c) an auth/interactive failure is
explicitly carved out of the Try-2 fallback (switching installers doesn't fix an auth requirement —
burning the second try on it would be exactly the "thrash trying to force it" DEFINE says not to
do). This turns a vague "if it doesn't work" into a checklist the build phase can execute without
guessing.

**5. Action-version pins — match existing repo convention where one exists, use current major where
none does.** `actions/checkout@v4` is kept, matching its 3x-consistent existing use in this file and
its siblings (even though a newer major exists upstream) — this fix's job is proportionate, not a
version-pin audit across unrelated jobs. `actions/setup-node` has no prior usage anywhere in this
repo to match, so this design pins its current major (`v6`, confirmed live) rather than deliberately
picking something stale for a brand-new introduction. `node-version: 'lts/*'` is used instead of a
hardcoded number specifically to avoid this design going stale the next time Node's LTS rolls over
(Node 20 is already being phased out upstream as of this research) — self-updating, zero-maintenance
choice.

**6. Path-scoping at the step level, not the workflow trigger.** GitHub Actions has no per-job
`on:` — a workflow-level `paths: [plugin/**]` filter would also silently gate the pre-existing
`bump-gate` job, which is not this fix's call to make. Instead, an early step mirrors `bump.sh`'s
own `git diff -- plugin/` idiom and gates only the new job's later, non-free steps (`if:` on
`steps.filter.outputs.changed`). Unlike its sibling job — whose own script-level short-circuit is
nearly free (git diff + a `python3` read) — an `npm install` + CLI download is real cost on every
PR; skipping it on non-plugin PRs (e.g. a README-only change) avoids wasting that cost for zero
value, without touching the trigger the `bump-gate` job also depends on.

**7. No `required_status_checks` promotion in this change.** Adding `plugin-validate` to branch
protection's required contexts is a separate, higher-blast-radius action (touches live repo
settings, not code) — consistent with this repo's own established pattern (`DESIGN_ISSUE_36`: "the
tool only *requires* `bump-gate`/`closing-keyword-gate` as status checks — it never authors them").
The new job runs and reports on every plugin-touching PR from the moment it merges; whether to make
it *required* is a deliberate, separate `/harden-repo --apply` decision, left for later.

---

## File Manifest

| # | File | Action | Purpose |
|---|------|--------|---------|
| 1 | `plugin/skills/refine-issue/SKILL.md` | Modify | `description:` plain scalar → `>-` block scalar (see (a)). **Required.** |
| 2 | `.github/workflows/bump-gate.yml` | Modify | New `plugin-validate` job (see (b)). **Attempted** — the build phase may drop this cleanly per the bounded-attempt plan; if dropped, this row does not ship and row 1 ships alone. |

**Explicitly NOT in this manifest:** `plugin/skills/night-shift/SKILL.md` (read-only style
reference — AT-4 requires it stay unchanged); `plugin/skills/fable5-prompting/SKILL.md` (mentioned
only as a second precedent for `|-`, not touched); `plugin/.claude-plugin/plugin.json` (composer's
version-bump step, after build, per DEFINE); `.github/workflows/closing-keyword-gate.yml` and
`.github/workflows/release.yml` (untouched); branch-protection `required_status_checks` (Decision 7
— a separate follow-up, not this change).

---

## Acceptance-test mapping & verification plan

| AT | DEFINE text (summarized) | How this design satisfies it | Verification |
|----|---------------------------|-------------------------------|---------------|
| **AT-1** | `claude plugin validate plugin/` exits 0 (currently exits 1, one error, `refine-issue`). | (a)'s Before/After fix. | **Executed at design time** against a scratch copy (never the working tree): baseline reproduced exit 1 / "Found 1 error" naming `refine-issue`; after applying the exact After block, re-run showed `✔ Validation passed`, exit 0. Build phase repeats this for real, against the actual file, as its own smoke evidence. |
| **AT-2** | `python3` + `yaml.safe_load` on the fixed frontmatter succeeds, non-empty `name`/`description`. | (a)'s `>-` block scalar. | **Executed at design time** — `yaml.safe_load` on the fixed block returns `name == 'refine-issue'`, non-empty `description`. (Baseline also directly reproduced: PyYAML raises `ScannerError: mapping values are not allowed here` on the *current* frontmatter — mechanical confirmation of DEFINE's root cause, not just inspection.) |
| **AT-3** | Parsed `description` is semantically identical to the original — encoding-only change. | The `>-` fold reconstructs the original paragraph exactly (Decision 1). | **Executed at design time** — direct Python string equality, parsed `description` from the fixed block vs. the original plain-scalar value → `True`, byte-for-byte. |
| **AT-4** | `night-shift/SKILL.md` unchanged (style reference only). | Never edited — only `Read` was used against it in this design; the File Manifest excludes it. | `git diff` on that file after build should be empty. |
| **AT-5** | *(if CI scope attempted and succeeds)* the new/edited workflow runs `claude plugin validate plugin/`, the PR's own run passes. | (b)'s `plugin-validate` job, triggered on the same `pull_request` event as its sibling job (Decision 3/6). | **Not executable at design time** — needs a live Actions run; that's the build/composer phase's smoke gate. Design-time confidence: the exact command (`claude plugin validate plugin/`, no flags) was already verified to work correctly against a real local install of the CLI (see (a)), confirming syntax and expected output shape. |
| **AT-6** | *(if CI scope dropped)* PR body + a comment on #75 explicitly say so, with the reason. | The Bounded-attempt plan's explicit Drop row names exactly when and what to state. | Build/composer phase's responsibility — PR body text and a `gh issue comment` on #75, using the concrete failure this design's Try 1 / Try 2 distinction will have already surfaced. |

---

## Constraints honored (self-check)

- No wording change to `refine-issue`'s description — verified byte-identical via round-trip, not
  just eyeballed. ✓
- `night-shift/SKILL.md` not touched — `Read` only, never `Write`/`Edit`, during this design. ✓
- No other skill's frontmatter touched. ✓
- No `plugin/.claude-plugin/plugin.json` version bump — composer's job, per DEFINE. ✓
- No git commit, no git push, no `gh` write — only this design artifact was written to the working
  tree; all validator/PyYAML runs happened against a disposable scratch copy outside the repo. ✓
- No code applied to the real repo — (a) and (b) are Before/After text and a YAML sketch for the
  build phase to apply, not applied here. ✓
- The CI gate design is explicitly bounded and droppable, with a concrete, evidence-based
  infeasibility trigger (Decision 4) — never assumed to "just work." ✓
- `required_status_checks` promotion explicitly out of scope (Decision 7). ✓
- File manifest is exactly the (up to) two files this task named, no more, no less. ✓

---

## Next Step

**Ready for:** build phase. Apply (a) verbatim to `plugin/skills/refine-issue/SKILL.md` first —
already round-trip-verified, low risk, ships regardless of Part B's outcome. Then attempt (b) in
`.github/workflows/bump-gate.yml` per the bounded 2-try plan; on genuine infeasibility, drop it
cleanly (remove the job, don't leave a half-wired step) and ship (a) alone, documenting why per
AT-6. Either way, the build phase's own `BUILD_REPORT_ISSUE_75_REFINE_ISSUE_FRONTMATTER.md` must
cite `Future-Gadgets-AI/agentic-dev#75` as its requirements source — the same issue cited at the
top of this file, and the same rule this design itself follows: the gitignored, fresh-clone-
invisible generated input this run started from is never the citation target.
