# BUILD REPORT: ISSUE_36_REPO_HARDENING

> Implementation report for issue #36 — "Harden a new repo to the team standard."

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | ISSUE_36_REPO_HARDENING |
| **Date** | 2026-07-04 |
| **Author** | build phase (headless build agent) |
| **DESIGN** | [`../features/DESIGN_ISSUE_36_REPO_HARDENING.md`](../features/DESIGN_ISSUE_36_REPO_HARDENING.md) |
| **Branch** | `feat/repo-hardening` |
| **Status** | **Complete** |

---

## Summary

| Metric | Value |
|--------|-------|
| **Manifest execution** | 7/7 files (5 created, 2 modified) |
| **Lines added** | 958 (new files) + 2 (doc rows) |
| **GitHub writes performed** | 0 (hard constraint — no `gh` mutation, no network call, of any kind) |
| **Git commits / version bump** | 0 (composer's step, per DEFINE and the build brief) |
| **Agents used** | 0 (direct — no specialist sub-agent matched or needed; the design itself assigns no `@agent-name`) |

---

## Files touched

| # | File | Action | Summary |
|---|------|--------|---------|
| 1 | `plugin/contracts/repo-standard.md` | Create | The codified contract (158 lines): 5 fenced JSON/data blocks under stable literal H3-style `##` headings — protection managed-fields target + observed snapshot, ruleset target + observed snapshot, 18-entry label manifest — plus prose sections for CODEOWNERS format and the bot-wiring pointer. Verified byte-parseable by Pattern 1's exact regex (see Verification Results). |
| 2 | `plugin/scripts/repo-standard-diff.sh` | Create | Phase A (419 lines): bash arg-parsing/dependency-guard/credential-extraction shell, delegating the substantive read+merge+diff computation to one embedded `python3` heredoc (Patterns 1 & 2, extended with ruleset/labels/CODEOWNERS/history/bot-wiring logic). Zero write verbs anywhere — grepped and confirmed. Never sources `bot-auth.sh`. Writes `plan.json` + `protection-put-body.json` + (conditionally) `ruleset-post-body.json` to the deterministic tmp dir, and renders a human-readable report to stdout. |
| 3 | `plugin/scripts/repo-standard-apply-labels.sh` | Create | Phase B (83 lines): parses the label manifest via Pattern 1, then bulk-creates only labels absent from an **exact-match** (`grep -qxF`) check against a generously-paged `gh label list`. Self-sources `bot-auth.sh`; refuses without `--confirmed`. |
| 4 | `plugin/scripts/repo-standard-apply-codeowners.sh` | Create | Phase A2 (112 lines): writes `.github/CODEOWNERS` — direct Contents-API commit on a genuinely empty repo, or a deterministic-branch + draft PR (pure Git Data API + Contents API, no local clone) on a repo with history, reusing an already-open PR when found. Self-sources `bot-auth.sh`; calls the existing `request-reviewers.sh` after opening a PR. |
| 5 | `plugin/commands/harden-repo.md` | Create | `/harden-repo` entrypoint (186 lines): argument parsing, Phase A invocation + verbatim presentation, A2/B/Bot-wiring/C sequencing, the two `AskUserQuestion` confirmation gates as instructions to the executing agent, the inline (never-scripted) protection/ruleset apply block with the pre-flight identity assertion and `# agentic:allow-ambient` on every write line, and the final per-sub-step report table. |
| 6 | `plugin/contracts/README.md` | Modify | Added one row to the Files table for `repo-standard.md`, matching the existing convention (every contract file listed there). No other section touched. |
| 7 | `README.md` | Modify | Added one row to the top-level Commands table for `/agentic-dev:harden-repo <owner/repo>`, matching the existing `/pickup`/`/recommend`/`/needs-me` row shape. No other section touched. |

---

## Verification Results

No unit-test harness exists for `plugin/scripts/*.sh` or `plugin/commands/*.md` in this repo (confirmed: no `tests/`, no `.bats`, no shellcheck CI job — matching the three pre-existing scripts' own precedent). Per the hard constraint, **no network call of any kind was made** during this build (no `gh` invocation — not even read-only). Verification below is entirely static/structural; the composer's own smoke gate performs the real, live runs against `gear` (AT-1) and `agentic-dev` (AT-2/AT-3).

### Syntax

| Check | Target | Result |
|---|---|---|
| `bash -n` | `repo-standard-diff.sh` | Pass |
| `bash -n` | `repo-standard-apply-labels.sh` | Pass |
| `bash -n` | `repo-standard-apply-codeowners.sh` | Pass |
| `python3 -m py_compile` | embedded heredoc in `repo-standard-diff.sh` | Pass |
| `python3 -m py_compile` | embedded heredoc in `repo-standard-apply-labels.sh` | Pass |
| Embedded bash blocks in `harden-repo.md` | all 4 fenced ` ```bash ` blocks (Phase A invocation, A2 invocation, identity assertion, inline apply block) | `bash -n` Pass on all 4 |
| Contract JSON blocks | all 5 fenced ` ```json ` blocks in `repo-standard.md` | Parsed with Pattern 1's literal regex — 3/3 machine-parsed blocks (`protection_target`, `ruleset_target`, 18-entry `label_manifest`) load correctly; both "observed" reference blocks also valid JSON |

### Dry-parse / fail-fast paths (network-free)

| Command | Expected | Observed |
|---|---|---|
| `repo-standard-diff.sh --help` | usage text, exit 0, no `gh` call | Pass |
| `repo-standard-diff.sh` (no args) | usage error, exit 1 | Pass |
| `repo-standard-apply-labels.sh` (no args) | usage error, exit 1 | Pass |
| `repo-standard-apply-labels.sh REPO` (missing `--confirmed`) | refusal message, exit 1, no `gh`/no `bot-auth.sh` reached | Pass |
| `repo-standard-apply-codeowners.sh` (no args) | usage error, exit 1 | Pass |

### Structural guarantees (grepped and confirmed)

- **Zero write verbs in `repo-standard-diff.sh`** — grepped for `-X`/`--method POST|PUT|PATCH|DELETE` and `gh (label|issue|pr|release) create|edit|delete|close|merge|comment`; the only hit is the header comment describing this guarantee, not code (D3 — AT-2's byte-identical-no-writes proof by construction).
- **`bot-auth.sh` sourced** in `repo-standard-apply-labels.sh` and `repo-standard-apply-codeowners.sh`; **never** sourced in `repo-standard-diff.sh` or `harden-repo.md`'s inline protection/ruleset block (D6, both directions confirmed by grep).
- **`# agentic:allow-ambient`** present on both write lines (PUT protection, POST ruleset) in `harden-repo.md`'s inline block.
- **No bare `jq` binary dependency** introduced anywhere in the three scripts — confirmed by grep (only `gh api --jq`, which is gh's own bundled filter, appears).
- **`grep -qxF` exact-match** confirmed present in `repo-standard-apply-labels.sh`'s existence check.
- **`setup-bot.sh` never invoked** — confirmed by grep: it appears only inside fix-suggestion strings in `repo-standard-diff.sh`'s `bot_wiring.fix` field and `harden-repo.md`'s Bot-wiring report block, never as an executed command.
- **plugin.json untouched** (`git diff plugin/.claude-plugin/plugin.json` empty) and **no commit created** (`git log` unchanged) — confirmed via `git status`/`git diff`/`git log` at the end of the build.

---

## Autonomous Decisions

| # | Decision Point | Options Considered | Chose | Rationale |
|---|----------------|--------------------|-------|-----------|
| 1 | The build brief's "usage CLI's jq check" precedent doesn't exist anywhere in this repo (grepped the whole tree — no hit) | Guess at an unknown file vs. approximate the intended style | Implemented a plain `command -v python3 \|\| { echo <clear message>; exit 1; }` guard, matching this codebase's own fail-fast idiom (`bot-auth.sh`'s "no bot credentials found... Fix: ..." style) | No literal precedent exists to copy; the instruction's intent (clear exit message on a missing interpreter) is satisfied by the existing house style instead |
| 2 | Scope of the python3-dependency guard | Only the two Pattern-1-parsing scripts (as the hard constraint's example implied) vs. all three scripts that shell out to python3 | All three — `repo-standard-apply-codeowners.sh` also needed the guard, since it uses `python3` for base64-decoding the current CODEOWNERS content (not Pattern 1 parsing, but the same failure mode) | Consistency: any script that silently fails with a cryptic error when python3 is absent is a worse experience than one extra guarded `command -v` check; cheap and safe |
| 3 | Design Pattern 3's label-existence check (`case "$existing" in *"$name"*)`) | Keep the substring `case` glob vs. tighten to exact-match | Tightened to `grep -qxF "$name" <<<"$existing"` (per the task's explicit instruction) | The substring form has a real collision smell — e.g. `priority:high` would false-positive-match a hypothetical existing `priority:highest` label, wrongly skipping a legitimate create |
| 4 | Design Pattern 4's `jq -r .url <<<"$existing_pr"` (a bare `jq` binary call) | Keep bare `jq` (not installed by default on macOS, no precedent anywhere else in this repo) vs. extract the URL via `gh`'s own bundled `--jq` at the point of the `gh pr list` call | Rewrote to `gh pr list ... --json url --jq '.[0].url // empty'`, dropping the second bare-`jq` call entirely | Avoids introducing an undeclared new binary dependency this repo has never required; `gh api`/`gh pr list --jq` already use gh's internal gojq, so no new tool is needed at all |
| 5 | CODEOWNERS content comparison: decode the Contents API's base64 `content` field | Shell out to `base64 -d` (GNU) or `base64 -D` (BSD) vs. decode in `python3` | `python3 -c 'import base64...'` | Sidesteps the BSD-vs-GNU flag incompatibility entirely (the hard constraint requires macOS/BSD compatibility); `python3` is already an unavoidable dependency of this script's sibling scripts, so this adds no new dependency |
| 6 | Design Pattern 4's "has history" branch (local `git clone` + `checkout -b` + `commit` + `push`) | Keep the local-clone dance vs. do it purely through `gh api` (Git Data API `git/refs` + Contents API `PUT ... branch=<new-branch>`) | Pure `gh api` — no local clone, no working directory, no trap-managed cleanup needed | Matches the same technique the empty-repo path (and the rest of this plugin) already uses; avoids a filesystem side effect and a network clone this script doesn't otherwise need; simpler and more auditable (every write is a visible `gh api` call) |
| 7 | CODEOWNERS target line when no reviewers resolve at all (no `--reviewers`, no `AGENTIC_REVIEWERS` in credentials) — a genuine DESIGN gap, not decided by DEFINE/DESIGN | Write `* ` (empty rule, matches nobody) vs. a new `codeowners.status = "blocked_no_reviewers"` outcome that refuses to write | Added `blocked_no_reviewers` as a distinct status; `harden-repo.md` reports it and skips CODEOWNERS rather than writing a broken rule | Never write a CODEOWNERS line that satisfies nobody — the safest documented default when the DESIGN didn't anticipate this input combination |
| 8 | Distinguishing "branch `main` doesn't exist" from "branch `main` exists but is unprotected" (both 404 on `GET .../protection`) — needed for Decision D7's `main_branch_exists` plan field | Infer from the protection GET's 404 alone vs. a separate `GET repos/{repo}/branches/main` existence probe | Added the separate probe | The protection-GET 404 is genuinely ambiguous between the two cases; a dedicated existence check is the only reliable signal, and D7/Phase C's re-probe instruction requires this exact distinction anyway |
| 9 | Label-list pagination for the exact-match existence check | `gh api --paginate` (multi-document stdout shape varies by gh version/flags) vs. an explicit high `per_page` | `repos/{repo}/labels?per_page=100` (diff script) and `gh label list --limit 300` (apply script), with a WARN on a full page | Matches `needs-me.sh`'s own established, working precedent (`LIMIT=100`, explicit, loudly-warned-if-capped) instead of depending on `--paginate`'s multi-document output format, which this repo has never used and isn't guaranteed to parse simply |
| 10 | `set -e` vs. no `set -e` for the three new scripts | `set -euo pipefail` (bump.sh/setup-bot.sh's shape) vs. `set -uo pipefail` (needs-me.sh/request-reviewers.sh's shape) | `set -uo pipefail` for all three | These scripts' role (cross-call reads/writes against a target repo, explicit `\|\| exit 1` at every critical step) matches `needs-me.sh`/`request-reviewers.sh` far more closely than `bump.sh`/`setup-bot.sh`'s one-time single-file-mutation shape |
| 11 | Placeholder repo in `harden-repo.md`'s inline apply block | Keep the design's worked example literal (`Future-Gadgets-AI/gear`) vs. genericize to `<owner/repo>` | Genericized, plus added a symmetric `# only if protection status != "match"` comment above the PUT line (the design only commented the POST/ruleset line) | The command file is repo-agnostic by construction (DESIGN never parameterizes this beyond the one CLI arg); the added comment states the same skip-if-matching guarantee the Idempotency table already claims for the PUT, for symmetry with the POST line's existing comment |
| 12 | Tie-break when more than one existing ruleset targets `branch` + a `"creation"` rule (not specified by DESIGN) | Compare all and report the worst status vs. take the first match found | First match found (list order from `gh api repos/{repo}/rulesets`) | DESIGN doesn't anticipate multiple competing rulesets; taking the first is the smallest-scope, most conservative reading — a genuine multi-ruleset conflict is a pre-existing repo anomaly outside this tool's remit either way |

---

## Acceptance-test mapping (AT-1..AT-6 — what the code guarantees; live verification is the composer's smoke gate)

| AT | Design's guarantee | What this build's code provides |
|---|---|---|
| AT-1 | apply + idempotency | `repo-standard-diff.sh`'s protection merge only marks a write needed when `normalize(merged) != normalize(current)`; `repo-standard-apply-labels.sh` only creates names absent from an exact-match check; `repo-standard-apply-codeowners.sh` no-ops when current content already equals target and reuses an already-open PR from the fixed branch name `chore/codeowners-hardening`; the ruleset is only POSTed when no existing ruleset already targets branch creation. All four are naturally idempotent by construction — re-running `--apply` twice should show the second run's `plan.json` fully `MATCH`, 0 writes. |
| AT-2 | verify mode is read-only | `repo-standard-diff.sh` contains zero write verbs (grepped, confirmed above); the diff script is the entirety of verify mode, so this is true by construction, not convention. |
| AT-3 | required-check promotion is per-repo | `workflow_file_exists()` probes `.github/workflows/<context>.yml` on the target's default branch per context; only detected contexts are unioned into the merge; nothing is set on a repo with neither workflow file present. |
| AT-4 | label-rollout safety | `harden-repo.md` presents exactly one `AskUserQuestion` confirmation for the whole batch; `repo-standard-apply-labels.sh` re-checks `gh label list` (paged to 300) with an exact-match, so a hand-edited existing label is never touched, only genuinely-missing names are created. |
| AT-5 | identity boundary (both directions) | Labels/CODEOWNERS: `source "$HERE/bot-auth.sh" \|\| exit 1` (fail-fast, structural) in both apply scripts. Protection/ruleset: `repo-standard-diff.sh` and `harden-repo.md`'s inline block never source `bot-auth.sh`; the command's pre-flight block asserts current `gh` identity != configured bot login before building any payload; every write line in the inline block carries `# agentic:allow-ambient` so `enforce-bot-identity.py` can see and deliberately allow it. |
| AT-6 | bot-wiring delegation | `bot_wiring` in `plan.json` is computed once (a scoped, never-exported, never-printed one-off `GH_TOKEN=<bot pat>` push probe) and read verbatim by `harden-repo.md`'s report — no script anywhere calls `setup-bot.sh` or writes to `~/.config/agentic-dev` (confirmed by grep: the string appears only in suggestion text). |

---

## Blockers

None. No CRITICAL risk was encountered; all 7 manifest files were completed.

---

## Deferred (explicitly out of this build, per DEFINE/DESIGN and the build brief)

- **Live smoke runs** against `Future-Gadgets-AI/gear` (AT-1) and `Future-Gadgets-AI/agentic-dev` (AT-2/AT-3) — the composer's own verify/smoke gate, since this build made no network calls at all.
- **Plugin version bump** (`plugin/.claude-plugin/plugin.json`) — the composer's step (ADR-0006), confirmed untouched.
- **Git commit** — the composer commits after this build; the working tree is left with the 7 file changes only.
- Everything DEFINE itself scoped out and DESIGN honored as-is: repo creation, authoring/editing CI workflows, a Projects board, any per-repo override beyond target repo + reviewer list.

---

## Final Status

### Overall: COMPLETE

**Completion Checklist:**
- [x] All 7 manifest files created/modified exactly as specified
- [x] Every Key Decision (D1–D10) honored in the shipped code
- [x] Contract outline headings verified load-bearing (parsed by Pattern 1's literal regex)
- [x] Per-sub-step identity/confirmation/reporting specs present in `harden-repo.md`
- [x] Error-handling table's cases each have a corresponding code path or explicit instruction
- [x] `bash -n` clean on all 3 scripts + all 4 embedded bash blocks in the command file
- [x] Zero GitHub writes, zero network calls, zero git commits, zero version bump during this build
- [x] No blocking issues
- [x] Ready for the composer's own verify/smoke gate and PR
