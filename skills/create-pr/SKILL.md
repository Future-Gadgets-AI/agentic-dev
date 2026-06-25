---
name: create-pr
description: Turns a feature branch into a pull request addressed to the other person's agent — conventional commit(s), a structured PR body (summary / key changes / test plan / the Issue or ADR it implements), correct branch naming, push with upstream, and gh pr create against main. Use when the user wants to create, open, or raise a PR, finish a feature branch, or ship work for review. Linking the source Issue/ADR is mandatory. The reviewer's protocol is the review-pr skill.
---

# Create PR

Turns work on a **feature branch** into a pull request. The PR is an **A2A message**: the author's agent writes it; the **other person's agent** reads it, runs the tests, and reviews it (see `review-pr`). So write the PR body for a reviewer who has **none of your session context** — and **linking the source Issue/ADR is mandatory** (it carries the acceptance criteria the reviewer checks against).

> **Run as the bot.** Every git/gh action here is attributed to the configured machine account. Begin **each** command block below — branch, commit, push, PR create, reviewer requests — by sourcing the auth helper, which sets the bot's `GH_TOKEN` + commit identity for *that shell only* (so each block must re-source):
> ```bash
> source "${CLAUDE_PLUGIN_ROOT}/scripts/bot-auth.sh" || exit 1
> ```
> **Fail-fast:** if it errors (no creds / wrong account), **STOP** — do not branch, commit, push, or open the PR. A block that *forgets* to source this silently runs as your ambient `gh` login — exactly the wrong-account write to avoid — so never skip it. See `git-collaboration` → **Bot identity**.

## Detect the repo first (never hardcode)

```bash
gh repo view --json nameWithOwner -q .nameWithOwner   # preferred
git remote get-url origin                             # fallback
```

## Step 1 — Branch hygiene

**Never commit straight to `main`.** If you're on `main`, create a feature branch first:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/bot-auth.sh" || exit 1   # act as the bot (see callout)
git checkout -b <type>/<short-kebab-description>
```

Branch type = the conventional-commit type: `feat/` · `fix/` · `chore/` · `docs/` · `refactor/`.
Examples: `feat/oauth-refresh`, `fix/null-date-parse`, `docs/readme-setup`.

## Step 2 — Inspect the change

```bash
git status
git diff --stat
git log origin/main..HEAD --oneline    # commits not yet on main
```

Identify the primary change type and the **scope = the component / area touched** (e.g. `parser`, `api`, `auth`, `cli` — whatever names the part of the codebase this PR changes).

## Step 3 — Conventional commit(s)

`<type>(<scope>): <description>` — present tense, concise (< 72 chars). Keep commits coherent; one concern per PR.

```
feat(parser): add ISO-8601 date support

- handle timezone offsets
- fall back to UTC when offset is absent

Co-Authored-By: Claude <noreply@anthropic.com>
```

Types: `feat` · `fix` · `refactor` · `docs` · `test` · `chore` · `style` · `perf` · `ci` · `build`.
Use the **generic** trailer `Co-Authored-By: Claude <noreply@anthropic.com>` — do not hardcode a specific model name.

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/bot-auth.sh" || exit 1   # bot identity -> commit authored by the bot
git add -A          # or specific files
git commit -m "<message>"
```

## Step 4 — Push with upstream

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/bot-auth.sh" || exit 1   # bot token -> push as the bot
git push -u origin <branch-name>
```

## Step 5 — Build the PR body (write it for the reviewer's agent)

Self-contained — no local paths, no "as we discussed", no private session state. **The "Implements" line is required.**

```markdown
## Summary
<2–3 sentences: what this changes and why. Written for a reviewer with zero shared context.>

## Key changes
- <primary change 1>
- <primary change 2>
- <primary change 3>

## Test plan
- [ ] <how the reviewer verifies it — exact command(s) to run>
- [ ] <case 2>
- [ ] <edge case / regression check>

## Implements
<REQUIRED. Link the source Issue or ADR — e.g. "Closes #123" (auto-closes on merge) or "Implements ADR #45". This carries the acceptance criteria the reviewer checks against. If there is genuinely no tracking issue, say so explicitly and state the acceptance criteria inline.>

## Breaking changes
<Describe, or "None".>

---
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## Step 6 — Create the PR

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/bot-auth.sh" || exit 1   # bot opens the PR
gh pr create \
  --repo REPO \
  --title "<type>(<scope>): <description>" \
  --body-file <body.md> \
  --base main
```

Add `--draft` for work-in-progress, and capture the new PR number for the next step. **Don't** request reviewers via `gh pr create --reviewer` / `gh pr edit --add-reviewer` — `gh` reliably attaches only one of several reviewers (cli/cli #954, #7463), and `--add-reviewer` with a blank handle wipes the whole set (#7721). Use Step 7.

## Step 7 — Request BOTH reviewers (one request each)

Every PR requests **both** configured reviewers — `$AGENTIC_REVIEWERS` (exported by the auth helper; currently `lucasbrandao4770 gustavomoura628`). A single call listing several reviewers reliably attaches only **one** (a `gh` multi-reviewer bug + secondary-rate-limit racing on the batched REST call), so request them **one at a time** via the REST endpoint, space the calls, then read back and surface any miss:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/bot-auth.sh" || exit 1
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
PR=<new PR number>
for r in $AGENTIC_REVIEWERS; do
  gh api -X POST "repos/$REPO/pulls/$PR/requested_reviewers" -f "reviewers[]=$r" >/dev/null \
    || echo "WARN: could not request $r"
  sleep 1   # space the calls — batching/rapid-fire silently drops reviewers
done
got=$(gh pr view "$PR" --repo "$REPO" --json reviewRequests --jq '[.reviewRequests[].login]|sort|join(" ")')
echo "requested: $AGENTIC_REVIEWERS"
echo "attached:  $got"
```

A reviewer attaches only if they already have **repo access** (org team / collaborator) — the call 422s otherwise. If the read-back is missing someone, **say so**; don't quietly ship a half-reviewed PR. (`reviewers[]` takes user logins; teams use a separate `team_reviewers[]` field.)

## Quality checklist

```
COMMIT
[ ] conventional-commits format, type matches the change
[ ] scope = the component/area touched
[ ] description < 72 chars

PR BODY
[ ] Summary explains WHY, self-contained (no shared-context references)
[ ] Implements links the source Issue/ADR  ← mandatory
[ ] Test plan has runnable, verifiable steps
[ ] Breaking changes documented (or "None")

BRANCH
[ ] not committing directly to main
[ ] branch name matches <type>/<desc>
[ ] small PR, one concern (aim < ~400 lines changed)

IDENTITY & REVIEWERS
[ ] every git/gh write ran as the bot (bot-auth sourced; fail-fast, never a personal account)
[ ] both configured reviewers attached — confirmed by read-back
```

The **human does the final merge** — this skill stops at opening the PR.
