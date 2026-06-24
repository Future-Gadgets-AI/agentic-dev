---
name: create-pr
description: Turns a feature branch into a pull request addressed to the other person's agent — conventional commit(s), a structured PR body (summary / key changes / test plan / the Issue or ADR it implements), correct branch naming, push with upstream, and gh pr create against main. Use when the user wants to create, open, or raise a PR, finish a feature branch, or ship work for review. Linking the source Issue/ADR is mandatory. The reviewer's protocol is the review-pr skill.
---

# Create PR

Turns work on a **feature branch** into a pull request. The PR is an **A2A message**: the author's agent writes it; the **other person's agent** reads it, runs the tests, and reviews it (see `review-pr`). So write the PR body for a reviewer who has **none of your session context** — and **linking the source Issue/ADR is mandatory** (it carries the acceptance criteria the reviewer checks against).

## Detect the repo first (never hardcode)

```bash
gh repo view --json nameWithOwner -q .nameWithOwner   # preferred
git remote get-url origin                             # fallback
```

## Step 1 — Branch hygiene

**Never commit straight to `main`.** If you're on `main`, create a feature branch first:

```bash
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
git add -A          # or specific files
git commit -m "<message>"
```

## Step 4 — Push with upstream

```bash
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
gh pr create \
  --repo REPO \
  --title "<type>(<scope>): <description>" \
  --body-file <body.md> \
  --base main
```

Add `--draft` for work-in-progress. Optionally `--assignee` / `--reviewer <other-user>` (`lucasbrandao4770` / `gustavomoura628`) to route it to the other person.

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
```

The **human does the final merge** — this skill stops at opening the PR.
