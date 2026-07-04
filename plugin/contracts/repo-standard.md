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
```json
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
```
`required_status_checks` is applied only with whichever of `contexts` has a matching
`.github/workflows/<context>.yml` on the target repo's default branch — see Decision D5.
On a repo with neither present, `required_status_checks` is omitted from the merge (not set
to an empty/impossible requirement). All fields not listed above are preserved verbatim from
the target repo's current live state — never asserted, never overwritten (Decision D4).

## Branch protection — observed live snapshot (agentic-dev, exported 2026-07-04)
```json
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
```
`restrictions` (push scoped to the org's `maintainers` team) and
`required_conversation_resolution` are genuine live settings on the reference repo but are
**not** managed fields here — out of scope for this revision (Decision D4); they show up as
"preserved, unmanaged" in every diff report, never as a target asserted on other repos.

## Branch-naming ruleset — target creation payload
```json
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
```
This full 14-prefix list is the live rule (`git-collaboration`'s branch-naming table lists
only the first five — that table is illustrative prose; this is the codified, complete
source). Applies only when **no** existing ruleset already targets branch creation on the
target repo; if one exists but differs, the diff reports DRIFT and does not modify it
(Decision, Error Handling).

## Branch-naming ruleset — observed live snapshot (agentic-dev, ruleset id 18134296, exported 2026-07-04)
```json
{
  "id": 18134296,
  "name": "branch-naming-convention",
  "target": "branch",
  "enforcement": "active",
  "rules": [{ "type": "creation" }],
  "bypass_actors": [],
  "current_user_can_bypass": "never"
}
```
(conditions omitted here — identical to the target payload above; the live ruleset already
matches the standard being codified, as expected since agentic-dev is the reference repo.)

## Label rollout manifest (target — create if missing; never touch existing)
```json
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
```
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
