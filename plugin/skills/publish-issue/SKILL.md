---
name: publish-issue
description: Publishes and curates a drafted issue or ADR on the current repo's GitHub via gh, with guardrails — dynamic repo detection, dedup check, self-containment lint, label validation against the live repo (human-in-the-loop to create any missing label, never auto-create), native parent/sub-issue relationships, assignees for ownership, and close-never-delete curation. Use when the user wants to post or publish a drafted issue/ADR (from create-issue or create-adr), apply labels, set a parent/sub-issue, assign an owner, or close/curate old issues.
---

# Publish Issue

Writes to the **current repo's** board safely and best-practice: **publishes** a drafted issue or ADR and **curates** the board (close / relabel / relate). One responsibility — *hygienic mutation of the board*. Authoring is `create-issue` / `create-adr`; here it's the `gh` write with guardrails. The label scheme and A2A principles live in `git-collaboration`.

## Detect the repo first (never hardcode)

```bash
gh repo view --json nameWithOwner -q .nameWithOwner   # preferred → use as REPO
git remote get-url origin                             # fallback
```

Use the detected `nameWithOwner` as `--repo` in every command below. These skills work in **any** repo.

## Guardrails — pre-flight before opening a new issue

ALWAYS run, in this order:

1. **Dedup — "does it already exist?"** `gh issue list --repo REPO --search "<topic terms>" --state all`. If an issue already covers the topic → **don't open a duplicate**: comment on / update the existing one, or open the new one as a **sub-issue** of it.
2. **Self-containment lint** — does the body avoid leaking context (`src/…` / `/Users/…` paths, references to private session state, references to the author's own numbered notes that collide with a real `#NN`, internal nicknames/codenames)? Would the **other person's agent**, with no shared context, understand it on its own? (See `git-collaboration`.)
3. **Best-practice** — does it follow the type's template? `[TYPE] …` title? **No** `> **Labels:**` line in the body?
4. **Do the labels exist?** Validate against the live repo (`gh label list --repo REPO`) before applying. If a label from the scheme does **not** exist in the repo, **do NOT create it automatically** — **surface it to the user and ask for explicit confirmation** (human-in-the-loop) before creating it (`gh label create`). Never apply a phantom label, nor create/alter a label without human sign-off. Automatic label creation is exactly the kind of silent board mutation to avoid.

## Publish — flow

**First, act as the bot.** In the shell that runs the `gh` *writes* in this skill — `issue create` / `edit` / `close` (here and in **Curate** below) and the human-approved `label create` — source the auth helper so they're attributed to the machine account:
```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/bot-auth.sh" || exit 1
```
**Fail-fast:** if it can't assume the bot, **STOP** — never publish or curate under a personal account. (The dedup / `gh label list` *reads* in the guardrails don't need it.) See `git-collaboration` → **Bot identity**.

1. Guardrails above.
2. `gh issue create --repo REPO --title "[TYPE] <title>" --body-file <draft.md>` → save the URL / number.
3. **Canonical labels** (validated in step 4): `gh issue edit <n> --repo REPO --add-label "type:<x>,priority:<p>"`. Add `status:blocked` / `status:needs-decision` only when applicable.
4. **Ownership = assignee** (when someone is actually going to work it), not a label: `gh issue edit <n> --repo REPO --add-assignee <user>` (use the handles configured for your project — see `git-collaboration` for the convention).
5. **Parent / sub-issue = GitHub native relationship**, never `Parent: #21` in the body. Use GitHub's sub-issue feature (in the UI, or `gh` sub-issue commands / the API where available) to attach a task/bug/spike under its parent feature or epic, or an ADR-implementing task under its ADR.

### ADRs specifically
An ADR publishes exactly like an issue, with `--label type:adr`. The canonical ADR number is the **issue number** assigned here — update the draft's `ADR-XXX` to match once known.

## Curate — close, NEVER delete

**Rule:** close > delete. Deleting is permanent, admin-only, and destroys history + cross-refs. Closing as `not planned` / duplicate, with a one-line comment pointing to the canonical issue, preserves the trail and stays searchable. Delete only pure garbage with no recorded decision — and even then, closing is safer.

- Superseded / duplicate: `gh issue close <n> --repo REPO --reason "not planned" --comment "Superseded by #<canonical> — <one-line reason>."`
- Relabel / curation: `gh issue edit <n> --repo REPO --add-label / --remove-label …`.
- A `Rejected` ADR is **closed, not deleted** — it stays on record so the idea isn't re-litigated.

## DOs / DON'Ts

**DO:** detect the repo dynamically · run the dedup before opening · close-with-pointer · apply a **validated** label · assignee for ownership · native sub-issue for parent · one topic per issue.

**DON'T:** hardcode a repo · open a duplicate · **delete** an issue · manual parent mention in the body · `> **Labels:**` line in the body · leak context · apply a label that doesn't exist in the repo · **auto-create a missing label** (ask the human first).
