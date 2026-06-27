#!/usr/bin/env bash
# check-closing-keyword.test.sh — table test for check-closing-keyword.sh (issue #48, DoD #4).
#
# Runs the REAL gate script as a subprocess with PR_BODY set, asserting pass(0)/fail(1) — the
# exact path GitHub Actions exercises. This is the documented relaxation of DoD #4: a
# unit-tested script stands in for literal "fixture PRs" (same logic, exercised directly,
# no GitHub round-trip needed for a prototype).
#
# Run:  bash .github/scripts/check-closing-keyword.test.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly GATE="${SCRIPT_DIR}/check-closing-keyword.sh"

pass=0 fail=0

# check <expected 0|1> <description> <body>
check() {
  local expected="$1" desc="$2" body="$3" got
  PR_BODY="$body" bash "$GATE" >/dev/null 2>&1 && got=0 || got=$?
  [ "$got" -ne 0 ] && got=1            # normalize any non-zero to 1
  if [ "$got" -eq "$expected" ]; then
    printf 'ok   [exit %s] %s\n' "$got" "$desc"; pass=$((pass + 1))
  else
    printf 'FAIL [exp %s got %s] %s\n' "$expected" "$got" "$desc"; fail=$((fail + 1))
  fi
}

# --- PASS: closing keywords (variant / case / separator coverage) ---
check 0 'Closes #NN'                'Adds a thing.

Closes #48'
check 0 'Fixes #NN'                 'Fixes #12'
check 0 'Resolves #NN'             'Resolves #7'
check 0 'lowercase closes'         'closes #1'
check 0 'UPPER CLOSES'            'CLOSES #1'
check 0 'closed variant'           'closed #1'
check 0 'fixed variant'            'fixed #1'
check 0 'resolved variant'         'resolved #1'
check 0 'colon separator'          'Closes: #99'
check 0 'keyword on a body line'   'Some text.
This Fixes #5 nicely.'

# --- PASS: opt-out markers ---
check 0 'Implements ADR #NN'       'Implements ADR #8'
check 0 'Implements ADR-0008 form' 'Implements ADR-0008'
check 0 '[no-close: reason]'       'Refactor only.

[no-close: pure docs, no tracking issue]'

# --- FAIL: the real-world miss (bare reference) and friends ---
check 1 'bare (#NN) reference'     'Implements the gate (#48)'
check 1 'mentions issue, no kw'    'Related to #48 but does not close it'
check 1 'empty body'              ''
check 1 'keyword, no number'       'This closes the gap in coverage'
check 1 'prefix not fix #5'        'This is a prefix #5 mention'
check 1 'empty no-close reason'    '[no-close:]'
check 1 'no separator Closes#1'    'Closes#1'

echo "---"
echo "passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
