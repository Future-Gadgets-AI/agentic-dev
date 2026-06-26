# Creating the bot's fine-grained PAT

The write skills authenticate as a **machine account** with a **fine-grained personal access token**. Three things decide whether it works on the first try: the **resource owner**, the **permissions**, and (if the org requires it) **approval**.

## The one that bites everyone: Resource owner

A fine-grained PAT can only touch resources owned by its **resource owner**, plus public repos read-only. To write to an **org's** repos, the resource owner MUST be that **org** — not the bot's personal account.

Symptoms of getting it wrong (resource owner left as the personal account):
- `gh api user` works and returns the bot login — so it *looks* fine — yet
- `gh api user/orgs` returns `[]`, and
- every push / PR / issue write returns **403 "Resource not accessible by personal access token"**, and
- the org's **Pending requests** queue stays empty (a personal-owner token never asks the org for anything).

**Resource owner is fixed at creation — it can't be edited.** A wrong one means generating a new token with the org selected.

At the org level (Org → Settings → Personal access tokens → Fine-grained tokens), **"Allow access via fine-grained personal access tokens"** must be enabled or the org blocks them all. If "Require approval" is on, an owner approves the token under **Pending requests** before it works.

## Permissions

Minimum for the write skills — all repository-level (issues, branches, code, PRs, comments):

| Permission | Access | Why |
|---|---|---|
| Contents | Read and write | push commits / branches |
| Issues | Read and write | create / comment / label / close issues |
| Pull requests | Read and write | open / comment / review PRs |
| Metadata | Read | required baseline |

Optional — add only when the bot actually needs it:

| Permission | Access | When |
|---|---|---|
| Workflows | Read and write | **required** to push changes under `.github/workflows/` — those pushes 403 without it, even with Contents:write |
| Commit statuses | Read and write | mark commit state (the PAT-writable alternative to the App-only Checks API) |
| Organization → Projects | Read and write | manage org Project boards (a "project owner" role) |
| Organization → Members | Read | resolve org members to assign work |

**Never grant `Administration`** (repository or organization). It can edit branch protection and rulesets — i.e. it would let the bot remove its own merge restriction. The bot is meant to open PRs and leave merging to a human; keeping `Administration` off is what preserves that boundary. The merge block is enforced by branch protection, not by starving the token of other permissions, so least-privilege here costs nothing.

## Step by step

1. Log into GitHub **as the bot account**.
2. Settings → Developer settings → **Fine-grained tokens** → **Generate new token**.
3. Name it; set an **expiration** (rotation is healthy).
4. **Resource owner → the org** (see above — this is the trap).
5. **Repository access** → the specific repos, or "All repositories".
6. **Permissions** → the table above.
7. **Generate token** and copy it (shown once).
8. If the org requires approval, an owner approves it under Org → Settings → Personal access tokens → **Pending requests**.
9. Hand it to `setup-bot.sh` (SKILL.md Step 3), which verifies and stores it.

## Sanity check before storing

```bash
GH_TOKEN=<new-token> gh api user --jq .login                          # -> the bot login
GH_TOKEN=<new-token> gh api repos/<org>/<repo> --jq .permissions.push  # -> true
```
If the first works but the second is `false` (or 403s), it's the resource-owner / permissions / approval issue above. `setup-bot.sh` makes the same push check and refuses to store a token that can't write — so fix the token first.
