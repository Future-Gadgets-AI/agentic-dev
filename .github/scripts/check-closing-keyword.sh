#!/usr/bin/env bash
# check-closing-keyword.sh — CI gate (issue #48): a PR to main must EITHER declare a
# closing keyword for its tracking issue, OR carry an explicit opt-out marker.
#
# Why: the create-pr skill mandates an "Implements" line with `Closes #NN` so that merging
# auto-closes the tracking issue (GitHub is the state store). PRs #43/#44 used a bare
# "(#NN)" instead, so their issues stayed OPEN after shipping and the blind review missed
# it — a review-checklist line is not enough, so the fix is mechanical.
#
# Input: the PR body is read from $PR_BODY, which the workflow passes via `env:` — it is
# NEVER interpolated into the run-script, so attacker-controlled PR text cannot inject shell.
# Exit 0 if the body closes an issue OR opts out; exit 1 with an actionable message otherwise.
#
# PASS conditions:
#   1. Closing keyword + issue number, case-insensitive (what GitHub needs to auto-close):
#        Close/Closes/Closed, Fix/Fixes/Fixed, Resolve/Resolves/Resolved   ->   "#<num>"
#        e.g.  "Closes #48"   "Fixes: #12"   "resolved #7"
#   2. Explicit opt-out marker — a small literal allowlist for the legit non-closing cases:
#        "Implements ADR #<num>"   ADR-implementing PR (no issue to close)
#        "[no-close: <reason>]"    multi-phase PR (closes its parent only in the final
#                                  phase), or a PR with genuinely no tracking issue
set -euo pipefail

# Case-insensitive ERE.
#  - The leading (^|[^[:alnum:]]) is a portable word boundary, so "prefix #1" is NOT read as
#    "fix #1".
#  - ":?[[:space:]]+" mirrors GitHub: an optional colon then REQUIRED whitespace before the
#    #number. We are no more lenient than GitHub, so any body we pass is one GitHub will
#    actually auto-close on merge.
readonly CLOSING_RE='(^|[^[:alnum:]])(close[sd]?|fix(es|ed)?|resolve[sd]?):?[[:space:]]+#[0-9]+'
readonly ADR_RE='(^|[^[:alnum:]])implements[[:space:]]+adr[[:space:]#-]*[0-9]+'
readonly NOCLOSE_RE='\[no-close:[[:space:]]*[^][:space:]][^]]*\]'   # reason required (non-empty)

# matches <body> <regex> -> exit 0 if body matches. Here-string (no pipe) sidesteps the
# `printf | grep -q` + pipefail SIGPIPE gotcha.
matches() { grep -iEq -- "$2" <<<"$1"; }

main() {
  local body="${PR_BODY:-}"

  if matches "$body" "$CLOSING_RE"; then
    echo "::notice::PR declares an issue-closing keyword — closing-keyword-gate passes."
    exit 0
  fi
  if matches "$body" "$ADR_RE"; then
    echo "::notice::PR opts out via 'Implements ADR #NN' — closing-keyword-gate passes."
    exit 0
  fi
  if matches "$body" "$NOCLOSE_RE"; then
    echo "::notice::PR opts out via '[no-close: <reason>]' — closing-keyword-gate passes."
    exit 0
  fi

  # Failure: name BOTH the missing keyword AND the opt-out escape hatch (actionable).
  # Only the first ::error:: line renders as a GitHub annotation; the rest prints to the log.
  cat >&2 <<'MSG'
::error::PR body has no issue-closing keyword and no opt-out marker — see the job log.

This PR targets main but its body neither closes a tracking issue nor opts out, so
merging it would leave the tracking issue OPEN (GitHub is the state store). Edit the
PR body to include ONE of the following, then the check re-runs automatically:

  * A closing keyword + issue number (auto-closes the issue on merge):
        Closes #NN   |   Fixes #NN   |   Resolves #NN
        (also Close/Closed, Fix/Fixed, Resolve/Resolved — case-insensitive)
        NOTE: a bare "(#NN)" reference does NOT close the issue and will NOT pass.

  * An explicit opt-out marker, for a PR that legitimately closes nothing:
        Implements ADR #NN     an ADR-implementing PR (no issue to close)
        [no-close: <reason>]   a multi-phase PR that closes its parent only in the
                               final phase, or a PR with no tracking issue
MSG
  exit 1
}

main "$@"
