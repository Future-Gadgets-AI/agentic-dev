# DESIGN: "What needs me?" — cross-repo status report of work awaiting the human

> Technical design for issue #34.

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | ISSUE_34_WHATS_NEEDED_ME |
| **Date** | 2026-07-04 |
| **Author** | design phase (`agentspec:workflow:design`, driven by `/pickup`) |
| **DEFINE** | [`.claude/sdd/_synthesized/DEFINE_ISSUE_34_WHATS_NEEDED_ME.md`](../_synthesized/DEFINE_ISSUE_34_WHATS_NEEDED_ME.md) |
| **Status** | Ready for Build |

---

## Architecture Overview

```text
┌──────────────────────────────────────────────────────────────────┐
│ /needs-me   (plugin/commands/needs-me.md)                        │
│   thin entrypoint: run the script, present its stdout verbatim   │
└─────────────────────────────┬──────────────────────────────────--┘
                               │ invokes (human's own ambient `gh` auth)
                               ▼
┌────────────────────────────────────────────────────────────────--┐
│ plugin/scripts/needs-me.sh          [no bot-auth.sh — human only]│
│                                                                    │
│  1. resolve OWNER  ← gh repo view --json owner   (or $1 override) │
│  2. parse GITHUB_LOGIN / AGENTIC_REVIEWERS out of the credentials │
│     file with grep+sed  (never `source` it — GITHUB_PAT untouched)│
│  3. one `gh search prs --owner OWNER --review-requested <r>`      │
│     per configured human reviewer  → group 1                      │
│  4. one `gh search issues --owner OWNER --label <L>` per label    │
│     → groups 2–5 (2 calls for group 5's two mutually-exclusive    │
│     labels — see Decision 3)                                      │
│  5. inline python3: union + dedupe by url, drop items assigned    │
│     solely to GITHUB_LOGIN, compute age, render grouped Markdown  │
└─────────────────────────────┬──────────────────────────────────--┘
                               │ read-only REST/Search API calls
                               ▼
                     GitHub (issues + PRs across every repo
                     owned by OWNER the human's token can see)
```

---

## Components

| Component | Purpose | Technology |
|-----------|---------|------------|
| `plugin/commands/needs-me.md` | `/needs-me` entrypoint — frontmatter + instructions to run the script and present its output | Claude Code command (Markdown) |
| `plugin/scripts/needs-me.sh` | All GitHub queries, filtering, dedup, and Markdown rendering | bash + `gh` + inline `python3` |
| `~/.config/agentic-dev/credentials` (existing, not created by this feature) | Source of `GITHUB_LOGIN` (excluded) and `AGENTIC_REVIEWERS` (the human set) | plain `KEY=VALUE` file, per `setup-bot.sh` |

No new persistent configuration file is introduced — this reads the config that `bot-auth.sh` already establishes, through a narrower lens.

---

## Key Decisions

### Decision 1: Runs as the human; reads identity config without `bot-auth.sh`

**Context:** `bot-auth.sh` unconditionally exports `GH_TOKEN` = the bot's PAT, runs `gh auth setup-git` (mutates the git credential helper), and asserts the bot identity. This command is read-only and must reflect the invoking human's own visibility/permissions — it must never risk acting as the bot.

**Choice:** parse only the `GITHUB_LOGIN=` and `AGENTIC_REVIEWERS=` lines out of the credentials file with `grep`+`sed` — the same extraction technique `setup-bot.sh` already uses to pull `GITHUB_PAT` out of a `.env` file without echoing it. Never `source` the credentials file, so `GITHUB_PAT` is never loaded into this script's process at all.

**Rationale:** smallest possible exposure of the bot secret; this script has no legitimate use for `GITHUB_PAT`.

**Alternatives Rejected:**
1. `source` the whole credentials file — rejected: pulls the bot PAT into a script whose entire premise is "never the bot," one accidental `export GH_TOKEN=$GITHUB_PAT` away from a silent wrong-identity bug.
2. Require `AGENTIC_REVIEWERS`/`GITHUB_LOGIN` as command-line flags — rejected: breaks the zero-config "just run it" precedent `bot-auth.sh`/`request-reviewers.sh` already set.

**Consequences:** one small extraction helper; zero bot-secret exposure surface; degrades gracefully (see Error Handling) if the credentials file doesn't exist on a machine that never configured a bot.

---

### Decision 2: Cross-repo aggregation via `gh search`, not per-repo enumeration

**Context:** the naive approach — `gh repo list OWNER` then loop `gh issue list --repo` per repo — is O(repos) calls and re-implements GitHub's own search index.

**Choice:** use `gh search prs --owner OWNER` / `gh search issues --owner OWNER` — both search across every repo owned by `OWNER` the token can see, in one call per query.

**Rationale:** empirically verified live against `Future-Gadgets-AI` during design (see Smoke evidence in the build report) — one call returns cross-repo results directly, satisfying acceptance criterion 6 (multi-repo aggregation) with no enumeration step.

**Alternatives Rejected:** per-repo enumeration + loop — strictly more calls and complexity for an identical result.

**Consequences:** relies on GitHub's search index (eventually consistent — acceptable for a status digest, not a system of record).

---

### Decision 3: One `gh` call per reviewer / per label — union + dedupe after, never combined

**Context:** `--review-requested` takes a single user. `--label` flags repeat but **AND** together — empirically confirmed: `--label "readiness:draft" --label "readiness:needs-refinement"` returns zero results, since `readiness:` is single-valued per issue (labels.md: "exactly one `readiness:` per issue"). So OR-shaped groups (multiple human reviewers; draft-OR-needs-refinement) cannot be expressed as one call.

**Choice:** loop once per reviewer login (group 1) and issue two calls for group 5's two labels; collect each call's JSON array separately, then union + de-duplicate by `url` before rendering.

**Rationale:** avoids a silent-wrong-results bug (reading AND where OR was intended) that would under-report exactly what the acceptance criteria check for.

**Consequences:** N+1 `gh` calls instead of 1 for those two groups — negligible at this scale (a handful of reviewers/labels).

---

### Decision 4: Bot exclusion is structural, plus one uniform assignee safety filter

**Context:** acceptance criterion 3 — the automation account must never appear as "needs you," including "an issue addressed only to it."

**Choice:**
(a) **Structural:** group 1 only ever queries human logins (`AGENTIC_REVIEWERS` / `@me` fallback) — never the bot's — so a PR requested only from the bot cannot match by construction.
(b) **Safety net:** every group's `--json` fields include `assignees`; a uniform filter drops any item whose `assignees` list is non-empty **and** consists solely of `GITHUB_LOGIN`. An empty `assignees` list is kept (default: unassigned escalations are for the human).

**Rationale:** (a) alone covers review-requests; (b) generalizes the same guarantee to the assignee-based reading of "addressed only to it," applied once and reused by every group rather than special-cased per group.

**Consequences:** one extra JSON field + one small, shared filter function.

---

### Decision 5: Packaging — thin command + a bundled script (not prose-only)

**Context:** ADR-0005 puts the entrypoint/orchestration role on `commands/`. The actual GitHub-query logic is exactly the kind of multi-call, loop-sensitive logic this repo already extracts into a script rather than writing inline (`request-reviewers.sh`'s own rationale: zsh doesn't word-split `for r in $VAR`, so a bash script is the safe, portable form).

**Choice:** `plugin/commands/needs-me.md` is thin — frontmatter + a few lines telling Claude to run the script and present its stdout. `plugin/scripts/needs-me.sh` carries all the logic, independently invocable and smokeable from a plain shell, no LLM in the loop.

**Alternatives Rejected:** all-logic-inline in the command body — rejected: no word-splitting safety, not standalone-testable, breaks the established precedent.

---

## File Manifest

| # | File | Action | Purpose | Dependencies |
|---|------|--------|---------|--------------|
| 1 | `plugin/scripts/needs-me.sh` | Create | All `gh` queries, filtering, dedup, Markdown rendering | None |
| 2 | `plugin/commands/needs-me.md` | Create | `/needs-me` entrypoint | 1 |

**Total Files:** 2

No test file: this repo has no unit-test harness for its `plugin/scripts/*.sh` files (checked — no `tests/`, no `bats`, no shellcheck CI job; the three existing scripts are verified the same way). Verification here is the smoke gate: a real invocation against live GitHub state, captured as a transcript (see Testing Strategy).

---

## Code Patterns

### Pattern 1: Identity extraction without sourcing the credentials file

```bash
CFG="${AGENTIC_DEV_CONFIG_DIR:-$HOME/.config/agentic-dev}/credentials"
_extract() {  # <KEY> — prints the value, or nothing if absent
  [ -f "$CFG" ] || return 0
  grep -E "^[[:space:]]*$1[[:space:]]*=" "$CFG" | tail -1 \
    | sed -E "s/^[^=]*=[[:space:]]*//; s/^[\"']//; s/[\"']\$//"
}
BOT_LOGIN="$(_extract GITHUB_LOGIN)"
REVIEWERS="$(_extract AGENTIC_REVIEWERS)"
if [ -z "$REVIEWERS" ]; then
  ME="$(gh api user --jq .login 2>/dev/null || echo "@me")"
  echo "needs-me: no AGENTIC_REVIEWERS configured — checking only $ME." >&2
  REVIEWERS="$ME"
fi
```

### Pattern 2: Owner resolution + the five query groups

```bash
OWNER="${1:-$(gh repo view --json owner -q .owner.login 2>/dev/null)}"
[ -n "$OWNER" ] || { echo "needs-me: could not resolve an owner; pass one: needs-me.sh OWNER" >&2; exit 1; }

FIELDS="number,title,url,repository,createdAt,assignees"

# Group 1 — needs your review: one call per human reviewer, capture each separately
mkdir -p "$TMP/reviews"
i=0
for r in $REVIEWERS; do
  gh search prs --owner "$OWNER" --state open --review-requested "$r" \
    --json "$FIELDS" > "$TMP/reviews/$i.json" 2>"$TMP/reviews/$i.err" \
    || { echo "[]" > "$TMP/reviews/$i.json"; echo "needs-me: WARN review-request query for $r failed" >&2; }
  i=$((i + 1))
done

# Groups 2–5 — one label each (group 5 = two calls, unioned downstream)
gh search issues --owner "$OWNER" --state open --label "status:needs-decision"      --json "$FIELDS" > "$TMP/decisions.json"  2>/dev/null || echo "[]" > "$TMP/decisions.json"
gh search issues --owner "$OWNER" --state open --label "phase:in-progress"          --json "$FIELDS" > "$TMP/inprogress.json" 2>/dev/null || echo "[]" > "$TMP/inprogress.json"
gh search issues --owner "$OWNER" --state open --label "readiness:ready"            --json "$FIELDS" > "$TMP/ready.json"      2>/dev/null || echo "[]" > "$TMP/ready.json"
gh search issues --owner "$OWNER" --state open --label "readiness:draft"            --json "$FIELDS" > "$TMP/draft_a.json"    2>/dev/null || echo "[]" > "$TMP/draft_a.json"
gh search issues --owner "$OWNER" --state open --label "readiness:needs-refinement" --json "$FIELDS" > "$TMP/draft_b.json"    2>/dev/null || echo "[]" > "$TMP/draft_b.json"
```

### Pattern 3: Union + dedupe + bot-assignee filter + age + render (inline `python3`, matching `bump.sh`'s convention of bash-orchestrates / python3-handles-JSON)

```python
# invoked as: python3 - "$BOT_LOGIN" "$TMP" <<'PY'
import json, sys, glob
from datetime import datetime, timezone

bot_login, tmp = sys.argv[1], sys.argv[2]

def load(path):
    try:
        return json.load(open(path))
    except (FileNotFoundError, json.JSONDecodeError):
        return []

def is_bot_only(item):
    assignees = item.get("assignees") or []
    return bool(assignees) and all(a.get("login") == bot_login for a in assignees)

def union(*paths):
    by_url = {}
    for p in paths:
        for item in load(p):
            if not is_bot_only(item):
                by_url[item["url"]] = item
    return sorted(by_url.values(), key=lambda i: i["createdAt"])  # oldest-waiting first

def age(iso):
    dt = datetime.fromisoformat(iso.replace("Z", "+00:00"))
    days = (datetime.now(timezone.utc) - dt).days
    return f"{days}d ago" if days >= 1 else "<1d ago"

def render(title, items):
    lines = [f"## {title} ({len(items)})"]
    if not items:
        lines.append("_none._")
    for i in items:
        repo = i["repository"]["nameWithOwner"]
        lines.append(f"- [{repo}#{i['number']}]({i['url']}) — {i['title']} _{age(i['createdAt'])}_")
    return "\n".join(lines) + "\n"

groups = [
    ("Needs your review",   union(*glob.glob(f"{tmp}/reviews/*.json"))),
    ("Needs your decision", union(f"{tmp}/decisions.json")),
    ("In progress",         union(f"{tmp}/inprogress.json")),
    ("Ready to pull",       union(f"{tmp}/ready.json")),
    ("Drafts to refine",    union(f"{tmp}/draft_a.json", f"{tmp}/draft_b.json")),
]
print(f"# What needs you — {datetime.now(timezone.utc):%Y-%m-%d %H:%M UTC}\n")
for title, items in groups:
    print(render(title, items))
```

### Pattern 4: `plugin/commands/needs-me.md` skeleton

```markdown
---
description: Cross-repo digest of everything waiting on you — reviews, decisions, in-progress work, ready-to-pull issues, and drafts to refine
---

# /needs-me — what needs the human right now

Read-only. Runs as **you** (your own `gh` auth) — never the bot; makes no writes.

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/needs-me.sh"` and present its stdout verbatim as the reply — it is already a complete, grouped Markdown digest.
```

---

## Data Flow

```text
1. /needs-me invoked
   │
   ▼
2. needs-me.sh resolves OWNER (gh repo view, or $1 override)
   │
   ▼
3. parse GITHUB_LOGIN / AGENTIC_REVIEWERS from the credentials file (no source)
   │
   ▼
4. 1 gh search prs call per human reviewer  +  4 gh search issues calls (5 total: 1 status:needs-decision, 1 phase:in-progress, 1 readiness:ready, 2 readiness:draft|needs-refinement)
   │
   ▼
5. inline python3: union + dedupe by url per group, drop bot-only-assignee items, compute age
   │
   ▼
6. render one grouped Markdown digest → stdout
   │
   ▼
7. command presents it verbatim to the human
```

---

## Error Handling

| Error Type | Handling Strategy | Retry? |
|------------|-------------------|--------|
| Credentials file absent (bot never configured on this machine) | `AGENTIC_REVIEWERS` empty → fall back to the authenticated caller (`gh api user`) with a stderr note; script still runs | No |
| A single `gh search` call fails (network blip, rate limit) | Treat that call's group/reviewer-slice as empty (`[]`), print a `WARN` to stderr naming which query failed; other groups still render | No — surfaced, not retried |
| `gh` not authenticated at all | Let the first `gh` call's native error surface and exit non-zero — no bespoke wrapping | No |
| Owner cannot be resolved (not in a repo, no `$1`) | Fail fast with a one-line usage message | No |

---

## Configuration

| Config Key | Type | Default | Description |
|------------|------|---------|-------------|
| `$1` (positional) | string | auto-detected via `gh repo view` | Override the owner (org or user login) to scope the search to |
| `AGENTIC_DEV_CONFIG_DIR` | string (env) | `~/.config/agentic-dev` | Where to look for the `credentials` file (matches `bot-auth.sh`) |

---

## Security Considerations

- Never loads `GITHUB_PAT` (the bot secret) into this script's environment — only `GITHUB_LOGIN`/`AGENTIC_REVIEWERS` are extracted, by line-parsing, not sourcing (Decision 1).
- Never calls `gh auth setup-git` or exports `GH_TOKEN` — runs strictly under the invoking human's own ambient `gh` session, so results are naturally scoped to what that human can already see (no privilege escalation, no cross-account leakage).
- Read-only by construction: every call is `gh search prs`/`gh search issues`/`gh repo view`/`gh api user` — no `edit`, `comment`, `merge`, or `create` verb appears anywhere in the script.

---

## Testing Strategy

| Test Type | Scope | Tools | Notes |
|-----------|-------|-------|-------|
| Smoke (real) | Full script, live `gh` calls against `Future-Gadgets-AI/agentic-dev` | shell, real `gh` | This repo has no unit-test harness for `plugin/scripts/*.sh` (verified: no `tests/`, no `bats`, no shellcheck CI job) — the smoke run **is** the verification, per the repo's existing convention for `bot-auth.sh` / `request-reviewers.sh` / `bump.sh`. |
| No-writes check | Before/after state diff on a real issue+PR | `gh issue view` / `gh pr view` label+comment capture | Directly proves acceptance criterion 4. |
| Empty-group check | Point at an owner/label combination known to have zero matches | live `gh` | Proves "empty group shown as empty or omitted, never an error" (acceptance criterion 5). |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-07-04 | design phase (`agentspec:workflow:design`) | Initial version |

---

## Next Step

**Ready for:** build phase (`agentspec:workflow:build`) on this file.
