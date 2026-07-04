#!/usr/bin/env bash
# repo-standard-apply-labels.sh OWNER/REPO --confirmed
#
# Phase B of /harden-repo: bulk-create every scheme label from
# plugin/contracts/repo-standard.md's "Label rollout manifest" that is still
# missing on OWNER/REPO. Never touches an existing label — the existence
# check is an EXACT line match (`grep -qxF`), never a substring match: a
# substring check has a real collision smell (e.g. "priority:high" would
# false-positive against a hypothetical existing "priority:highest" label).
#
# Runs as the BOT: self-sources bot-auth.sh (fail-fast, structural — Decision
# D6). Refuses to run without --confirmed: the confirmation gate is the
# CALLER's (harden-repo.md's) job, never this script's — it never prompts.
set -uo pipefail

REPO="${1:?usage: repo-standard-apply-labels.sh OWNER/REPO --confirmed}"
[ "${2:-}" = "--confirmed" ] || {
  echo "repo-standard-apply-labels: refusing — missing --confirmed (the confirmation gate is the caller's job)." >&2
  exit 1
}

command -v python3 >/dev/null 2>&1 || {
  echo "repo-standard-apply-labels: python3 is required (parses plugin/contracts/repo-standard.md's label manifest — Decision D2) and is not on PATH." >&2
  exit 1
}

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/.." && pwd)"
CONTRACT="$PLUGIN_ROOT/contracts/repo-standard.md"
[ -f "$CONTRACT" ] || { echo "repo-standard-apply-labels: missing contract file: $CONTRACT" >&2; exit 1; }

# Act as the bot (fail-fast; never fall back to a personal account).
# shellcheck source=/dev/null
source "$HERE/bot-auth.sh" || exit 1

# --- Pattern 1: parse the label manifest straight out of the contract (Decision D2) ---
MANIFEST_TSV="$(python3 - "$CONTRACT" <<'PY'
import json
import re
import sys


def block(text, heading):
    m = re.search(re.escape("## " + heading) + r"\n```json\n(.*?)\n```", text, re.DOTALL)
    if not m:
        sys.exit(f"repo-standard-apply-labels: missing or malformed section {heading!r}")
    return json.loads(m.group(1))


contract = open(sys.argv[1]).read()
manifest = block(contract, "Label rollout manifest (target — create if missing; never touch existing)")
for row in manifest:
    print(f"{row['name']}\t{row['color']}\t{row['description']}")
PY
)" || exit 1

[ -n "$MANIFEST_TSV" ] || { echo "repo-standard-apply-labels: label manifest parsed empty — nothing to do." >&2; exit 1; }

# --- existing labels on the target, generously paged so nothing is silently missed ---
existing="$(gh label list --repo "$REPO" --limit 300 --json name --jq '.[].name')"

created=0
failed=0
while IFS=$'\t' read -r name color desc; do
  [ -n "$name" ] || continue
  if grep -qxF "$name" <<<"$existing"; then
    echo "  $name: already exists — skipping"
    continue
  fi
  if gh label create "$name" --repo "$REPO" --color "$color" --description "$desc" >/dev/null 2>&1; then
    echo "  + created $name (#$color)"
    created=$((created + 1))
  else
    echo "  ! FAILED to create $name" >&2
    failed=$((failed + 1))
  fi
done <<<"$MANIFEST_TSV"

echo "repo-standard-apply-labels: $created label(s) created; existing labels untouched."
if [ "$failed" -gt 0 ]; then
  echo "repo-standard-apply-labels: $failed label(s) FAILED to create." >&2
  exit 1
fi
