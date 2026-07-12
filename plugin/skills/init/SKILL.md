---
name: init
description: One-time onboarding for the agentic-dev plugin — wire up the bot machine account so the write skills (create-pr, create-issue, publish-issue, fix-bug, a2a-workflow) can act as it. Use this whenever someone installs the plugin and needs to configure the bot, the first time an autonomous GitHub write is attempted, when "gh api user works but push/PR/issue calls 403", when bot-auth reports missing or wrong credentials, or whenever a user asks how to set up, initialize, onboard, or configure agentic-dev or its bot token. Guides creating a fine-grained PAT from scratch (correct resource owner + permissions) OR wiring an existing one, then runs setup-bot.sh to verify and store it.
---

# Initialize agentic-dev (bot setup)

The plugin's **write** skills (`create-pr`, `create-issue`, `publish-issue`, `fix-bug`, `a2a-workflow`) attribute every GitHub action to a **machine account** — not the user's personal `gh` login — by sourcing `scripts/bot-auth.sh`, which reads a fine-grained token. That helper is **fail-fast**: if the bot's credentials aren't set up, the write skills stop rather than quietly writing as the user. This skill is what makes them stop failing — it gets the bot's token **created → verified → stored**, once.

Storage and runtime auth are already handled by the bundled scripts. Your job here is the part a script can't do: **guide the human**, run the scripts with the right values, and turn any failure back into a concrete fix. Don't reimplement `setup-bot.sh` or `bot-auth.sh`.

> **This flow is generic.** Ask the user for *their* bot login, org, repo, and reviewers — different installs use different ones. Never hardcode an account or org into the conversation.

## Step 0 — Preflight

```bash
gh --version          # the transport for every GitHub call — must be installed
gh auth status        # the human must be logged in to create the PAT in Step 2
```
If `gh` is missing, stop and point them to https://cli.github.com — nothing else works without it.

**Already configured?** If credentials exist, offer to *verify* (re-probe — useful after a token expires) instead of overwriting:
```bash
ls -l "${AGENTIC_DEV_CONFIG_DIR:-$HOME/.config/agentic-dev}/credentials" 2>/dev/null \
  && echo "already configured — re-running setup overwrites it"
```
> Read paths also accept the deprecated `AGENTIC_DEV_CONFIG` (a full file path) as a fallback — see `bot-auth.sh`, `needs-me.sh`, `repo-standard-diff.sh`, and `harden-repo.md`'s CFG snippets. This probe and `setup-bot.sh`'s write path stay canonical-only (`AGENTIC_DEV_CONFIG_DIR`).

## Step 1 — Gather the details (ask first)

These are per-team, which is exactly why they're asked, not hardcoded:

| Value | What it is |
|---|---|
| **bot login** | the machine account that should author writes |
| **org** | the GitHub org that **owns the repos** — becomes the token's *resource owner* (the #1 trap; see Step 2B) |
| **probe repo** | one `OWNER/REPO` the bot must be able to push to — used to prove the token truly works |
| **reviewers** | space-separated logins requested on every PR (usually the human teammates) |

## Step 2 — Token: wire an existing one, or create one?

### A — They already have the bot's PAT
Put it in a file as `GITHUB_PAT=<token>` (any path — it does **not** need to live in a repo), then go to **Step 3** with `--from-env <that-file>`. Or pass it inline with `--token` to avoid writing a file.

### B — Create a fine-grained PAT from scratch
This is where people lose an afternoon, so walk it carefully. **Read `references/fine-grained-pat.md`** and guide the user through it. The essentials:

1. Log into GitHub **as the bot account** (not the user's own).
2. Settings → Developer settings → **Fine-grained tokens** → Generate new token.
3. **Resource owner = the org**, *not* the bot's personal account. ← the trap: a personal-owner token authenticates fine and reads public repos, but **every org write 403s** and it never appears in the org's approval queue.
4. Repository access → the repos (or All).
5. Permissions → **Contents: RW, Issues: RW, Pull requests: RW, Metadata: R** (the minimum). The reference lists optional extras and the **never-grant** list.
6. Generate. If the org requires approval, an owner approves it (Org → Settings → Personal access tokens → Pending requests).

Then go to **Step 3**.

## Step 3 — Verify + store (the bundled script)

`setup-bot.sh` checks the token resolves to the expected login, **probes that it can actually push** (catching the trap above), derives the commit identity, and stores everything `chmod 600` at `~/.config/agentic-dev/credentials` — **outside any repo**, so there's nothing to accidentally commit. It never prints the token.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-bot.sh" \
  --from-env   <file-with-GITHUB_PAT> \
  --login      <bot-login> \
  --probe-repo <org>/<repo> \
  --reviewers  "<reviewer logins>"
```

Pass the Step 1 values **explicitly** — that keeps the flow correct for any install rather than leaning on the script's built-in defaults.

## Step 4 — If verification fails

`setup-bot.sh` prints the reason; map it to the fix:

- **"token resolves to '<x>' but expected '<bot>'"** → wrong account's PAT — or pass `--login <x>` if `<x>` is actually the intended account.
- **"cannot push to <repo>"** → the resource-owner / approval / permissions trap. Fix the token per `references/fine-grained-pat.md` (recreate it if the resource owner is wrong — that field can't be edited), then re-run Step 3.
- **"invalid or expired"** → generate a fresh token.

## Step 5 — Confirm the wiring

A non-destructive identity check that sources the very helper the write skills use:
```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/bot-auth.sh" && echo "bot ready"
```
If it prints `acting as <bot> ✓`, the write skills are good to go. Then explain, plainly:

- **Writes run as the bot, fail-fast.** `create-pr` / `publish-issue` / `fix-bug` / etc. re-source `bot-auth.sh` in each command block; if creds go missing or a token expires they **stop with an error** rather than writing as the user. Re-run this skill to fix.
- **`review-pr` stays you.** A review is your own act, so it uses your personal `gh` identity — by design.
- **The human merges.** The bot opens and pushes; merging is a human step.

Full protocol: `git-collaboration` → **Bot identity**.

## Notes

- **Token hygiene:** fine-grained, least-privilege (see the reference), with an expiry. Rotate by re-running this skill; revoke instantly from the bot's settings if it leaks.
- **Cross-platform:** the scripts are `bash` and `chmod` the creds file — they run on macOS/Linux and under Git Bash / WSL on Windows. The token itself is platform-agnostic.
