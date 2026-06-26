#!/usr/bin/env bash
# request-reviewers.sh OWNER/REPO PR_NUMBER
#
# Request every configured reviewer (AGENTIC_REVIEWERS) on a PR, as the bot.
#
# Why a script and not an inline loop in the skill: the skills run in the user's
# shell, which is often zsh, and `for r in $AGENTIC_REVIEWERS` does NOT word-split
# in zsh — it would POST one bogus "a b" reviewer and attach neither. A bash script
# (this shebang) splits correctly everywhere.
#
# Why one request per reviewer: gh and the REST endpoint reliably attach only ONE
# when several are passed in a single call (cli/cli #954, #7463), so each reviewer
# is POSTed alone, with the calls spaced out.
#
# CODEOWNERS-aware: a reviewer already requested (e.g. auto-added by a matching
# CODEOWNERS rule when the PR was opened) is skipped — harmless either way because
# GitHub dedupes, but it avoids noise. The read-back at the end is the real
# guarantee: it exits non-zero if any configured reviewer is still missing.
set -uo pipefail

REPO="${1:?usage: request-reviewers.sh OWNER/REPO PR_NUMBER}"
PR="${2:?usage: request-reviewers.sh OWNER/REPO PR_NUMBER}"

# Act as the bot (idempotent; sets GH_TOKEN + AGENTIC_REVIEWERS if not already set).
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/bot-auth.sh" || exit 1

REVIEWERS="${AGENTIC_REVIEWERS:-}"
[ -n "$REVIEWERS" ] || { echo "request-reviewers: no AGENTIC_REVIEWERS configured — relying on CODEOWNERS for review requests." >&2; exit 0; }

# Reviewers already on the PR (e.g. CODEOWNERS auto-requests on open).
already="$(gh pr view "$PR" --repo "$REPO" --json reviewRequests --jq '[.reviewRequests[].login]|join(" ")' 2>/dev/null || echo "")"

for r in $REVIEWERS; do
  case " $already " in
    *" $r "*) echo "  $r: already requested (CODEOWNERS or prior) — skipping"; continue ;;
  esac
  if gh api -X POST "repos/$REPO/pulls/$PR/requested_reviewers" -f "reviewers[]=$r" >/dev/null 2>&1; then
    echo "  $r: requested"
  else
    echo "  $r: WARN — could not request (not a collaborator / no repo access?)" >&2
  fi
  sleep 1   # space the calls — batching/rapid-fire silently drops reviewers
done

# Read-back guarantee.
attached="$(gh pr view "$PR" --repo "$REPO" --json reviewRequests --jq '[.reviewRequests[].login]|sort|unique|join(" ")')"
echo "configured: $REVIEWERS"
echo "attached:   $attached"
missing=""
for r in $REVIEWERS; do
  case " $attached " in *" $r "*) ;; *) missing="$missing $r" ;; esac
done
if [ -n "$missing" ]; then
  echo "request-reviewers: MISSING:$missing — surface this; do not ship a half-reviewed PR." >&2
  exit 1
fi
echo "request-reviewers: all configured reviewers attached ✓"
