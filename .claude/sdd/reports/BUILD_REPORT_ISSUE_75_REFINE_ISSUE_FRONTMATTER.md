# BUILD REPORT: ISSUE_75_REFINE_ISSUE_FRONTMATTER

**Requirements source:** Future-Gadgets-AI/agentic-dev#75 — "[BUG] refine-issue SKILL.md frontmatter fails strict YAML parse (unquoted ': ' in description)"

**Design:** [`../features/DESIGN_ISSUE_75_REFINE_ISSUE_FRONTMATTER.md`](../features/DESIGN_ISSUE_75_REFINE_ISSUE_FRONTMATTER.md)
**Date:** 2026-07-12
**Branch:** `fix/refine-issue-frontmatter`
**Status:** ✅ **Complete** — Part A (required) and Part B (bounded attempt) both shipped. Part B's
local pre-flight cleared cleanly on Try 1 (npm install succeeded, `claude plugin validate` ran
non-interactively with no auth/interactive blocker under two separate environments — see
Verification §4), so the design's Try-2/Drop fallback paths were not needed.

> Headless build (Phase 3). Applied the design's (a) Before/After block verbatim to
> `plugin/skills/refine-issue/SKILL.md`, then executed the design's recommended local pre-flight
> before touching CI, then applied the design's (b) "Sketch — Try 1" YAML verbatim to
> `.github/workflows/bump-gate.yml` as an additive sibling job. No git commit, push, or `gh` write
> performed — all git/GitHub operations are the composer's job.

---

## Summary

| Metric | Value |
|--------|-------|
| **Manifest execution** | 2/2 files from the design's File Manifest (both modified, 0 created) |
| **Part A** | Shipped — frontmatter `description:` plain scalar → `>-` block scalar, verbatim per design |
| **Part B** | Shipped (not dropped) — new `plugin-validate` job added to `bump-gate.yml`, verbatim per design's Try 1 sketch |
| **Agents used** | 0 (direct — design's manifest specifies `(general)`/direct application for both files; no `@agent-name` delegation called for) |
| **Git commits / pushes / `gh` calls** | 0 |
| **Files touched** | 2 (`plugin/skills/refine-issue/SKILL.md`, `.github/workflows/bump-gate.yml`) |
| **Verification commands executed** | 12 (all captured below with real output and exit codes) |

---

## Files touched

| File | Action | Part |
|---|---|---|
| `plugin/skills/refine-issue/SKILL.md` | Modify — 4-line frontmatter → 9-line frontmatter (`description: >-` folded block scalar); nothing below the frontmatter changed | A (required) |
| `.github/workflows/bump-gate.yml` | Modify — new `plugin-validate:` job appended as a sibling under `jobs:`; existing `bump-gate:` job block untouched (purely additive diff, confirmed below) | B (attempted, shipped) |

`plugin/skills/night-shift/SKILL.md`, `plugin/.claude-plugin/plugin.json`,
`.github/workflows/closing-keyword-gate.yml`, and `.github/workflows/release.yml` were **not**
touched — confirmed empty diffs in Verification §4.

---

## Verification

All commands executed for real from the repo root of the build workspace (a fresh clone of this
repository, on this branch) unless noted otherwise. `claude` here is the native v2.1.207 install
already on `PATH`.

### 1. Baseline — `claude plugin validate plugin/` before any edit (re-confirms the design's root-cause repro against the real file, not a scratch copy)

```text
$ claude plugin validate plugin/
Validating plugin manifest: <repo>/plugin/.claude-plugin/plugin.json

Validating skill: <repo>/plugin/skills/refine-issue/SKILL.md

✘ Found 1 error:

  ❯ frontmatter: YAML frontmatter failed to parse: YAML Parse error: Unexpected token. At runtime
    this skill loads with empty metadata (all frontmatter fields silently dropped).

✘ Validation failed
$ echo $?
EXIT_CODE=1
```

Matches the design's AT-1 baseline exactly (1 error, `refine-issue`, exit 1).

### 2. Part A applied, then `claude plugin validate plugin/` again (AT-1)

```text
$ claude plugin validate plugin/
Validating plugin manifest: <repo>/plugin/.claude-plugin/plugin.json

✔ Validation passed
$ echo $?
EXIT_CODE=0
```

Re-run again after Part B also shipped (workflow YAML edits don't affect `plugin/` content) —
identical result, `✔ Validation passed`, exit 0.

### 3. `python3` + PyYAML round-trip (AT-2, AT-3)

PyYAML is not installed on the system Python (Homebrew-managed, PEP 668 externally-managed
environment); a disposable venv was created **inside the scratchpad** (not the repo, not a
system-wide install) solely to run this check — see Autonomous Decisions #3.

Baseline reproduction (mirrors the design's own root-cause repro, against the real original file
via `git show HEAD`, not a retyped copy):

```text
$ python3 -c "import yaml; yaml.safe_load(original_frontmatter_body)"
ScannerError - mapping values are not allowed here
```

Post-fix check — parses the fixed frontmatter, asserts `name`, non-empty `description`, and
byte-for-byte equality of the parsed `description` against the **original** value (pulled from
`git show HEAD:plugin/skills/refine-issue/SKILL.md`, i.e. the actual pre-fix committed content on
this branch — not retyped from the design doc, to eliminate any transcription risk on a 628-char
string):

```text
parsed name: 'refine-issue'
name == 'refine-issue': True
description non-empty: True
len(parsed description)      = 628
len(original description)    = 628
parsed description == original description (byte-for-byte): True

ALL_CHECKS_PASSED: True
$ echo $?
PYTHON_EXIT=0
```

### 4. `git diff --stat` and touched-file scope (AT-4 + hard boundaries)

```text
$ git diff --stat
 .github/workflows/bump-gate.yml     | 31 +++++++++++++++++++++++++++++++
 plugin/skills/refine-issue/SKILL.md |  9 ++++++++-
 2 files changed, 39 insertions(+), 1 deletion(-)

$ git diff plugin/skills/night-shift/SKILL.md
(empty — confirms untouched, AT-4)

$ git diff plugin/.claude-plugin/plugin.json
(empty — confirms no version bump, per hard boundary)

$ git diff .github/workflows/closing-keyword-gate.yml .github/workflows/release.yml
(empty — confirms untouched, per hard boundary)

$ git status --porcelain
 M .github/workflows/bump-gate.yml
 M plugin/skills/refine-issue/SKILL.md
?? .claude/sdd/features/DESIGN_ISSUE_75_REFINE_ISSUE_FRONTMATTER.md
```

(The untracked `DESIGN_ISSUE_75...md` is this run's own design input, pre-existing before the
build phase started — not created or moved by this build.)

`git diff .github/workflows/bump-gate.yml` confirms the existing `bump-gate:` job block is
byte-for-byte untouched — the diff is a pure append (no `-` lines) of the new `plugin-validate:`
job after the last line of the existing job:

```text
@@ -26,3 +26,34 @@ jobs:
             exit 0
           fi
           bash plugin/scripts/bump.sh --check
+
+  plugin-validate:
+    runs-on: ubuntu-latest
+    steps:
+      ...
```

### 5. Workflow YAML sanity check (task-required)

```text
$ python3 -c "import yaml; d = yaml.safe_load(open('.github/workflows/bump-gate.yml')); print('parsed OK'); print(list(d['jobs'].keys()))"
parsed OK
['bump-gate', 'plugin-validate']
```

### 6. npm pre-flight (per the design's "Recommended before touching the workflow file at all")

Run entirely in a disposable scratch directory (`npm-preflight/`) outside the repo — never the
repo, never a global `npm install -g` on this dev machine (which already has a native `claude`
install).

```text
$ node --version
v25.8.1
$ npm --version
11.11.0

$ npm install --prefix . @anthropic-ai/claude-code
added 2 packages in 11s
$ echo $?
NPM_INSTALL_EXIT=0

$ node_modules/.bin/claude --version
2.1.207 (Claude Code)
```

npm install succeeded — no fallback to Try 2 (native installer) needed.

**Validate subcommand, run 1** — same shell, `CI=1`, stdin closed:

```text
$ CI=1 node_modules/.bin/claude plugin validate <repo>/plugin/ < /dev/null
Validating plugin manifest: <repo>/plugin/.claude-plugin/plugin.json

✔ Validation passed
VALIDATE_EXIT=0
```

This machine already has a native, authenticated `claude` install, so a shared-config run like the
one above is weaker proof of Decision 4's "no interactive-auth block expected in CI" claim than a
truly fresh runner would be (see Autonomous Decision #2). **Validate subcommand, run 2** —
strengthened: fully isolated `$HOME` (`env -i`, freshly-created empty directory, no prior Claude
Code config of any kind), `CI=1`, stdin closed, capturing whether the first-run onboarding wizard
would block:

```text
$ env -i HOME=<fresh-empty-dir> PATH="$PATH" CI=1 node_modules/.bin/claude plugin validate <repo>/plugin/ < /dev/null
Validating plugin manifest: <repo>/plugin/.claude-plugin/plugin.json

✔ Validation passed
FRESH_HOME_VALIDATE_EXIT=0
```

No hang, no interactive prompt, no `ANTHROPIC_API_KEY` required. The CLI silently bootstrapped its
own first-run config under the isolated `$HOME` (evidence below) without blocking on the
onboarding wizard — empirically confirming the design's Decision 4 expectation (`CI=1` suppresses
it) rather than just trusting the documented claim:

```text
$ find <fresh-empty-dir> -maxdepth 3
<fresh-empty-dir>/.claude.json
<fresh-empty-dir>/.claude
<fresh-empty-dir>/.claude/backups
<fresh-empty-dir>/.claude/backups/.claude.json.backup.1783890403882
```

**Conclusion:** no auth/interactive blocker at any point → per the design's bounded-attempt plan,
Try 1 succeeds outright. Try 2 and the Drop row were not exercised.

---

## Autonomous Decisions

| # | Decision Point | Options Considered | Chose | Rationale |
|---|----------------|--------------------|-------|-----------|
| 1 | Part B go/no-go after pre-flight | Ship Try 1 verbatim / swap in Try 2 / Drop the job entirely | Shipped Try 1 verbatim | npm install succeeded (exit 0, 11s, no registry/network errors) and `claude plugin validate` completed non-interactively under **two** environments (shared config and fully isolated `$HOME`) with `CI=1` and stdin closed — no auth/interactive blocker surfaced. Per the design's own bounded-attempt table, this is exactly Try 1's success path; no fallback or drop condition was triggered |
| 2 | Pre-flight rigor beyond the literal instruction | Run only the single specified invocation (shared local config) / also test under an isolated, credential-free `$HOME` before deciding | Added a second, isolated-`$HOME` run (`env -i HOME=<fresh dir>`) | This dev machine already has a native, authenticated `claude` install; the literal one-shot invocation risked silently reusing that shared config, which would not actually test Decision 4's "no interactive-auth block expected in CI" claim the way a genuinely fresh GitHub Actions runner would. The task's own goal is "prove... its validate subcommand works non-interactively" — an isolated-`$HOME` run is materially stronger evidence of that than a shared-config run, at near-zero extra cost |
| 3 | PyYAML availability for the verification script | `pip install --user pyyaml` on system Python / `pip install --break-system-packages` / disposable venv | Created a scratch venv under the scratchpad, deleted after use | System Python (Homebrew 3.14) is a PEP 668 externally-managed environment; a scratch venv runs the required checks for real without mutating any machine-wide Python install or touching the repo. Cleaned up afterward to respect the "no files outside the working directory / npm-preflight dir" boundary (see below) |
| 4 | Ground truth for the AT-3 byte-equality baseline | Retype the 628-char original description from the design doc's quoted "Before" block / pull the exact original bytes via `git show HEAD:<path>` | Pulled from `git show HEAD` | Guarantees a byte-exact baseline with zero transcription risk on a long prose string containing em dashes, backticks, and curly punctuation. Confirmed HEAD's frontmatter on this branch is identical to the design's quoted Before block (same 4 lines) before relying on it |
| 5 | Scratch-file placement mid-build | Initially wrote a verification script, a venv, and a git-HEAD dump directly under the shared session scratchpad root (outside both the working directory and the npm-preflight dir named in this task's hard boundaries) | Caught and corrected: deleted all three once their output was captured, leaving only `runner-75/` (working dir) and `npm-preflight/` (explicitly permitted scratch dir) touched | The task's hard boundaries explicitly restrict file creation to those two locations; this is stricter than the general environment guidance to "use the scratchpad for temp files." Resolved in favor of the task-specific, more restrictive rule |

---

## Acceptance-test mapping (design's AT table)

| AT | DEFINE text (summarized) | Result | Evidence |
|----|---------------------------|--------|----------|
| **AT-1** | `claude plugin validate plugin/` exits 0 (baseline exits 1). | **PASS** | Verification §1 (baseline, exit 1, "Found 1 error" naming `refine-issue`) → §2 (post-fix, `✔ Validation passed`, exit 0), against the real file, not a scratch copy |
| **AT-2** | `python3` + `yaml.safe_load` on fixed frontmatter succeeds, non-empty `name`/`description`. | **PASS** | Verification §3 — `name == 'refine-issue'` True, `description` non-empty (628 chars); baseline `ScannerError` also reproduced against the real pre-fix content |
| **AT-3** | Parsed `description` semantically identical to the original (encoding-only change). | **PASS** | Verification §3 — direct string equality True, byte-for-byte, sourced from `git show HEAD` (not retyped) |
| **AT-4** | `night-shift/SKILL.md` unchanged. | **PASS** | Verification §4 — `git diff plugin/skills/night-shift/SKILL.md` empty |
| **AT-5** | *(if CI scope attempted and succeeds)* the new/edited workflow runs `claude plugin validate plugin/`, the PR's own run passes. | **Shipped, live-run confirmation pending** | The `plugin-validate` job was added verbatim per the design's Try 1 sketch (Verification §4/§5: purely additive diff, YAML parses, job present). The design itself scopes AT-5's live-Actions proof to "the build/composer phase's smoke gate" — a real Actions run only happens once the PR is opened and pushed, which is outside this build phase's hard boundary (no git push/`gh` writes here). Design-time + build-time confidence is high: the exact command was verified working, non-interactively, twice (§6), including under a fully isolated `$HOME`. **Composer/reviewer should treat the first live run on the PR itself as the final AT-5 confirmation**, exactly as the design anticipates |
| **AT-6** | *(if CI scope dropped)* PR body + a comment on #75 state so, with the reason. | **N/A** | Part B was not dropped — Try 1 succeeded cleanly, so there is no drop reason to surface in the PR body or as an issue comment |

---

## Status: ✅ COMPLETE
