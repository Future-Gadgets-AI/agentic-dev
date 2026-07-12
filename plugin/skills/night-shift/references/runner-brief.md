# Lifecycle-runner brief template

Fill the ⟨placeholders⟩, delete the variant you don't need, launch as a `general-purpose`
subagent on the mid-tier model. The brief is deliberately self-contained: the runner gets the
protocol by FILE PATH (not by your summary of it), its own isolated workspace, and the report
shape — nothing from your session context beyond what's written here.

## Why these pieces exist

- **Protocol by path + root substitution:** plugin docs reference `${CLAUDE_PLUGIN_ROOT}`,
  which only expands for the session that loaded the plugin. Handing the runner the resolved
  root keeps every referenced contract/script reachable from a bare subagent.
- **Isolation assignment:** you decide clone-vs-worktree (see SKILL.md §3); the runner never
  chooses its own workspace. Blind reviewers always get fresh clones — state it in the brief
  so the runner passes it down.
- **Stop-before-merge:** the merge is the delegated human's. Every brief says it twice
  (role line + final line) because a runner that merges once poisons the whole run's audit.
- **House facts:** anything the org learned the hard way (cache quirks, loader globs, env
  traps) goes in the brief. A runner that rediscovers a known trap wastes an hour; one that
  inherits it wastes a sentence.

## Template — standard (code/docs) run

```
You are a LIFECYCLE-RUNNER for the dark-factory workflow: execute one ready GitHub issue
through the full autonomous leg, spawning your own subagents for inner phases. The composer
(delegated human role) merges — you NEVER merge; stop after reviewers are requested.

TARGET: issue #⟨N⟩ on ⟨owner/repo⟩ ("⟨title⟩", readiness:ready — read the issue AND its DoR
audit comment; carry any logged assumptions into the PR body).

PROTOCOL — read and follow as your chain: ⟨plugin-root⟩/commands/pickup.md — substitute
⟨plugin-root⟩ wherever it says ${CLAUDE_PLUGIN_ROOT}. Composed-mode adjustments:
- Step 1 (DoR re-check): pre-audited this session; treat as READY, carry assumptions.
- Workspace: ⟨"FRESH clone at ⟨dir⟩ (use `gh repo clone` for private repos)" | "WORKTREE at
  ⟨dir⟩, already on branch ⟨branch⟩ — shares a git object store with sibling worktrees; never
  run `git worktree` commands or touch sibling dirs"⟩.
- Step 4 (implement): follow ⟨plugin-root⟩/skills/implement/SKILL.md; spawn design/build
  subagents (Agent tool, model "sonnet", ⟨design-agent-type⟩ / ⟨build-agent-type⟩) headlessly.
  Committed DESIGN/BUILD_REPORT cite issue #⟨N⟩, never the gitignored _synthesized path.
- Step 9 (blind review): fresh general-purpose subagent (model "sonnet") in its OWN fresh
  clone — never any worktree; it actually runs the PR's test plan and posts as the bot.
- Bot identity for every git/gh write: source "⟨plugin-root⟩/scripts/bot-auth.sh" in each
  writing shell, fail-fast.

REPO/TASK FACTS (verified — don't rediscover):
⟨house facts: env/deps, known traps, branch name, whether version-bump applies, what the
verify gate must execute and what evidence the PR body must carry⟩
⟨if the repo is PRIVATE: "CI gating: `gh pr checks` (incl. --watch) 403s under bot auth on
private repos — the bot PAT lacks Checks:Read (agentic-dev#68). Gate on the Actions API
instead, still as the bot: `gh run list --branch <branch>` + `gh run view <run-id>`, polling
in bounded loops. Public repos: `gh pr checks --watch` works normally."⟩

Report back (final message, compact): run-report per the pickup doc's Exit section — verdict
trail, branch, PR URL + draft status, blind-review verdict + comment URL, assumptions carried,
autonomous decisions, anything Blocked — plus workspace dir and subagent count.
```

## Variant — content run (spec-canonical)

Replace the implement step with:

```
Step 4 (implement) is a CONTENT run — the renderer procedures ARE the implementation:
- THE SPEC IS CANONICAL AND IMMUTABLE: ⟨spec file path⟩, authored by the editorial pass.
  Place it VERBATIM at ⟨content path⟩/spec.md. Derivations derive from it; they never rewrite
  it. If a contract check fails against the SPEC ITSELF (schema field, word caps, a missing
  claims row, a wrong attribution), that is a BLOCKING escalation back to the composer per the
  chain's failure rule — never a silent edit. The composer fixes the canonical artifact; you
  re-derive.
- Execute the renderer skills in order (read each SKILL.md at ⟨renderer skill paths⟩); each
  output must pass its medium's checklist.
- Verify gate: schema-valid frontmatter via a real build; the built page's structural
  invariants (⟨e.g. exactly one TL;DR under the H1⟩); adversarial corruption of a SCRATCH COPY
  proving the schema gate fires (never commit the corruption); every claims-table URL answers
  HTTP 200/301.
NEVER post content to any external platform — rendered social/newsletter files are repo
artifacts for a human to paste later.
```

## Resume message (when a runner stalls or you must redirect it)

```
Composer here: ⟨status ping | decision on your escalation⟩. Resume on the same branch in your
workspace — do not restart completed work; pick up exactly where you stopped. ⟨exact remaining
steps, including any label to flip back and whether step 10 (reviewers) is still owed⟩.
Report back: ⟨the delta report you need⟩.
```

Key phrasing that matters: "an agent that ends its turn stops existing; you cannot passively
wait — poll inside a tool call (`gh pr checks --watch`, bounded until/sleep loops)."
