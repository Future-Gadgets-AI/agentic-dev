#!/usr/bin/env bash
# needs-me.sh [OWNER] — cross-repo digest of everything waiting on the human.
#
# Runs as the INVOKING HUMAN's own `gh` auth — never the bot. This script
# reads only GITHUB_LOGIN (the automation account, excluded from every
# heading below) and AGENTIC_REVIEWERS (the recognized human reviewer set)
# out of the bot's credentials file; it never `source`s that file, so the
# bot PAT (GITHUB_PAT) is never loaded into this process. See DESIGN
# Decision 1 (.claude/sdd/features/DESIGN_ISSUE_34_WHATS_NEEDED_ME.md).
#
# Read-only, always: every call below is `gh search` / `gh repo view` /
# `gh api user` — no edit/comment/merge/create verb appears anywhere here.
#
# Cross-repo aggregation uses `gh search prs`/`gh search issues --owner`,
# which search every repo OWNER's token can see in one call (DESIGN
# Decision 2) — not a per-repo enumeration loop.
#
# Five groups, ordered "needs you now" -> "state of the line":
#   1. Needs your review   — open PRs requesting review from a human
#   2. Needs your decision — issues labelled status:needs-decision
#   3. In progress          — issues labelled phase:in-progress
#   4. Ready to pull        — issues labelled readiness:ready
#   5. Drafts to refine     — issues labelled readiness:draft or
#                             readiness:needs-refinement
#
# Group 1 needs one call per human reviewer (`--review-requested` takes a
# single user) and group 5 needs one call per label — `--label` flags
# repeat but AND together (empirically confirmed: readiness: is
# single-valued per issue, so two `--label` values return zero results).
# Each call's JSON array is collected separately and unioned + deduped by
# `url` downstream (DESIGN Decision 3) — never combined into one call.
#
# This file has a bash shebang, so executing it always runs under bash
# regardless of the caller's login shell — `for r in $REVIEWERS` word-splits
# correctly here even though it would silently misbehave if this logic were
# inlined into a zsh session instead (same reasoning as request-reviewers.sh).
set -uo pipefail

usage() {
  cat <<'EOF'
usage: needs-me.sh [OWNER]

Cross-repo digest of everything waiting on the human: open PRs requesting
your review, escalated issues (status:needs-decision), in-progress work
(phase:in-progress), ready-to-pull issues (readiness:ready), and drafts
needing refinement (readiness:draft / readiness:needs-refinement).

  OWNER   Org or user login to scope the search to.
          Defaults to the owner of the current repo (gh repo view).

Read-only. Runs as your own `gh` auth — never the bot identity.
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

OWNER="${1:-}"
if [ -z "$OWNER" ]; then
  OWNER="$(gh repo view --json owner -q .owner.login 2>/dev/null)" || OWNER=""
fi
if [ -z "$OWNER" ]; then
  echo "needs-me: could not resolve an owner — pass one explicitly: needs-me.sh OWNER" >&2
  usage >&2
  exit 1
fi

# --- identity config: parse only the two keys we need, never source the file ---
CFG="${AGENTIC_DEV_CONFIG_DIR:-$HOME/.config/agentic-dev}/credentials"
_extract() {  # <KEY> — prints the value, or nothing if the file/key is absent
  local key="$1"
  [ -f "$CFG" ] || return 0
  grep -E "^[[:space:]]*${key}[[:space:]]*=" "$CFG" 2>/dev/null | tail -1 \
    | sed -E 's/^[^=]*=[[:space:]]*//; s/^["'\'']//; s/["'\'']$//'
}
BOT_LOGIN="$(_extract GITHUB_LOGIN)"
REVIEWERS="$(_extract AGENTIC_REVIEWERS)"

if [ -z "$REVIEWERS" ]; then
  ME="$(gh api user --jq .login 2>/dev/null)" || ME=""
  if [ -z "$ME" ]; then
    echo "needs-me: no AGENTIC_REVIEWERS configured and 'gh api user' failed — cannot resolve a reviewer to check. Are you logged in ('gh auth status')?" >&2
    exit 1
  fi
  echo "needs-me: no AGENTIC_REVIEWERS configured — checking only the invoking account ($ME) for review requests." >&2
  REVIEWERS="$ME"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FIELDS="number,title,url,repository,createdAt,assignees"

# --- Group 1: needs your review — one call per human reviewer ---
mkdir -p "$TMP/reviews"
i=0
for r in $REVIEWERS; do
  if ! gh search prs --owner "$OWNER" --state open --review-requested "$r" \
        --json "$FIELDS" >"$TMP/reviews/$i.json" 2>"$TMP/reviews/$i.err"; then
    echo "[]" >"$TMP/reviews/$i.json"
    echo "needs-me: WARN review-request query for '$r' failed: $(tail -1 "$TMP/reviews/$i.err")" >&2
  fi
  i=$((i + 1))
done

# --- Groups 2-5: one label each (group 5 = two calls, unioned downstream) ---
_search_label() {  # <label> <out-file>
  local label="$1" out="$2"
  local err="$out.err"
  if ! gh search issues --owner "$OWNER" --state open --label "$label" \
        --json "$FIELDS" >"$out" 2>"$err"; then
    echo "[]" >"$out"
    echo "needs-me: WARN query for label '$label' failed: $(tail -1 "$err")" >&2
  fi
}
_search_label "status:needs-decision"        "$TMP/decisions.json"
_search_label "phase:in-progress"            "$TMP/inprogress.json"
_search_label "readiness:ready"              "$TMP/ready.json"
_search_label "readiness:draft"              "$TMP/draft_a.json"
_search_label "readiness:needs-refinement"   "$TMP/draft_b.json"

# --- Union + dedupe + bot-assignee filter + age + render ---
python3 - "$BOT_LOGIN" "$TMP" "$OWNER" <<'PY'
import glob
import json
import sys
from datetime import datetime, timezone

bot_login, tmp, owner = sys.argv[1], sys.argv[2], sys.argv[3]


def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return []


def is_bot_only(item):
    assignees = item.get("assignees") or []
    if not assignees or not bot_login:
        return False
    return all(a.get("login") == bot_login for a in assignees)


def union(*paths):
    by_url = {}
    for p in paths:
        for item in load(p):
            if not is_bot_only(item):
                by_url[item["url"]] = item
    return sorted(by_url.values(), key=lambda i: i["createdAt"])  # oldest-waiting first


def age(iso):
    dt = datetime.fromisoformat(iso.replace("Z", "+00:00"))
    delta = datetime.now(timezone.utc) - dt
    return f"{delta.days}d ago" if delta.days >= 1 else "<1d ago"


def render(title, items):
    lines = [f"## {title} ({len(items)})"]
    if not items:
        lines.append("_none._")
    for i in items:
        repo = i["repository"]["nameWithOwner"]
        lines.append(f"- [{repo}#{i['number']}]({i['url']}) — {i['title']} _{age(i['createdAt'])}_")
    return "\n".join(lines) + "\n"


groups = [
    ("Needs your review", union(*sorted(glob.glob(f"{tmp}/reviews/*.json")))),
    ("Needs your decision", union(f"{tmp}/decisions.json")),
    ("In progress", union(f"{tmp}/inprogress.json")),
    ("Ready to pull", union(f"{tmp}/ready.json")),
    ("Drafts to refine", union(f"{tmp}/draft_a.json", f"{tmp}/draft_b.json")),
]

print(f"# What needs you — {owner} — {datetime.now(timezone.utc):%Y-%m-%d %H:%M UTC}\n")
for title, items in groups:
    print(render(title, items))
PY
