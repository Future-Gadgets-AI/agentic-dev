# DESIGN: Harden a new repo to the team standard

> Technical design for issue #36. Codifies the org's repo-hardening "recipe" (branch protection, branch-naming ruleset, CODEOWNERS, label scheme, bot wiring) as a versioned contract plus an idempotent diff→plan→apply tool with a read-only verify mode. First client: `Future-Gadgets-AI/gear`.

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | ISSUE_36_REPO_HARDENING |
| **Date** | 2026-07-04 |
| **Author** | design phase (`agentspec:workflow:design`) |
| **DEFINE** | [`.claude/sdd/_synthesized/DEFINE_ISSUE_36_REPO_HARDENING.md`](../_synthesized/DEFINE_ISSUE_36_REPO_HARDENING.md) |
| **Status** | Ready for Build |

---

## Scope

**In:** `plugin/contracts/repo-standard.md` (the contract); one apply entrypoint with a read-only verify mode; the four sub-steps (labels, CODEOWNERS, bot-wiring report, branch protection + ruleset), each with its decided identity; the confirmation UX for the two sub-steps that need one.

**Out (per DEFINE, honored as-is):** repo creation; creating/editing CI workflows or release automation (the tool only *requires* `bump-gate`/`closing-keyword-gate` as status checks — it never authors them); a Projects board; any per-repo override beyond *target repo* and *reviewer list*. **No GitHub writes during this build** — the composer's smoke gate performs the real runs afterward (AT-1 against `gear`, AT-2/AT-3 against `agentic-dev`); the plugin version bump is likewise the composer's step, not this design's.

---

## Architecture Overview

```text
┌────────────────────────────────────────────────────────────────────────┐
│ /harden-repo <owner/repo> [--apply] [--reviewers "<logins>"]           │
│ plugin/commands/harden-repo.md — entrypoint + orchestration only       │
└───────────────────────────────┬────────────────────────────────────────┘
                                 ▼
                ┌───────────────────────────────────┐
                │ Phase A — PLAN (read-only, ambient)│  ◄─ verify mode
                │ scripts/repo-standard-diff.sh      │     stops HERE —
                │  reads: protection, rulesets,      │     0 writes,
                │  labels, CODEOWNERS, bot-wiring     │     by construction
                │  probe — diffs vs repo-standard.md │     (no write verb
                │  → plan.json + human-readable report│    appears in this
                └───────────────┬─────────────────────┘    script at all)
                                │  apply mode only, from here down:
      ┌─────────────────────────┼───────────────────┬─────────────────────────┐
      ▼                         ▼                    ▼                        ▼
┌──────────────┐   ┌────────────────────────┐  ┌───────────────┐  ┌───────────────────────┐
│ A2. CODEOWNERS│   │ B. Labels               │  │ Bot wiring    │  │ C. Protection + Ruleset│
│ identity: bot │   │ identity: bot           │  │ (report only) │  │ identity: AMBIENT human│
│ gate: none    │   │ gate: 1 confirmation    │  │ no identity,  │  │ gate: 1 confirmation   │
│ apply-        │   │ apply-labels.sh         │  │ no action —   │  │ inline gh api in the   │
│ codeowners.sh │   │ --confirmed             │  │ delegates to  │  │ command file itself,   │
│ (self-sources │   │ (self-sources           │  │ init /        │  │ each write line marked │
│  bot-auth.sh) │   │  bot-auth.sh)           │  │ setup-bot.sh  │  │ `# agentic:allow-ambient`│
│ direct commit │   │ re-checks gh label list │  │               │  │ bot-auth.sh is NEVER   │
│ (empty repo)  │   │ before every create     │  │               │  │ sourced in this block  │
│ or branch+PR  │   │                         │  │               │  │                        │
└──────────────┘   └────────────────────────┘  └───────────────┘  └───────────────────────┘
                                 │
                                 ▼
                    final report: one table, sub-step × identity × status
```

**Data flow (apply mode, happy path):**
1. `harden-repo.md` resolves `<owner/repo>` and reviewer list (`--reviewers` or `AGENTIC_REVIEWERS`).
2. Phase A runs once; its `plan.json` + rendered report is what every later phase and the final report reads from — never recomputed ad hoc.
3. A2 (CODEOWNERS) runs unconditionally if drifted — no gate. On a genuinely empty target repo this is also what creates the `main` branch (see Decision 7), so it always runs *before* Phase C's protection step is allowed to proceed.
4. B (Labels) asks its one confirmation, then applies or is skipped.
5. Bot-wiring is a pure readout of Phase A's `bot_wiring` block — no separate call.
6. C (Protection + Ruleset) re-probes that `main` exists, asks its one confirmation, then applies under the ambient identity.
7. The command renders the final per-sub-step table and cleans up the plan directory.

---

## Component shapes (ADR-0005 taxonomy)

| Component | Shape | Rationale |
|---|---|---|
| `plugin/contracts/repo-standard.md` | **contract** | Canonical, machine-loadable target configuration — exactly the role `contracts/` exists for (`lifecycle.md`, `dor-rubric.md`, `labels.md` are the precedent). References `labels.md` for label *semantics*, never forks it. |
| `plugin/commands/harden-repo.md` | **command** | A human-invoked, deliberate entrypoint (`/harden-repo <repo>`) — matches the existing precedent exactly: `/pickup`, `/needs-me`, `/recommend` are all direct commands, not skills, and none of them wrap a companion skill. There is no cross-command reuse need here (unlike `implement`/`a2a-workflow`, which several commands share), so a dedicated skill would be an unused extra layer. |
| `plugin/scripts/repo-standard-diff.sh` | **script** | Deterministic, identity-agnostic mechanics (all reads) — the same role `needs-me.sh`/`bump.sh` already play. Independently invocable and smokeable outside the LLM loop. |
| `plugin/scripts/repo-standard-apply-labels.sh` | **script** | Deterministic bot-authenticated mechanics, self-sourcing `bot-auth.sh` exactly like `request-reviewers.sh`. |
| `plugin/scripts/repo-standard-apply-codeowners.sh` | **script** | Same pattern as above, for the CODEOWNERS write. |
| Branch protection + ruleset apply | **inline bash in the command**, deliberately *not* a script | See Decision 6 — the hook's opt-out marker only has teeth if the literal `gh api` write text is in the string Claude's Bash tool actually executes; hiding it inside a called script would make both the marker and the hook meaningless for this step. |

No new **agent** is introduced: this plugin's `agents/` are workflow roles (`the-planner`, `codebase-explorer`), not per-domain specialists, and this feature needs neither planning nor exploration at runtime — it needs deterministic `gh api` diffing. Consistent with the two existing command-level DESIGN docs in this repo (`DESIGN_ISSUE_25`, `DESIGN_ISSUE_34`), neither of which assigns files to specialist agents either.

---

## Key Decisions

### D1 — Command + scripts, no new skill
**Context:** ADR-0005 gives `commands/` the entrypoint role and `scripts/` the deterministic-mechanics role. **Choice:** one command, three scripts (as above), zero skills. **Alternatives rejected:** a `harden-repo` skill wrapping the command — rejected, nothing else in the plugin would load it, and `/needs-me`/`/recommend` already establish that a command-only (or command+script) shape is normal here.

### D2 — `repo-standard.md` is parsed directly, never duplicated
**Context:** the label rollout needs exact hex colors, which `labels.md` doesn't carry; the protection/ruleset sub-steps need exact JSON payloads. **Choice:** embed three fenced ` ```json ` blocks in `repo-standard.md`, each anchored under a stable, literal H3 heading; every script that needs contract data parses the file directly (regex-extract the block after its heading, `json.loads` it) instead of hardcoding a second copy. **Rationale:** one source of truth, matching `contracts/README.md`'s own framing ("canonical, machine-loadable rules and data") — a script and a human read the *same* bytes. **Consequence:** the headings are load-bearing; renaming one without updating the parser breaks the tool (documented inline in the contract file itself).

### D3 — Verify mode *is* apply mode's first phase, nothing more
**Context:** the task calls for "verify mode as strict read-only planning pass." **Choice:** `repo-standard-diff.sh` is the *entire* verify mode and *also* apply mode's mandatory first phase — one engine, reused, never re-implemented. Verify mode simply never proceeds past it. **Consequence:** AT-2's "byte-identical no-writes proof" is true by construction — the diff script contains zero write verbs (no `create`, `edit`, `-X POST/PUT/PATCH/DELETE` anywhere in it), not just by convention.

### D4 — Branch protection: read-merge-write, never a blind PUT
**Context:** the PUT `.../protection` endpoint is full-replace; DEFINE's known-reference-state names a *subset* of fields as decided (`required_pull_request_reviews` sub-fields, `enforce_admins`, no force-push, no deletion, `required_status_checks`). The live GET also carries fields DEFINE never mentions (`restrictions` → push scoped to the org's `maintainers` team; `required_conversation_resolution: true`; `required_linear_history`, `block_creations`, `lock_branch`, `allow_fork_syncing`). **Choice:** GET current → override *only* the managed fields from the contract → pass every other observed field through unchanged → PUT the merge, and **only if it differs from current** (skip the call entirely otherwise). **Rationale:** re-running against `agentic-dev` for AT-3 must add the two required status checks *without* silently stripping its existing push restriction or conversation-resolution setting — a blind overwrite using only the fields DEFINE named would do exactly that. **Alternatives rejected:** hardcode `restrictions`/`required_conversation_resolution` as additional managed fields — rejected as scope creep: DEFINE's known-reference-state doesn't list them as decided, so they stay unmanaged (a candidate for a future revision of this contract, not this one).

### D5 — `required_status_checks.contexts` is computed per target repo, never hardcoded
**Context:** AT-1 runs against `gear` (bare — no workflows at all) and AT-3 runs against `agentic-dev` (both gate workflows already exist). If the contract statically required `bump-gate`/`closing-keyword-gate` everywhere, `gear`'s PRs would deadlock forever on a check that never reports. **Choice:** Phase A probes `gh api repos/<repo>/contents/.github/workflows/{bump-gate,closing-keyword-gate}.yml` (200 vs 404) and only includes a context in the merge if its workflow file is actually present on the target's default branch. Existing unrelated contexts are unioned in, never replaced. **Consequence:** the *same* contract produces the *empty* required-checks outcome on `gear` and the *two-context* outcome on `agentic-dev`, satisfying both acceptance tests without a special case.

### D6 — Two different identity-guarantee mechanisms, matched to direction
**Context:** AT-5 requires *both* directions: labels/CODEOWNERS never ambient, protection/ruleset never bot.
- **Bot-bound direction (labels, CODEOWNERS):** the scripts `source "$HERE/bot-auth.sh" || exit 1` themselves, exactly like `request-reviewers.sh` — fail-fast, structural, deterministic. The `enforce-bot-identity.py` hook is *irrelevant* here (it can't even see writes issued from inside a called script — it only inspects the literal Bash `tool_input.command` string, e.g. `bash .../repo-standard-apply-labels.sh <repo>`, which never contains `gh label create` as text), so correctness rests entirely on the script's own sourced line, same as the existing precedent.
- **Ambient-bound direction (protection, ruleset):** the *opposite* guarantee — the bot must **never** run this. Three layers: (1) **structural** — this bash block never sources `bot-auth.sh`, so `GH_TOKEN` is whatever the human's own `gh auth login` already set (each Bash call is a fresh shell — nothing leaks in from an earlier bot-auth'd block); (2) **asserted** — before building any payload, compare `gh api user --jq .login` to the configured `GITHUB_LOGIN` (parsed out of the credentials file *without sourcing it*, same technique as `needs-me.sh`); refuse if they match; (3) **platform ceiling** — even a bug that somehow ran this under the bot's token would 403, because the bot's fine-grained PAT structurally never has `Administration` (`plugin/skills/init/references/fine-grained-pat.md`, doctrinal). Because the actual `gh api -X PUT/POST` calls are **inline in the command**, not wrapped in a script, `enforce-bot-identity.py` *can* see them and *would* block an accidental ambient write to this org — which is exactly why the `# agentic:allow-ambient` marker must be present (see Per-sub-step section below): it is the deliberate, visible opt-out for a write the hook would otherwise legitimately stop.
**Consequence — this is why protection/ruleset apply logic is not a fourth script** (contrast D1): burying it in a script would silence the hook entirely (it would allow the write unconditionally, marker or not), defeating the exact protection DEFINE asked for.

### D7 — Ordering dependency: CODEOWNERS before protection, on a genuinely empty repo
**Context:** `gear` is described as "completely bare." Branch protection targets `branches/main/protection`, which 404s if `main` doesn't exist yet; a truly empty repo (`gh api repos/<repo>/commits` → 409 "Git Repository is empty") has no branches at all. The CODEOWNERS direct-commit path (Contents API, `branch: main`) is what creates the first commit *and* the `main` branch on such a repo. **Choice:** A2 (CODEOWNERS) always runs before C (protection) in apply mode; Phase A's plan flags `codeowners.repo_has_history: false`, and Phase C re-probes `main`'s existence immediately before rendering its confirmation rather than trusting the stale Phase A snapshot. **Consequence:** the ruleset half of Phase C has no such dependency (a ruleset's `ref_name` conditions are pattern-based, not tied to an existing branch) — only the protection half waits.

### D8 — CODEOWNERS: direct commit vs. branch+PR, idempotent either way
**Context:** DEFINE decided "file via PR on repos with history; direct commit acceptable on a fresh empty repo." **Choice:** detect emptiness via the commits-endpoint 409 (fallback: `.size == 0`); on empty → Contents API `PUT` creates `.github/CODEOWNERS` directly on `main`; on non-empty → deterministic branch name `chore/codeowners-hardening` (not a random name) + PR, always `--draft`, body carries `[no-close: repo-hardening bootstrap — no tracking issue on <target-repo>]` (defensively — harmless if the target has no `closing-keyword-gate`, required if it does), reviewers requested via the existing `request-reviewers.sh`. **Idempotency:** before opening a PR, check for an already-open PR from that exact branch name; if found, report "already proposed at PR #N" instead of duplicating. If current file content already equals the target line, no write at all, on either path.

### D9 — Confirmation UX is this plugin's one deliberate synchronous exception
**Context:** everywhere else, a block escalates *asynchronously* (label + comment, never a synchronous wait — Constitution Principle IV). Repo-hardening's ambient-identity switch has no safe unattended default — proceeding without a human physically present to *be* that identity is meaningless, not just risky. **Choice:** exactly two real conversational stops — end the assistant's turn and wait for the human's next message (via `AskUserQuestion`, matching the existing interactive precedent in `a2a-workflow/assets/clarification-gate.md`) — for Labels and for Protection+Ruleset. CODEOWNERS and Bot-wiring get none (see Per-sub-step section for why each doesn't need one). **Consequence:** `/harden-repo --apply` cannot fully complete in one unattended pass when there's drift in either gated sub-step — by design, not by gap.

### D10 — CLI surface is fixed to DEFINE's two legitimate parameters
**Context:** DEFINE scopes out "per-repo overrides beyond target repo + reviewer list." **Choice:** `/harden-repo <owner/repo> [--apply] [--reviewers "<space-separated logins>"]` — nothing else is parameterizable (no custom label sets, no custom protection rules, no custom ruleset prefixes). `--reviewers` defaults to `AGENTIC_REVIEWERS` from the bot credentials file when omitted.

---

## The `repo-standard.md` contract — full outline

Build creates `plugin/contracts/repo-standard.md` with **exactly** this structure (headings are load-bearing — `repo-standard-diff.sh` parses them literally, see Code Patterns). Live values below were exported read-only from `Future-Gadgets-AI/agentic-dev` on 2026-07-04 (`gh api repos/.../branches/main/protection`, `gh api repos/.../rulesets/18134296`, `gh label list`); non-substantive API metadata (`url`, `node_id`, timestamps, `_links`) is trimmed from the "observed" blocks for readability — every configuration *value* is preserved verbatim.

```
# Repo Standard — the codified hardening contract

> **Enforcement:** the identity boundary between sub-steps is code-enforced — bot-auth.sh
> is sourced (fail-fast) by the Labels/CODEOWNERS scripts, and deliberately never sourced by
> the Branch-protection/Ruleset step, which additionally asserts the current gh identity is
> not the bot before proceeding; the PreToolUse hook backstops the latter, and the bot's PAT
> structurally lacks Administration regardless (fine-grained-pat.md). The configuration
> VALUES below are prompt-and-script-honored, not hook-enforced: nothing stops a human
> hand-editing a live repo outside this tool. Re-run `/harden-repo <repo>` (verify mode) to
> catch that drift. (Constitution Principle VI.)

## Branch protection — managed fields (target)
​```json
{
  "required_pull_request_reviews": {
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true
  },
  "enforce_admins": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_status_checks": {
    "strict": false,
    "contexts": ["bump-gate", "closing-keyword-gate"]
  }
}
​```
`required_status_checks` is applied only with whichever of `contexts` has a matching
`.github/workflows/<context>.yml` on the target repo's default branch — see Decision D5.
On a repo with neither present, `required_status_checks` is omitted from the merge (not set
to an empty/impossible requirement). All fields not listed above are preserved verbatim from
the target repo's current live state — never asserted, never overwritten (Decision D4).

## Branch protection — observed live snapshot (agentic-dev, exported 2026-07-04)
​```json
{
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "require_last_push_approval": false,
    "required_approving_review_count": 1
  },
  "required_signatures": { "enabled": false },
  "enforce_admins": { "enabled": true },
  "required_linear_history": { "enabled": false },
  "allow_force_pushes": { "enabled": false },
  "allow_deletions": { "enabled": false },
  "block_creations": { "enabled": false },
  "required_conversation_resolution": { "enabled": true },
  "lock_branch": { "enabled": false },
  "allow_fork_syncing": { "enabled": false },
  "restrictions": {
    "users": [],
    "teams": [{ "slug": "maintainers", "permission": "pull" }],
    "apps": []
  }
}
​```
`restrictions` (push scoped to the org's `maintainers` team) and
`required_conversation_resolution` are genuine live settings on the reference repo but are
**not** managed fields here — out of scope for this revision (Decision D4); they show up as
"preserved, unmanaged" in every diff report, never as a target asserted on other repos.

## Branch-naming ruleset — target creation payload
​```json
{
  "name": "branch-naming-convention",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["~ALL"],
      "exclude": [
        "refs/heads/main",
        "refs/heads/feat/**",
        "refs/heads/fix/**",
        "refs/heads/chore/**",
        "refs/heads/docs/**",
        "refs/heads/refactor/**",
        "refs/heads/test/**",
        "refs/heads/perf/**",
        "refs/heads/ci/**",
        "refs/heads/build/**",
        "refs/heads/style/**",
        "refs/heads/release/**",
        "refs/heads/hotfix/**",
        "refs/heads/revert-*",
        "refs/heads/dependabot/**"
      ]
    }
  },
  "rules": [{ "type": "creation" }],
  "bypass_actors": []
}
​```
This full 14-prefix list is the live rule (`git-collaboration`'s branch-naming table lists
only the first five — that table is illustrative prose; this is the codified, complete
source). Applies only when **no** existing ruleset already targets branch creation on the
target repo; if one exists but differs, the diff reports DRIFT and does not modify it
(Decision, Error Handling).

## Branch-naming ruleset — observed live snapshot (agentic-dev, ruleset id 18134296, exported 2026-07-04)
​```json
{
  "id": 18134296,
  "name": "branch-naming-convention",
  "target": "branch",
  "enforcement": "active",
  "rules": [{ "type": "creation" }],
  "bypass_actors": [],
  "current_user_can_bypass": "never"
}
​```
(conditions omitted here — identical to the target payload above; the live ruleset already
matches the standard being codified, as expected since agentic-dev is the reference repo.)

## Label rollout manifest (target — create if missing; never touch existing)
​```json
[
  {"name": "type:feature", "color": "1d76db", "description": "A new capability to add"},
  {"name": "type:task", "color": "1d76db", "description": "A concrete unit of work (child of feature/epic/ADR)"},
  {"name": "type:epic", "color": "1d76db", "description": "A large umbrella initiative (parent of features/tasks)"},
  {"name": "type:spike", "color": "1d76db", "description": "A time-boxed investigation with a defined deliverable"},
  {"name": "type:adr", "color": "0052cc", "description": "An Architecture Decision Record published as an issue"},
  {"name": "priority:high", "color": "b60205", "description": "Now / blocking — P0/P1"},
  {"name": "priority:medium", "color": "d93f0b", "description": "Soon — scheduled work with a clear horizon"},
  {"name": "priority:low", "color": "fbca04", "description": "Backlog — nice-to-have, no active blocker"},
  {"name": "status:blocked", "color": "5319e7", "description": "Waiting on an external dependency — name it in a comment"},
  {"name": "status:needs-decision", "color": "8a2be2", "description": "Awaiting a human decision — @-mention the decider"},
  {"name": "phase:triage", "color": "0e8a16", "description": "Created but not yet scheduled for implementation"},
  {"name": "phase:in-progress", "color": "0e8a16", "description": "A branch exists; implementation active (P4-P5)"},
  {"name": "phase:review", "color": "0e8a16", "description": "PR open; awaiting blind/human review (P6-P7)"},
  {"name": "phase:done", "color": "0e8a16", "description": "Implementation merged; issue closed/closing"},
  {"name": "readiness:draft", "color": "ededed", "description": "Captured idea, not yet DoR-assessed (default on creation)"},
  {"name": "readiness:needs-refinement", "color": "e99695", "description": "DoR assessed and FAILED — needs human authoring before pickup"},
  {"name": "readiness:ready", "color": "006b75", "description": "Passes the Definition of Ready — an agent may pick it up"},
  {"name": "no-release", "color": "BFD4F2", "description": "Waive the version-bump gate (ADR-0006/#33) for a deliberate unversioned shipped change"}
]
​```
18 entries — the 19th scheme label (`bug`) is GitHub's own built-in default, already present
on every new repo; nothing to create. Semantics/rules for all of these stay owned by
`plugin/contracts/labels.md` (this table adds only the colors/descriptions labels.md doesn't
carry — it does not redefine meaning).

## CODEOWNERS — format
File: `.github/CODEOWNERS`. Content (single line): `* @<reviewer-1> @<reviewer-2> ... @<reviewer-N>`.
Reviewers come from the tool's `--reviewers` argument, defaulting to `AGENTIC_REVIEWERS`.
Any ONE listed reviewer satisfies "Require review from Code Owners" — order is cosmetic.
Observed live example (agentic-dev, exported 2026-07-04): `* @gustavomoura628 @lucasbrandao4770 @thallersubtil`

## Bot wiring — pointer (never re-derive credential logic here)
Source of truth: `plugin/skills/init/SKILL.md` (guided) + `plugin/scripts/setup-bot.sh` /
`bot-auth.sh` (mechanics). Readiness for a target repo = local credentials exist AND
`gh api repos/<target>/... --jq .permissions.push` (under the bot token) is `true`. The
bot's PAT must never include `Administration` (repo or org) — see
`plugin/skills/init/references/fine-grained-pat.md`. This tool only reports gaps; it never
creates or edits credentials.
```

(The `​```` fences above are escaped with a zero-width marker only so this design doc renders without prematurely closing its own outer code fence; the actual file has plain triple-backtick fences.)

---

## The diff → plan → apply engine

**Idempotency mechanism**, per sub-step:
| Sub-step | Idempotent because |
|---|---|
| Labels | `gh label list` re-checked immediately before every create; only ever creates what's *still* missing; never touches an existing label |
| CODEOWNERS | current file content compared to target *before* writing; equal → no-op; an already-open PR from the deterministic branch is detected and reused, never duplicated |
| Protection | read-merge-write; the merged payload is compared to current *before* the PUT is issued — if equal, the PUT is skipped entirely (not just harmless, genuinely not called) |
| Ruleset | created only when *no* existing ruleset targets branch creation; if the merge would be identical to an already-matching ruleset, nothing is sent |

**Plan shape** — `repo-standard-diff.sh` writes (and returns via stdout, rendered) a `plan.json` to a deterministic, non-self-deleting directory (survives across the separate Bash tool calls that later phases run in — each Bash call is a fresh process, so nothing may rely on shell-exported state surviving between phases):

```
${TMPDIR:-/tmp}/agentic-dev/repo-standard/<owner>__<repo>/
  plan.json                    # the full machine-readable diff, shape below
  protection-put-body.json     # precomputed merge — ready to PUT verbatim if apply confirmed
  ruleset-post-body.json       # present only if ruleset status != "match"
```

```json
{
  "repo": "Future-Gadgets-AI/gear",
  "generated_at": "2026-07-04T18:00:00Z",
  "bot_wiring": {"ready": false, "reason": "no credentials file", "fix": "…/scripts/setup-bot.sh --from-env … or /agentic-dev:init"},
  "labels": {"missing": ["type:feature", "type:task", "…"], "existing_scheme_count": 0, "target_count": 18},
  "codeowners": {"status": "absent", "current": null, "target": "* @a @b @c", "repo_has_history": false},
  "protection": {"status": "absent", "main_branch_exists": false, "blocked_on": "codeowners", "diff_fields": ["all"]},
  "ruleset": {"status": "absent", "diff_fields": ["all"]},
  "required_checks_detected": []
}
```

Verify mode renders this plan as a report and stops. Apply mode reads the *same* `plan.json` to decide which of Phases A2/B/C have pending work — it is never recomputed by a different code path.

---

## Per-sub-step identity, confirmation UX, and reporting format

### Labels — identity: bot · gate: ONE confirmation
No confirmation needed if `labels.missing` is empty (report `NO-OP`). Otherwise, the command renders and stops (turn ends, `AskUserQuestion` or a direct question — never a bash `read`):

```
repo-standard: 18 of 18 scheme labels missing on Future-Gadgets-AI/gear:
  type:feature, type:task, type:epic, type:spike, type:adr, priority:high, priority:medium,
  priority:low, status:blocked, status:needs-decision, phase:triage, phase:in-progress,
  phase:review, phase:done, readiness:draft, readiness:needs-refinement, readiness:ready,
  no-release
Per labels.md's sanctioned-rollout exception, ONE confirmation authorizes bulk-creating ALL
of the above; every existing label stays untouched.
Create them now?
  [ Yes, create all 18 ]   [ No, skip labels for now ]
```
On **Yes**: `bash ".../repo-standard-apply-labels.sh" "<owner/repo>" --confirmed`. On **No**: report `SKIPPED (declined)`, continue to the next sub-step — safe to re-run `--apply` later.

**Report block:**
```
### Labels
Identity:  bot (repo-standard-apply-labels.sh, self-sources bot-auth.sh)
Status:    APPLIED | NO-OP | SKIPPED (declined) | BLOCKED (bot wiring absent)
Changed:
  + created type:feature (#1d76db)
  + created type:task (#1d76db)
  … (or "none — all 18 already present")
```

### CODEOWNERS — identity: bot · gate: none
No human gate: fully reversible (a PR needs a human merge regardless; a direct commit on a repo with zero prior history disturbs nothing). Runs unconditionally in apply mode when drifted.

**Report block:**
```
### CODEOWNERS
Identity:  bot (repo-standard-apply-codeowners.sh, self-sources bot-auth.sh)
Status:    APPLIED via <direct commit <sha> on main | PR #<n> (draft)> | NO-OP | BLOCKED (bot wiring absent)
Changed:   .github/CODEOWNERS: "" -> "* @gustavomoura628 @lucasbrandao4770 @thallersubtil"
```

### Bot wiring — identity: n/a · gate: none (report only)
Never executes `setup-bot.sh`; never touches credentials. Pulled straight from Phase A's `bot_wiring` block.

**Report block:**
```
### Bot wiring
Status:  READY (verified push access) | NOT WIRED
Fix (if NOT WIRED):
  1. /agentic-dev:init   (guided), or
  2. plugin/scripts/setup-bot.sh --from-env <file> --login <bot> --probe-repo <owner>/<repo> --reviewers "<…>"
```

### Branch protection + ruleset — identity: AMBIENT human · gate: ONE confirmation
Pre-flight identity assertion (inline, before anything is rendered):
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
Then render and stop:
```
Branch protection + ruleset changes for Future-Gadgets-AI/gear require YOUR OWN GitHub
identity (never the bot — it must never hold Administration). Current identity: lucasbrandao4770.

Planned PUT repos/Future-Gadgets-AI/gear/branches/main/protection:
<pretty-printed protection-put-body.json>

Planned POST repos/Future-Gadgets-AI/gear/rulesets:
<pretty-printed ruleset-post-body.json>   (omitted if ruleset status is already "match")

Apply now as lucasbrandao4770?
  [ Yes, apply ]   [ No, leave as-is ]
```
On **Yes**, run inline — **every** write line carries its own trailing marker (cheap redundancy, correct even if this block is later split across separate Bash tool calls):
```bash
REPO="Future-Gadgets-AI/gear"
PLAN_DIR="${TMPDIR:-/tmp}/agentic-dev/repo-standard/${REPO/\//__}"

gh api --method PUT "repos/${REPO}/branches/main/protection" \
  --input "$PLAN_DIR/protection-put-body.json"  # agentic:allow-ambient

# only if ruleset status != "match":
gh api --method POST "repos/${REPO}/rulesets" \
  --input "$PLAN_DIR/ruleset-post-body.json"  # agentic:allow-ambient
```
On **No**: report `DECLINED`, note "re-run `/harden-repo <repo> --apply` to retry."

**Report block:**
```
### Branch protection + ruleset
Identity:  ambient human (lucasbrandao4770) — asserted != configured bot (asserted 2026-07-04T18:03Z)
Status:    APPLIED (confirmed) | NO-OP (already matches) | AWAITING CONFIRMATION | DECLINED
Changed:
  protection.required_status_checks.contexts: [] -> ["bump-gate","closing-keyword-gate"]
  (all other observed protection fields — restrictions, required_conversation_resolution,
   required_linear_history, block_creations, lock_branch, allow_fork_syncing — preserved verbatim)
  ruleset: created "branch-naming-convention" (new id <n>) | already present, no-op
```

**Overall final report** (always rendered, both modes):
```
# Repo hardening — Future-Gadgets-AI/gear — APPLY

| Sub-step               | Identity                 | Status                    |
|-------------------------|--------------------------|----------------------------|
| Labels                  | bot                      | APPLIED (18 created)       |
| CODEOWNERS              | bot                      | APPLIED (direct commit)    |
| Bot wiring              | —                        | READY                      |
| Protection + ruleset    | ambient (lucasbrandao4770)| APPLIED (confirmed)       |

Writes performed: 20 | Confirmations: 2/2 granted | Mode: apply
```
Verify mode uses the same table with `Status` limited to `MATCH`/`DRIFT`, footer `Writes performed: 0 (verify mode — read-only).`

---

## Error handling

| Error | Handling | Retry? |
|---|---|---|
| `gh` not authenticated at all (Phase A, ambient) | let the first call's native error surface, exit non-zero, no bespoke wrapping (matches `needs-me.sh`) | No |
| Target repo doesn't exist / no read access | Phase A fails fast with a one-line message naming the repo | No |
| Bot credentials absent locally | `bot_wiring.ready=false`; Labels/CODEOWNERS report `BLOCKED (bot wiring absent)` with the exact init/setup-bot.sh command; protection/ruleset unaffected (ambient, independent) | No |
| Bot creds present but push-probe to the *target* repo fails (403/no access) | same `BLOCKED` treatment, message names the specific repo the probe failed against | No |
| A single `gh label create` fails mid-batch | log `! FAILED to create <name>` to stderr, continue the remaining labels, non-zero exit at the end if any failed | No |
| CODEOWNERS: an open PR from `chore/codeowners-hardening` already exists | detected before creating a new one; report "already proposed at PR #N" | No |
| CODEOWNERS: local branch name conflict on the target (rare, diverged history) | fail fast, name the conflict; resolving it is a human step, out of scope to auto-resolve | No |
| Ruleset already exists targeting branch creation but with different conditions | reported as `DRIFT`, never auto-modified (avoids an unreviewed PATCH to an unrelated existing rule) | No |
| Ambient identity assertion: current `gh` login == configured bot login | Phase C refuses before constructing any payload | No |
| Human declines either confirmation | sub-step marked `SKIPPED`/`DECLINED`; run continues with remaining sub-steps; re-running `--apply` later is safe (idempotent) | No — re-run instead |
| Required-check workflow probe 404s for a context | omit that context from the merge; never add a required check that can never report | No |
| `main` doesn't exist yet when Phase C is reached and CODEOWNERS (A2) didn't create it (e.g. declined, or repo already had history but no `main`) | protection half of Phase C is skipped and reported `BLOCKED (main branch does not exist)`; ruleset half proceeds independently (Decision D7) | No |

---

## Code Patterns

### Pattern 1 — parsing the contract's JSON blocks (used by every script that needs contract data)
```python
import json, re, sys

def block(text: str, heading: str) -> object:
    m = re.search(re.escape("## " + heading) + r"\n```json\n(.*?)\n```", text, re.DOTALL)
    if not m:
        sys.exit(f"repo-standard: missing or malformed section {heading!r}")
    return json.loads(m.group(1))

contract = open(f"{plugin_root}/contracts/repo-standard.md").read()
protection_target = block(contract, "Branch protection — managed fields (target)")
ruleset_target    = block(contract, "Branch-naming ruleset — target creation payload")
label_manifest    = block(contract, "Label rollout manifest (target — create if missing; never touch existing)")
```

### Pattern 2 — protection read-merge-write (inside `repo-standard-diff.sh`, read-only computation)
```python
current = get_or_empty(f"repos/{repo}/branches/main/protection")   # {} if 404 (unprotected)

merged = dict(current)  # start from everything observed
merged["required_pull_request_reviews"] = {
    **current.get("required_pull_request_reviews", {}),
    **protection_target["required_pull_request_reviews"],
}
merged["enforce_admins"] = protection_target["enforce_admins"]
merged["allow_force_pushes"] = protection_target["allow_force_pushes"]
merged["allow_deletions"] = protection_target["allow_deletions"]

detected = [c for c in protection_target["required_status_checks"]["contexts"]
            if workflow_file_exists(repo, c)]                     # e.g. "bump-gate" -> .github/workflows/bump-gate.yml
if detected:
    existing = current.get("required_status_checks", {"strict": False, "contexts": []})
    merged["required_status_checks"] = {
        "strict": existing.get("strict", False),
        "contexts": sorted(set(existing.get("contexts", [])) | set(detected)),
    }
elif "required_status_checks" in current:
    merged["required_status_checks"] = current["required_status_checks"]   # untouched

write_needed = normalize(merged) != normalize(current)
```

### Pattern 3 — labels bulk-create (`repo-standard-apply-labels.sh`, run only with `--confirmed`)
```bash
REPO="${1:?usage: repo-standard-apply-labels.sh OWNER/REPO --confirmed}"
[ "${2:-}" = "--confirmed" ] || { echo "refusing — missing --confirmed (the confirmation gate is the caller's job)" >&2; exit 1; }
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/bot-auth.sh" || exit 1

existing="$(gh label list --repo "$REPO" --json name --jq '.[].name')"
created=0
# manifest rows come from Pattern 1's label_manifest, one TSV line per label
while IFS=$'\t' read -r name color desc; do
  case "$existing" in *"$name"*) echo "  $name: already exists — skipping"; continue ;; esac
  if gh label create "$name" --repo "$REPO" --color "$color" --description "$desc" >/dev/null 2>&1; then
    echo "  + created $name (#$color)"; created=$((created + 1))
  else
    echo "  ! FAILED to create $name" >&2
  fi
done <<<"$MANIFEST_TSV"
echo "repo-standard-apply-labels: $created label(s) created; existing labels untouched."
```

### Pattern 4 — CODEOWNERS empty-vs-history branch
```bash
if gh api "repos/$REPO/commits?per_page=1" >/dev/null 2>&1; then
  # has history -> deterministic branch + PR
  BRANCH="chore/codeowners-hardening"
  if existing_pr="$(gh pr list --repo "$REPO" --head "$BRANCH" --json number,url --jq '.[0]')" && [ -n "$existing_pr" ]; then
    echo "repo-standard-apply-codeowners: already proposed — $(jq -r .url <<<"$existing_pr")"
  else
    # create branch, commit CODEOWNERS, push, gh pr create --draft, request-reviewers.sh
    :
  fi
else
  # empty repo -> Contents API creates the first commit AND the default branch
  gh api --method PUT "repos/$REPO/contents/.github/CODEOWNERS" \
    -f message="chore: add CODEOWNERS (repo hardening)" \
    -f content="$(base64 <<<"* $REVIEWERS_AT")" -f branch="main"
fi
```

### Pattern 5 — `plugin/commands/harden-repo.md` skeleton
```markdown
---
description: Harden a repo to the team standard — branch protection, branch-naming ruleset, CODEOWNERS, label scheme, bot wiring. Read-only verify by default; --apply writes, gated by two human confirmations.
argument-hint: <owner/repo> [--apply] [--reviewers "<login1 login2 ...>"]
---

# /harden-repo — apply the repo-standard contract

Diff `${CLAUDE_PLUGIN_ROOT}/contracts/repo-standard.md` against a target repo and, in
`--apply` mode, bring it into line. Labels and CODEOWNERS run as the bot; Bot-wiring is
report-only; Branch protection + ruleset run under YOUR OWN ambient identity, confirmed
in-session — never the bot.

## Phase A — plan (read-only, always first)
bash "${CLAUDE_PLUGIN_ROOT}/scripts/repo-standard-diff.sh" "<owner/repo>" [--reviewers "..."]
Present the report verbatim. **Verify mode (no `--apply`) stops here.**

## Apply mode only, in order: A2 CODEOWNERS (no gate) -> B Labels (1 confirmation) ->
## Bot wiring (report only, from Phase A) -> C Protection + Ruleset (1 confirmation)
[... exact steps per the Per-sub-step section above ...]

## Final report
One table: sub-step x identity x status. Clean up the plan directory on the way out.
```

---

## Testing Strategy

No GitHub writes happen during design or build (DEFINE constraint) — this maps the design's guarantees to what the composer's later smoke gate exercises for real, against `gear` (AT-1) and `agentic-dev` (AT-2/AT-3). This repo has no unit-test harness for `plugin/scripts/*.sh` (no `tests/`, no `bats`, no shellcheck job — verified, matching the existing three scripts' own precedent); the smoke run is the verification.

| AT | What the design guarantees | How the later smoke verifies it |
|---|---|---|
| AT-1 apply + idempotency | read-merge-write + missing-only creates + deterministic branch names make every sub-step naturally idempotent | `--apply` on `gear` twice; second run's plan shows all `MATCH`, 0 writes |
| AT-2 verify read-only | the diff script contains zero write verbs, structurally | run without `--apply`; before/after `gh api` state byte-compared |
| AT-3 check promotion | contexts computed from workflow-file presence (D5); `agentic-dev` has both files | `--apply` against `agentic-dev`; `gh api .../protection` shows both contexts required |
| AT-4 label safety | ONE confirmation gates the whole batch; script re-checks `gh label list` before every create | confirm once, verify 18 created; re-run confirms 0 created; hand-edit one label first, confirm it survives untouched |
| AT-5 identity boundary | self-sourced `bot-auth.sh` (structural) for labels/CODEOWNERS; never-sourced + login-assertion + inline marker for protection/ruleset (D6) | capture the printed identity lines from both phases in the smoke transcript |
| AT-6 bot-wiring delegation | `bot_wiring.ready` flag drives a report-only path; no script ever calls `setup-bot.sh` or writes credentials | run with creds removed; confirm output names the init steps and creates nothing under `~/.config` |

---

## File Manifest

| # | File | Action | Purpose |
|---|------|--------|---------|
| 1 | `plugin/contracts/repo-standard.md` | Create | The codified contract — protection managed-fields + observed snapshot, ruleset target + observed snapshot, label rollout manifest (colors/descriptions), CODEOWNERS format spec, bot-wiring pointer. Machine-parsed directly by the scripts below (Decision D2). |
| 2 | `plugin/commands/harden-repo.md` | Create | `/harden-repo` entrypoint: arg parsing, Phase A invocation, the two confirmation gates, sequencing of A2/B/C, the final report. Owns the inline (never-scripted) protection/ruleset apply block. |
| 3 | `plugin/scripts/repo-standard-diff.sh` | Create | Phase A: read-only fetch (protection, ruleset, labels, CODEOWNERS, bot-wiring probe, required-check workflow-file probes) + read-merge-write computation + `plan.json`/report rendering. Ambient identity, no bot-auth. |
| 4 | `plugin/scripts/repo-standard-apply-labels.sh` | Create | Phase B: bulk-creates only-still-missing scheme labels; self-sources `bot-auth.sh`; refuses without `--confirmed`. |
| 5 | `plugin/scripts/repo-standard-apply-codeowners.sh` | Create | Phase A2: writes `.github/CODEOWNERS` (direct commit on an empty repo, deterministic branch + draft PR otherwise); self-sources `bot-auth.sh`; calls the existing `request-reviewers.sh` after opening a PR. |
| 6 | `plugin/contracts/README.md` | Modify | Add a `repo-standard.md` row to the Files table (existing convention: every contract file listed there). |
| 7 | `README.md` | Modify | Add a `/agentic-dev:harden-repo` row to the top-level Commands table (established precedent — both `/recommend` and `/needs-me` required this same edit, caught at blind review last time; doing it up front here). |

**Total files:** 7 (5 new, 2 modified). Excluded from this manifest, per DEFINE: `plugin/.claude-plugin/plugin.json` version bump (the composer's step, ADR-0006) and any actual GitHub writes (the composer's smoke gate, run after this build).
