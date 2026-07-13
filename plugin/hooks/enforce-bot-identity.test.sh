#!/usr/bin/env bash
# enforce-bot-identity.test.sh — table test for enforce-bot-identity.py (issue #57).
#
# Runs the REAL hook as a subprocess, feeding it the exact JSON shape the PreToolUse
# harness sends on stdin (tool_name, tool_input.command, cwd), asserting its exit code
# — 0 = allow, 2 = deny, per the hook's own PreToolUse contract. Mirrors this repo's
# .github/scripts/check-closing-keyword.test.sh convention: real script, subprocess,
# exit-code assertions, pass/fail tally, non-zero exit if anything failed.
#
# Never runs a real git/gh write — the hook only ever inspects the literal command
# string, so every fixture below is a plain string that never actually executes.
#
# Run:  bash plugin/hooks/enforce-bot-identity.test.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly HOOK="${SCRIPT_DIR}/enforce-bot-identity.py"

# --- cwd fixtures -----------------------------------------------------------------
# ORG_CWD: this script lives at plugin/hooks/, so two levels up is the repo root —
#   wherever this repo happens to be checked out, that IS a Future-Gadgets-AI/
#   agentic-dev clone, so the cwd-remote fallback resolves it to the bot's org.
#   Portable by construction: never a hardcoded absolute path.
readonly ORG_CWD="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# NOGIT_CWD / OTHERORG_CWD: real temp dirs, created fresh per run, cleaned up on exit.
# Never created inside the repo tree (a nested `git init` there would corrupt `git
# status` for the outer repo).
NOGIT_CWD="$(mktemp -d)"      # no .git at all -> cwd fallback unresolvable (None)
OTHERORG_CWD="$(mktemp -d)"   # git-inited, remote = a DIFFERENT org -> resolves False
readonly NOGIT_CWD OTHERORG_CWD
cleanup() { rm -rf "$NOGIT_CWD" "$OTHERORG_CWD"; }
trap cleanup EXIT

git -C "$OTHERORG_CWD" init -q
git -C "$OTHERORG_CWD" remote add origin https://github.com/some-other-org/some-other-repo.git

pass=0 fail=0

# build_payload <command> <cwd> -> JSON on stdout, shaped exactly like the real
# PreToolUse(Bash) payload. Built via python3 (already a hard dependency of the hook
# itself) so arbitrary command strings — including multi-line heredoc fixtures — are
# escaped correctly; never hand-rolled string concatenation.
build_payload() {
  python3 -c '
import json, sys
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}, "cwd": sys.argv[2]}))
' "$1" "$2"
}

# _tally <expected> <got> <desc> <stderr-output> — shared pass/fail bookkeeping.
_tally() {
  local expected="$1" got="$2" desc="$3" out="$4"
  if [ "$got" -eq "$expected" ]; then
    printf 'ok   [exit %s] %s\n' "$got" "$desc"
    pass=$((pass + 1))
  else
    printf 'FAIL [exp %s got %s] %s\n' "$expected" "$got" "$desc"
    [ -n "$out" ] && printf '     stderr: %s\n' "$out"
    fail=$((fail + 1))
  fi
}

# check_raw <expected 0|2> <description> <raw stdin text> — for fixtures that aren't
# a normal (command, cwd) pair: empty/unparseable stdin, non-Bash tool_name.
check_raw() {
  local expected="$1" desc="$2" stdin_body="$3" got out
  out="$(printf '%s' "$stdin_body" | python3 "$HOOK" 2>&1 1>/dev/null)"
  got=$?
  _tally "$expected" "$got" "$desc" "$out"
}

# check <expected 0|2> <description> <command string> <cwd> — the common case.
check() {
  local expected="$1" desc="$2" cmd="$3" cwd="$4"
  check_raw "$expected" "$desc" "$(build_payload "$cmd" "$cwd")"
}

echo "=== AC1 — repo-verb block (gh repo create|delete|rename|edit|archive), ambient, org via cwd ==="
check 2 'AC1 repo create'  'gh repo create new-repo --public'         "$ORG_CWD"
check 2 'AC1 repo delete'  'gh repo delete old-repo --yes'            "$ORG_CWD"
check 2 'AC1 repo rename'  'gh repo rename old-name new-name'         "$ORG_CWD"
check 2 'AC1 repo edit'    'gh repo edit some-repo --description "x"' "$ORG_CWD"
check 2 'AC1 repo archive' 'gh repo archive some-repo'                "$ORG_CWD"

echo "=== AC2 — repo-verb marker escape ==="
check 0 'AC2 repo create + marker' \
  'gh repo create new-repo --public # agentic:allow-ambient' "$ORG_CWD"
check 0 'AC2 repo delete + marker' \
  'gh repo delete old-repo --yes # agentic:allow-ambient' "$ORG_CWD"

echo "=== AC3 — graphql-mutation block ==="
check 2 'AC3 graphql -f mutation' \
  "gh api graphql -f query='mutation { addComment(input: {}) { clientMutationId } }'" \
  "$ORG_CWD"
check 2 'AC3 graphql heredoc mutation (keyword only in the heredoc body)' \
  'gh api graphql -f query=@- <<'"'"'EOF'"'"'
mutation {
  addComment(input: {}) { clientMutationId }
}
EOF' \
  "$ORG_CWD"

echo "=== AC4 — graphql-mutation marker escape ==="
check 0 'AC4 graphql mutation + marker' \
  "gh api graphql -f query='mutation { addComment(input: {}) { clientMutationId } }' # agentic:allow-ambient" \
  "$ORG_CWD"

echo "=== AC5 — URL-form org resolution, before the cwd fallback, for a non-merge/repo-delete verb ==="
check 2 'AC5 https URL target resolves org despite non-org cwd (gh issue comment by URL)' \
  'gh issue comment https://github.com/Future-Gadgets-AI/agentic-dev/issues/1 --body "thanks"' \
  "$NOGIT_CWD"
check 2 'AC5 ssh URL resolves org despite non-org cwd (git push by URL)' \
  'git push git@github.com:Future-Gadgets-AI/agentic-dev.git HEAD:main' \
  "$NOGIT_CWD"

echo "=== AC5b — quoted prose URLs are NOT targets (PR #88 blind-review finding 1) ==="
check 2 'AC5b quoted other-org URL in --body cannot spoof merge target (org cwd)' \
  'gh pr merge 5 --body "closes https://github.com/some-other-org/other-repo/pull/1"' \
  "$ORG_CWD"
check 2 'AC5b quoted other-org URL in --body cannot spoof comment target (org cwd)' \
  'gh issue comment 5 --body "see https://github.com/some-other-org/other-repo/issues/2"' \
  "$ORG_CWD"
check 0 'AC5b quoted org URL in prose alone does not deny (target unresolvable, low-consequence verb)' \
  'gh issue comment 5 --body "see https://github.com/Future-Gadgets-AI/agentic-dev/issues/1"' \
  "$NOGIT_CWD"
check 2 'AC5b unquoted URL target still beats a confirmed-other-org cwd (merge)' \
  'gh pr merge https://github.com/Future-Gadgets-AI/agentic-dev/pull/5' \
  "$OTHERORG_CWD"
check 0 'AC5b quoted org URL in prose does not block a personal-repo merge (other-org cwd)' \
  'gh pr merge 5 --body "backports https://github.com/Future-Gadgets-AI/agentic-dev/pull/3"' \
  "$OTHERORG_CWD"

echo "=== AC6 — gh pr merge: unmarked block regardless of identity or how the target resolves ==="
check 2 'AC6 URL merge, ambient, unresolved cwd' \
  'gh pr merge https://github.com/Future-Gadgets-AI/agentic-dev/pull/5' "$NOGIT_CWD"
check 2 'AC6 URL merge, bot-auth.sh present (!!)' \
  'source "${CLAUDE_PLUGIN_ROOT}/scripts/bot-auth.sh" || exit 1 && gh pr merge https://github.com/Future-Gadgets-AI/agentic-dev/pull/5' \
  "$NOGIT_CWD"
check 2 'AC6 URL merge, GH_TOKEN= present (!!)' \
  'GH_TOKEN=ghp_xxx gh pr merge https://github.com/Future-Gadgets-AI/agentic-dev/pull/5' \
  "$NOGIT_CWD"
check 2 'AC6 bare merge, confirmed org via cwd' 'gh pr merge 5' "$ORG_CWD"
check 2 'AC6 bare merge, target fails to resolve' 'gh pr merge 5' "$NOGIT_CWD"

echo "=== AC7 — merge marker escape, regardless of identity ==="
check 0 'AC7 URL merge + marker, ambient' \
  'gh pr merge https://github.com/Future-Gadgets-AI/agentic-dev/pull/5 # agentic:allow-ambient' \
  "$NOGIT_CWD"
check 0 'AC7 bare merge + marker, org cwd' 'gh pr merge 5 # agentic:allow-ambient' "$ORG_CWD"

echo "=== AC8 — merge out-of-org passthrough (hook has no opinion on other orgs' merges) ==="
check 0 'AC8 merge --repo confirms other org' \
  'gh pr merge 5 --repo some-other-org/some-other-repo' "$NOGIT_CWD"
check 0 'AC8 merge non-org URL' \
  'gh pr merge https://github.com/some-other-org/some-other-repo/pull/5' "$NOGIT_CWD"
check 0 'AC8 merge confirmed-other-org via cwd' 'gh pr merge 5' "$OTHERORG_CWD"

echo "=== AC9 — repo-delete fails CLOSED when unresolvable; marker/bot-auth/GH_TOKEN= still escape it ==="
check 2 'AC9 repo delete, unresolved, ambient' 'gh repo delete some-repo --yes' "$NOGIT_CWD"
check 0 'AC9 repo delete, unresolved + marker' \
  'gh repo delete some-repo --yes # agentic:allow-ambient' "$NOGIT_CWD"
check 0 'AC9 repo delete, unresolved + bot-auth' \
  'source "${CLAUDE_PLUGIN_ROOT}/scripts/bot-auth.sh" || exit 1 && gh repo delete some-repo --yes' \
  "$NOGIT_CWD"
check 0 'AC9 repo delete, unresolved + GH_TOKEN=' \
  'GH_TOKEN=ghp_xxx gh repo delete some-repo --yes' "$NOGIT_CWD"

echo "=== AC10 — every OTHER matched write verb still fails OPEN when unresolvable (narrow scoping) ==="
check 0 'AC10 gh issue create, unresolved'  'gh issue create --title x --body y'     "$NOGIT_CWD"
check 0 'AC10 git commit, unresolved'       'git commit -m "wip"'                    "$NOGIT_CWD"
check 0 'AC10 gh label create, unresolved'  'gh label create bug --color ff0000'     "$NOGIT_CWD"
check 0 'AC10 gh repo create, unresolved'   'gh repo create some-repo --public'      "$NOGIT_CWD"
check 0 'AC10 gh repo rename, unresolved'   'gh repo rename old new'                 "$NOGIT_CWD"
check 0 'AC10 gh repo edit, unresolved'     'gh repo edit some-repo --description x' "$NOGIT_CWD"
check 0 'AC10 gh repo archive, unresolved'  'gh repo archive some-repo'              "$NOGIT_CWD"
check 0 'AC10 graphql mutation, unresolved' "gh api graphql -f query='mutation {}'"  "$NOGIT_CWD"

echo "=== AC11 — regression: every pre-existing behavior still holds ==="
check 2 'AC11 git commit in-org ambient blocked (pre-existing)' 'git commit -m "wip"' "$ORG_CWD"
check 2 'AC11 git push in-org ambient blocked (pre-existing)' 'git push origin main' "$ORG_CWD"
check 0 'AC11 bot-auth allows git commit' \
  'source "${CLAUDE_PLUGIN_ROOT}/scripts/bot-auth.sh" || exit 1 && git commit -m "wip"' \
  "$ORG_CWD"
check 0 'AC11 GH_TOKEN= allows gh issue create' \
  'GH_TOKEN=ghp_x gh issue create --title x' "$ORG_CWD"
check 0 'AC11 marker allows git commit' \
  'git commit -m "wip" # agentic:allow-ambient' "$ORG_CWD"
check 0 'AC11 gh pr review stays exempt (never matched)' 'gh pr review 5 --approve' "$ORG_CWD"
check_raw 0 'AC11 non-Bash tool_name allowed' \
  '{"tool_name":"Read","tool_input":{"file_path":"/etc/hosts"}}'
check_raw 0 'AC11 empty stdin allowed' ''
check_raw 0 'AC11 unparseable stdin allowed' 'not valid json {{{'
check 0 'AC11 no write verb (gh issue list)' 'gh issue list' "$ORG_CWD"
check 0 'AC11 no write verb (git status)' 'git status' "$ORG_CWD"
check 2 'AC11 --repo owner/repo resolution still works' \
  'gh issue create --repo Future-Gadgets-AI/agentic-dev --title x' "$NOGIT_CWD"
check 2 'AC11 -R owner/repo resolution still works' \
  'gh issue create -R Future-Gadgets-AI/agentic-dev --title x' "$NOGIT_CWD"
check 2 'AC11 repos/owner resolution still works' \
  'gh api repos/Future-Gadgets-AI/agentic-dev/issues -X POST -f title=x' "$NOGIT_CWD"
check 2 'AC11 orgs/owner resolution still works' \
  'gh api orgs/Future-Gadgets-AI/repos -X POST -f name=x' "$NOGIT_CWD"
check 0 'AC11 confirmed-other-org via --repo still allows' \
  'gh issue create --repo some-other-org/some-repo --title x' "$NOGIT_CWD"
check 0 'AC11 confirmed-other-org via cwd still allows' 'git commit -m wip' "$OTHERORG_CWD"

echo "=== Edge cases (DEFINE, explicit — must keep passing) ==="
check 0 'edge: night-shift documented merge form (url + marker)' \
  'gh pr merge https://github.com/Future-Gadgets-AI/agentic-dev/pull/9 --admin # agentic:allow-ambient' \
  "$NOGIT_CWD"
check 0 'edge: bot-auth allows a non-merge write in-org' \
  'source "${CLAUDE_PLUGIN_ROOT}/scripts/bot-auth.sh" || exit 1 && gh repo archive some-repo' \
  "$ORG_CWD"
check 0 'edge: unrelated non-org working directory allowed' \
  'git commit -m "personal project wip"' "$OTHERORG_CWD"

echo "---"
echo "passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
