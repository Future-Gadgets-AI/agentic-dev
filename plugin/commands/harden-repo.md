---
description: Harden a repo to the team standard — branch protection, branch-naming ruleset, CODEOWNERS, label scheme, bot wiring. Read-only verify by default; --apply writes, gated by two human confirmations.
argument-hint: <owner/repo> [--apply] [--reviewers "<login1 login2 ...>"]
---

# /harden-repo — apply the repo-standard contract

Diff `${CLAUDE_PLUGIN_ROOT}/contracts/repo-standard.md` against a target repo and, in `--apply` mode, bring it into line. Four sub-steps, two identities: **Labels** and **CODEOWNERS** run as the **bot**; **Bot wiring** is report-only; **Branch protection + ruleset** run under **YOUR OWN ambient identity**, confirmed in-session — **never** the bot. This is the plugin's one deliberate synchronous exception (Decision D9): everywhere else a run escalates asynchronously, but there is no safe unattended default for a step whose entire point is that a human must physically be the identity running it.

## Parse arguments

`$ARGUMENTS` = `<owner/repo> [--apply] [--reviewers "<login1 login2 ...>"]`.
- `<owner/repo>` — required, first positional token, shape `OWNER/REPO`. Missing or malformed → refuse with the usage line above and stop; write nothing.
- `--apply` — optional flag. Absent → **verify mode** (read-only, the default). Present → **apply mode**.
- `--reviewers "<space-separated logins>"` — optional, forwarded to Phase A verbatim. When omitted, Phase A resolves `AGENTIC_REVIEWERS` from the bot credentials file itself — you never read that file directly.

No other flags exist (Decision D10) — no custom label sets, no custom protection rules, no custom ruleset prefixes. Reject anything else as an unknown argument.

## Phase A — plan (read-only, always first, both modes)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/repo-standard-diff.sh" "<owner/repo>" [--reviewers "<...>"]
```

This is the **entire** verify mode and apply mode's mandatory first phase — one engine, reused, never re-implemented (Decision D3). It contains zero write verbs by construction. It prints a human-readable diff report on stdout and writes `plan.json` + `protection-put-body.json` + (if needed) `ruleset-post-body.json` to `${TMPDIR:-/tmp}/agentic-dev/repo-standard/<owner>__<repo>/`.

A non-zero exit means Phase A itself failed (bad repo, no read access, malformed contract, etc.) — surface its stderr verbatim and stop; do not proceed to any later phase.

**Present the report verbatim as your reply.** Every later phase and the final report read their inputs from this run's `plan.json` — never recompute a diff by a different path (e.g. do not re-run `gh api` yourself to "double check"; if you suspect the plan is stale, re-run Phase A instead).

**Verify mode (no `--apply`) stops here.** Render the Final report below with every `Status` limited to `MATCH`/`DRIFT`/`ABSENT`/`BLOCKED`/`N/A (plan limitation)` (the last is Protection/ruleset-only — see `plan.json`'s `protection.status`/`ruleset.status` == `na_plan_limitation`), footer `Writes performed: 0 (verify mode — read-only).` Leave the plan directory in place — nothing outside it was written, and a later `--apply` run (or a fresh Phase A run) can reuse or overwrite it.

**Apply mode continues below, strictly in order: A2 (CODEOWNERS) → B (Labels) → Bot wiring (report only) → C (Protection + Ruleset).**

## A2 — CODEOWNERS (identity: bot · gate: NONE)

Runs unconditionally when `plan.json`'s `codeowners.status` is not `"match"`. No human gate: fully reversible — a PR still needs a human merge regardless, and a direct commit on a repo with zero prior history disturbs nothing (Decision D9).

If `codeowners.status` is `"blocked_no_reviewers"` (no `--reviewers` and no `AGENTIC_REVIEWERS` configured anywhere) — report `BLOCKED (no reviewers configured)` for this sub-step and continue to Labels; never guess a reviewer list.

Otherwise, resolve the reviewer list once — the **same** list Phase A used: the `--reviewers` value if the invocation carried one; else extract `AGENTIC_REVIEWERS` from the bot credentials file without sourcing it (never reconstruct it by parsing `plan.json`'s composed `codeowners.target` rendering):

```bash
CFG="${AGENTIC_DEV_CONFIG_DIR:-$HOME/.config/agentic-dev}/credentials"
REVIEWERS="$(grep -E '^[[:space:]]*AGENTIC_REVIEWERS[[:space:]]*=' "$CFG" | tail -1 | sed -E 's/^[^=]*=[[:space:]]*//; s/^["'"'"']//; s/["'"'"']$//')"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/repo-standard-apply-codeowners.sh" "<owner/repo>" --reviewers "$REVIEWERS" --confirmed
```
`--confirmed` here is a required literal for the script's own CLI interface (unifying its shape with `apply-labels.sh`'s — Decision D9), not a human-facing prompt — this sub-step's gate stays `NONE`, unchanged.

It self-sources `bot-auth.sh` — if bot wiring isn't ready, it fails fast; report `BLOCKED (bot wiring absent)` with the exact fix command from its stderr.

**Report block:**
```
### CODEOWNERS
Identity:  bot (repo-standard-apply-codeowners.sh, self-sources bot-auth.sh)
Status:    APPLIED via <direct commit <sha> on main | PR #<n> (draft) | already proposed at PR #<n>> | NO-OP | BLOCKED (bot wiring absent) | BLOCKED (no reviewers configured)
Changed:   .github/CODEOWNERS: "<old-or-empty>" -> "<new>"
```

## B — Labels (identity: bot · gate: ONE confirmation)

If `plan.json`'s `labels.missing` is empty → report `NO-OP` and skip straight to Bot wiring; no confirmation needed.

Otherwise, **end your turn and wait for the human's next message** — via `AskUserQuestion` (or, if unavailable in this session, a direct question; never a bash `read`) — rendering exactly:

```
repo-standard: <N> of <target_count> scheme labels missing on <owner/repo>:
  <comma-separated plan.json labels.missing>
Per labels.md's sanctioned-rollout exception, ONE confirmation authorizes bulk-creating ALL
of the above; every existing label stays untouched.
Create them now?
  [ Yes, create all <N> ]   [ No, skip labels for now ]
```

- **Yes** → `bash "${CLAUDE_PLUGIN_ROOT}/scripts/repo-standard-apply-labels.sh" "<owner/repo>" --confirmed`
- **No** → report `SKIPPED (declined)`, continue to the next sub-step. Nothing was written; re-running `--apply` later is safe.

**Report block:**
```
### Labels
Identity:  bot (repo-standard-apply-labels.sh, self-sources bot-auth.sh)
Status:    APPLIED | NO-OP | SKIPPED (declined) | BLOCKED (bot wiring absent)
Changed:
  + created type:feature (#1d76db)
  ... (or "none — all <target_count> already present")
```

## Bot wiring (identity: n/a · gate: NONE — report only)

**Never** executes `setup-bot.sh`; **never** touches credentials. This is a pure readout of `plan.json`'s `bot_wiring` block from Phase A — no separate call, no re-probe here.

**Report block:**
```
### Bot wiring
Status:  READY (verified push access) | NOT WIRED
Fix (if NOT WIRED):
  1. /agentic-dev:init   (guided), or
  2. plugin/scripts/setup-bot.sh --from-env <file> --login <bot> --probe-repo <owner>/<repo> --reviewers "<...>"
```

## C — Branch protection + ruleset (identity: AMBIENT human · gate: ONE confirmation)

This is the one part of the run that must **never** act as the bot (Decision D6). Run the pre-flight identity assertion first, exactly as below — do not simplify, shorten, or skip it:

```bash
CFG="${AGENTIC_DEV_CONFIG_DIR:-$HOME/.config/agentic-dev}/credentials"
BOT_LOGIN="$(grep -E '^[[:space:]]*GITHUB_LOGIN[[:space:]]*=' "$CFG" 2>/dev/null | tail -1 \
  | sed -E 's/^[^=]*=[[:space:]]*//; s/^["'"'"']//; s/["'"'"']$//')"
CURRENT_LOGIN="$(gh api user --jq .login 2>/dev/null)" \
  || { echo "harden-repo: cannot resolve current gh identity — run 'gh auth login' as yourself." >&2; exit 1; }
if [ -n "$BOT_LOGIN" ] && [ "$CURRENT_LOGIN" = "$BOT_LOGIN" ]; then
  echo "harden-repo: refusing — current gh identity ($CURRENT_LOGIN) IS the configured bot." >&2
  echo "  Branch protection/ruleset must run under YOUR OWN identity, never the bot's." >&2
  exit 1
fi
echo "harden-repo: protection/ruleset will run as '$CURRENT_LOGIN' (ambient, non-bot) ✓"
```

This block never sources `bot-auth.sh` — that is deliberate and structural, not an oversight: `GH_TOKEN` here is whatever your own `gh auth login` already set, because each Bash call is a fresh shell and nothing from an earlier bot-auth'd block leaks in. If this block exits non-zero, stop this sub-step entirely and report `BLOCKED (ambient identity check failed)` — do not build or apply any payload.

Re-probe that `main` exists before rendering the confirmation (Decision D7 — Phase A's snapshot can be stale either direction: CODEOWNERS may just have created `main`, or A2 may have been skipped/blocked): `gh api "repos/<owner/repo>/branches/main" >/dev/null 2>&1`.
- `main` missing and A2 didn't just create it (declined, blocked, or a non-empty repo with no `main`) → skip the **protection** half only, report `BLOCKED (main branch does not exist)`. The **ruleset** half has no such dependency (its `ref_name` conditions are pattern-based, not tied to an existing branch) — proceed with it independently.
- `main` exists → continue below.

If protection status is already `"match"` **and** ruleset status is already `"match"` — nothing to confirm; report `NO-OP (already matches)` for both and skip straight to the Final report without asking.

Otherwise, read `$PLAN_DIR/protection-put-body.json` and (if present) `$PLAN_DIR/ruleset-post-body.json`, pretty-print them, and **end your turn and wait for the human's next message**:

```
Branch protection + ruleset changes for <owner/repo> require YOUR OWN GitHub
identity (never the bot — it must never hold Administration). Current identity: <CURRENT_LOGIN>.

Planned PUT repos/<owner/repo>/branches/main/protection:
<pretty-printed protection-put-body.json>   (omit this block if protection status is already "match")

Planned POST repos/<owner/repo>/rulesets:
<pretty-printed ruleset-post-body.json>   (omit this block if ruleset status is already "match")

Apply now as <CURRENT_LOGIN>?
  [ Yes, apply ]   [ No, leave as-is ]
```

On **Yes**, run inline exactly as below — **never** wrapped in a script (Decision D6: burying this in a script would silence the `enforce-bot-identity.py` hook entirely, allowing the write unconditionally regardless of the marker). Run only the write line(s) whose status isn't already `"match"`. **Every** write line carries its own trailing `# agentic:allow-ambient` marker, even though this block never sources `bot-auth.sh` — that marker is the deliberate, visible opt-out the hook expects for a write it would otherwise legitimately block on this org:

```bash
REPO="<owner/repo>"
PLAN_DIR="${TMPDIR:-/tmp}/agentic-dev/repo-standard/${REPO/\//__}"

# only if protection status != "match":
gh api --method PUT "repos/${REPO}/branches/main/protection" \
  --input "$PLAN_DIR/protection-put-body.json"  # agentic:allow-ambient

# only if ruleset status != "match":
gh api --method POST "repos/${REPO}/rulesets" \
  --input "$PLAN_DIR/ruleset-post-body.json"  # agentic:allow-ambient
```

On **No** → report `DECLINED`, note "re-run `/harden-repo <repo> --apply` to retry."

**Report block:**
```
### Branch protection + ruleset
Identity:  ambient human (<CURRENT_LOGIN>) — asserted != configured bot (asserted <timestamp>)
Status:    APPLIED (confirmed) | NO-OP (already matches) | AWAITING CONFIRMATION | DECLINED | BLOCKED (main branch does not exist) | BLOCKED (ambient identity check failed)
Changed:
  protection.required_status_checks.contexts: <before> -> <after>
  (all other observed protection fields — restrictions, required_conversation_resolution,
   required_linear_history, block_creations, lock_branch, allow_fork_syncing — preserved verbatim)
  ruleset: created "branch-naming-convention" (new id <n>) | already present, no-op | DRIFT (not modified — see plan.json ruleset.diff_fields)
```

## Final report (always rendered, both modes)

```
# Repo hardening — <owner/repo> — <VERIFY|APPLY>

| Sub-step               | Identity                  | Status |
|-------------------------|---------------------------|--------|
| Labels                  | bot                       | ...    |
| CODEOWNERS              | bot                       | ...    |
| Bot wiring              | —                         | ...    |
| Protection + ruleset    | ambient (<CURRENT_LOGIN>) | ...    |

Writes performed: <N> | Confirmations: <granted>/<asked> granted | Mode: <verify|apply>
```

Verify mode: every `Status` is `MATCH`/`DRIFT`/`ABSENT`/`BLOCKED`/`N/A (plan limitation)` (Protection/ruleset-only); footer `Writes performed: 0 (verify mode — read-only).`

`<asked>` counts only the gates actually presented in this run (up to 2: Labels, Protection+ruleset) — a gate that never needed to ask because it was already a `NO-OP` doesn't count as "asked."

Clean up on the way out: `rm -rf "${TMPDIR:-/tmp}/agentic-dev/repo-standard/<owner>__<repo>"` **only** after apply mode has fully resolved every gated sub-step (applied, no-op, or declined) — never mid-run, and never in verify mode.
