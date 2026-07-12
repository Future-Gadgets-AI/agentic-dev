# BUILD REPORT: ISSUE_64_CONFIG_ENV_VAR_NAMING

**Source issue:** `Future-Gadgets-AI/agentic-dev#64` — "[TASK] Reconcile AGENTIC_DEV_CONFIG vs AGENTIC_DEV_CONFIG_DIR env-var naming across scripts"

**Design artifact used:** `.claude/sdd/features/DESIGN_ISSUE_64_CONFIG_ENV_VAR_NAMING.md`
**Date:** 2026-07-12
**Branch:** `fix/config-dir-env-var`
**Status:** Complete

> Headless build (Phase 3) applying the design's 6 precise Before/After edits across 5 files.
> Every reader of the bot-credentials config location now applies the same three-step
> precedence: canonical `AGENTIC_DEV_CONFIG_DIR` first, deprecated `AGENTIC_DEV_CONFIG`
> fallback (one-line stderr warning, own message prefix per file), else the existing default.

---

## Summary

| Metric | Value |
|--------|-------|
| **Manifest execution** | 6/6 edit sites, 5/5 files — exactly the design's manifest (0 files created, 0 deleted, 5 modified) |
| **Agents used** | 0 (direct — design assigns `(general)` execution everywhere; faithful transcription of exact Before/After blocks, no new logic authored) |
| **Git/gh commands run** | 0 writes (`git add`/`commit`/`push`, any `gh` call) — working tree left uncommitted for the composer, per hard constraint |
| **Autonomous decisions** | 0 — see below |
| **Syntax checks** | 4/4 pass (`bash -n` ×3, `zsh -n` ×1) |

---

## Files changed

`git diff --stat` output, run for real from the repo root on `fix/config-dir-env-var`:

```
 plugin/commands/harden-repo.md       | 18 ++++++++++++++++--
 plugin/scripts/bot-auth.sh           | 10 +++++++++-
 plugin/scripts/needs-me.sh           |  9 ++++++++-
 plugin/scripts/repo-standard-diff.sh |  9 ++++++++-
 plugin/skills/init/SKILL.md          |  1 +
 5 files changed, 42 insertions(+), 5 deletions(-)
```

`git status --short` (full working-tree scope, confirms nothing else touched):

```
 M plugin/commands/harden-repo.md
 M plugin/scripts/bot-auth.sh
 M plugin/scripts/needs-me.sh
 M plugin/scripts/repo-standard-diff.sh
 M plugin/skills/init/SKILL.md
?? .claude/sdd/features/DESIGN_ISSUE_64_CONFIG_ENV_VAR_NAMING.md
```

The one untracked entry (`DESIGN_ISSUE_64_CONFIG_ENV_VAR_NAMING.md`) was already present, untracked, before this build phase started (confirmed via the initial `git status` at session start) — it was not created or modified by this build. This BUILD_REPORT file itself is new and is not yet reflected in `git status` output above because it was written after that command ran; it is untracked by design (the composer stages/commits).

---

## Per-edit-site confirmation

| # | File | Region | Landed | Matches design |
|---|------|--------|--------|-----------------|
| 1 | `plugin/scripts/bot-auth.sh` | `local cfg=...` inside `__bot_auth()` (was line 18) | Yes | Exact — `local cfg` (bare) + `if/elif/else` block, 2-space/4-space nested indent matching the function's existing convention, `bot-auth:` prefix, `${VAR:-}` defensive form throughout |
| 2 | `plugin/scripts/needs-me.sh` | top-level `CFG=...` (was line 70) | Yes | Exact — top-level (0-indent) `if/elif/else`, `needs-me:` prefix, `${VAR:-}` (load-bearing under this file's `set -uo pipefail`) |
| 3 | `plugin/scripts/repo-standard-diff.sh` | top-level `CFG=...` (was line 85) | Yes | Exact — identical shape to `needs-me.sh`, own `repo-standard-diff:` prefix, `${VAR:-}` (load-bearing under this file's `set -uo pipefail`) |
| 4 | `plugin/commands/harden-repo.md` — A2 section | embedded snippet #1, `CFG=...` (was line 44) | Yes | Exact — only the `CFG=` line replaced; `REVIEWERS=` and the `bash .../repo-standard-apply-codeowners.sh` line below are byte-for-byte unchanged (confirmed in diff: no `+`/`-` on those two lines), `harden-repo:` prefix |
| 5 | `plugin/commands/harden-repo.md` — C section | embedded snippet #2, `CFG=...` (was line 106) | Yes | Exact — only the `CFG=` line replaced; `BOT_LOGIN=` through the closing `echo "harden-repo: protection/ruleset will run as ... ✓"` (including the identity-guardrail `if` block) are byte-for-byte unchanged (confirmed in diff: no `+`/`-` on any of those lines), `harden-repo:` prefix |
| 6 | `plugin/skills/init/SKILL.md` | one blockquote line after Step 0's credentials probe, before `## Step 1` | Yes | Exact — single `> Read paths also accept the deprecated ...` line inserted verbatim between the closing ` ``` ` fence and the `## Step 1` heading; the `ls -l` probe itself (line above) is untouched — stays canonical-only, no logic change |

All 6 "Before" quotes in the design matched the live file content exactly on re-read immediately before editing (content-verified, not line-number-assumed, per the task's instruction — the design's own line numbers were in fact still accurate too). No mismatch between design and live tree was found at any site.

---

## Validation performed (build-phase sanity, not the full verify-gate matrix)

| # | Check | Command | Result |
|---|-------|---------|--------|
| 1 | Syntax — `bot-auth.sh` under bash | `bash -n plugin/scripts/bot-auth.sh` | Clean |
| 2 | Syntax — `needs-me.sh` under bash | `bash -n plugin/scripts/needs-me.sh` | Clean |
| 3 | Syntax — `repo-standard-diff.sh` under bash | `bash -n plugin/scripts/repo-standard-diff.sh` | Clean |
| 4 | Syntax — `bot-auth.sh` under zsh (load-bearing: it's *sourced*, never executed, per the design's Design decision 2 / Zsh-safety section) | `zsh -n plugin/scripts/bot-auth.sh` | Clean |
| 5 | Diff scope | `git diff --stat` | Exactly the 5 designed files, 42 insertions / 5 deletions |
| 6 | Full-tree scope | `git status --short` | No files touched outside the 5 + this new report; pre-existing untracked DESIGN doc unchanged |
| 7 | Full diff manual review | `git diff` (read in full) | Every hunk matches the design's "After" blocks verbatim; A2's `REVIEWERS=`/`bash` lines and C's `BOT_LOGIN=`...`echo` lines confirmed unchanged (context lines only, no `+`/`-`) |

Per the task's explicit instruction, `bot-auth.sh`'s real identity-check flow was **not** sourced/run end-to-end (it needs real or stubbed `gh`/credentials) — that belongs to the composer's separate verify-gate matrix run against throwaway-`HOME` fixtures, described in the design's own Verification section (cases a–d × 6 edit sites).

---

## Autonomous Decisions

None. Every one of the design's 6 "Before" quotes matched the live file content exactly on re-read (verified by content, not by trusting the design's line numbers), so every "After" block was applied as a direct, unambiguous transcription with no interpretive gap-filling required.

| # | Decision Point | Options Considered | Chose | Rationale |
|---|----------------|--------------------|-------|-----------|
| — | (none) | — | — | — |

---

## Out of scope — confirmed untouched

Consistent with the design's own "Out of scope" section and the task's hard constraints:

- `plugin/scripts/setup-bot.sh` — not touched (write path, canonical-only by design).
- `README.md`, `ARCHITECTURE.md` — not touched (no matches for either env-var name).
- Historical `.claude/sdd/**` docs (`DESIGN_ISSUE_{34,36,66}*.md`, `BUILD_REPORT_ISSUE_34*.md`) — not touched.
- `.gitignore`, the DEFINE file, the DESIGN file — not touched.
- No `git add`/`commit`/`push`, no `gh` call of any kind was run.

---

## Status: COMPLETE
