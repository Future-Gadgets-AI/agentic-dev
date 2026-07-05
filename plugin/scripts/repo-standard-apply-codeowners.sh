#!/usr/bin/env bash
# repo-standard-apply-codeowners.sh OWNER/REPO --reviewers "reviewer1 reviewer2 ..." --confirmed
#
# Phase A2 of /harden-repo: write .github/CODEOWNERS so it lists every given
# reviewer login. `--confirmed` is REQUIRED, but it is not a new human-safety
# gate (Decision D9 — fully reversible: a PR still needs a human merge
# regardless, and a direct commit on a repo with zero prior history disturbs
# nothing, both stay true). The flag exists purely so this script's CLI shape
# matches apply-labels.sh's (OWNER/REPO ... --confirmed) — interface
# consistency across the repo-standard-*.sh family (see #66), not a gate the
# caller must earn. Idempotent either way (Decision D8): no-op if current
# content already equals the target line; an already-open PR from the
# deterministic branch is reused, never duplicated.
#
# Argument validation — ALL of the below happens before bot-auth.sh is
# sourced (sourcing it already performs network calls of its own: `gh auth
# setup-git`, `gh api user`), so a bad invocation never touches the network:
#   - OWNER/REPO positional required.
#   - --reviewers "..." and --confirmed both required, order-independent;
#     any other argument is an unknown-argument usage error.
#   - --reviewers's value is split on whitespace; the resulting list must be
#     non-empty, and no token may start with "-" — a flag silently absorbed
#     as an owner handle (e.g. `apply-codeowners.sh OWNER/REPO --confirmed`
#     alone, the original #66 bug) is exactly the mistake this closes.
#   - API-based existence-checking of the handles themselves is out of scope
#     (offline, syntactic validation only).
#
# Runs as the BOT: self-sources bot-auth.sh (fail-fast, structural — Decision
# D6). Pure `gh api` (Contents + Git Data API) for BOTH the empty-repo direct
# commit and the has-history branch+PR path — no local `git clone` needed,
# matching the empty-repo path's own technique (Pattern 4) rather than
# introducing a filesystem side effect this script would otherwise not need.
set -uo pipefail

REPO="${1:?usage: repo-standard-apply-codeowners.sh OWNER/REPO --reviewers \"reviewer1 reviewer2 ...\" --confirmed}"
shift || true

REVIEWERS=""
CONFIRMED=0
while [ $# -gt 0 ]; do
  case "$1" in
    --reviewers) shift; REVIEWERS="${1:?--reviewers needs a value}" ;;
    --confirmed) CONFIRMED=1 ;;
    *)
      echo "repo-standard-apply-codeowners: unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift || true
done

[ "$CONFIRMED" -eq 1 ] || {
  echo "repo-standard-apply-codeowners: refusing — missing --confirmed (the confirmation gate is the caller's job)." >&2
  exit 1
}

[ -n "$REVIEWERS" ] || {
  echo "repo-standard-apply-codeowners: refusing — missing --reviewers (a space-separated list of GitHub logins is required)." >&2
  exit 1
}

REVIEWER_COUNT=0
for r in $REVIEWERS; do
  case "$r" in
    -*)
      echo "repo-standard-apply-codeowners: refusing — reviewer token '$r' looks like a flag (starts with '-'), not a GitHub login." >&2
      exit 1
      ;;
  esac
  REVIEWER_COUNT=$((REVIEWER_COUNT + 1))
done
[ "$REVIEWER_COUNT" -gt 0 ] || {
  echo "repo-standard-apply-codeowners: no reviewers resolved — refusing to write an empty CODEOWNERS rule." >&2
  exit 1
}

command -v python3 >/dev/null 2>&1 || {
  echo "repo-standard-apply-codeowners: python3 is required (decodes the current CODEOWNERS content) and is not on PATH." >&2
  exit 1
}

HERE="$(cd "$(dirname "$0")" && pwd)"
# Act as the bot (fail-fast; never fall back to a personal account).
# shellcheck source=/dev/null
source "$HERE/bot-auth.sh" || exit 1

TARGET_LINE="*"
for r in $REVIEWERS; do TARGET_LINE="$TARGET_LINE @$r"; done
[ "$TARGET_LINE" != "*" ] || {
  echo "repo-standard-apply-codeowners: no reviewers resolved — refusing to write an empty CODEOWNERS rule." >&2
  exit 1
}

SCRATCH_ERR="$(mktemp)"
trap 'rm -f "$SCRATCH_ERR"' EXIT

# --- current content: 200 -> decode+compare, 404 -> absent, anything else -> fail fast ---
CONTENT_B64="$(gh api "repos/$REPO/contents/.github/CODEOWNERS" --jq '.content' 2>"$SCRATCH_ERR" | tr -d '\n')"
rc=$?
if [ "$rc" -eq 0 ]; then
  CURRENT_LINE="$(python3 -c 'import base64,sys; print(base64.b64decode(sys.argv[1]).decode("utf-8").strip())' "$CONTENT_B64")"
elif grep -q "HTTP 404" "$SCRATCH_ERR" 2>/dev/null; then
  CURRENT_LINE=""
else
  echo "repo-standard-apply-codeowners: reading .github/CODEOWNERS on $REPO failed: $(tail -1 "$SCRATCH_ERR")" >&2
  exit 1
fi

# Effective-rules compare, mirroring repo-standard-diff.sh: comment/blank lines
# and owner order are cosmetic (the contract says so) — a raw byte compare would
# rewrite every commented-but-correct file into a comment-stripping PR.
if [ -n "$CURRENT_LINE" ] && python3 -c '
import sys


def rules(text):
    out = []
    for ln in text.splitlines():
        s = ln.strip()
        if not s or s.startswith("#"):
            continue
        parts = s.split()
        out.append((parts[0], tuple(sorted(parts[1:]))))
    return out


sys.exit(0 if rules(sys.argv[1]) == rules(sys.argv[2]) else 1)
' "$CURRENT_LINE" "$TARGET_LINE"; then
  echo "repo-standard-apply-codeowners: NO-OP — effective CODEOWNERS rules already match the target (comments/owner order are cosmetic)."
  exit 0
fi

BRANCH="chore/codeowners-hardening"

# Emptiness detection mirrors repo-standard-diff.sh's repo_has_history(): ONLY a
# 409 "Git Repository is empty" (or a confirmed size==0) means empty. Ambiguity
# (rate limit, network blip) must fail fast — it must never route a populated
# repo onto the direct-commit-to-main path.
if gh api "repos/$REPO/commits?per_page=1" >/dev/null 2>"$SCRATCH_ERR"; then
  REPO_EMPTY=0
elif grep -qE "409|Git Repository is empty" "$SCRATCH_ERR" 2>/dev/null; then
  REPO_EMPTY=1
elif [ "$(gh api "repos/$REPO" --jq .size 2>/dev/null)" = "0" ]; then
  REPO_EMPTY=1
else
  echo "repo-standard-apply-codeowners: could not determine commit history for $REPO: $(tail -1 "$SCRATCH_ERR" 2>/dev/null)" >&2
  exit 1
fi

if [ "$REPO_EMPTY" -eq 0 ]; then
  # --- has history: deterministic branch + draft PR, never a direct push to main ---
  existing_pr_url="$(gh pr list --repo "$REPO" --head "$BRANCH" --state open --json url --jq '.[0].url // empty' 2>/dev/null)"
  if [ -n "$existing_pr_url" ]; then
    echo "repo-standard-apply-codeowners: already proposed — $existing_pr_url"
    exit 0
  fi

  REUSE_BRANCH=0
  if gh api "repos/$REPO/git/ref/heads/$BRANCH" >/dev/null 2>&1; then
    # An interrupted earlier run can leave the branch (commit landed, PR not yet
    # opened). Self-heal ONLY when the branch already carries the target rules —
    # any other pre-existing branch stays a human step.
    BRANCH_B64="$(gh api "repos/$REPO/contents/.github/CODEOWNERS?ref=$BRANCH" --jq '.content' 2>/dev/null | tr -d '\n')"
    BRANCH_CONTENT=""
    [ -n "$BRANCH_B64" ] && BRANCH_CONTENT="$(python3 -c 'import base64,sys; print(base64.b64decode(sys.argv[1]).decode("utf-8").strip())' "$BRANCH_B64")"
    if [ -n "$BRANCH_CONTENT" ] && python3 -c '
import sys


def rules(text):
    out = []
    for ln in text.splitlines():
        s = ln.strip()
        if not s or s.startswith("#"):
            continue
        parts = s.split()
        out.append((parts[0], tuple(sorted(parts[1:]))))
    return out


sys.exit(0 if rules(sys.argv[1]) == rules(sys.argv[2]) else 1)
' "$BRANCH_CONTENT" "$TARGET_LINE"; then
      echo "repo-standard-apply-codeowners: branch '$BRANCH' already carries the target rules (interrupted earlier run) — reusing it and opening the PR."
      REUSE_BRANCH=1
    else
      echo "repo-standard-apply-codeowners: branch '$BRANCH' already exists on $REPO with different content and no open PR — resolving it is a human step." >&2
      exit 1
    fi
  fi

  if [ "$REUSE_BRANCH" -eq 0 ]; then
    main_sha="$(gh api "repos/$REPO/git/ref/heads/main" --jq .object.sha 2>/dev/null)" || {
      echo "repo-standard-apply-codeowners: cannot resolve main's HEAD sha on $REPO." >&2
      exit 1
    }

    gh api --method POST "repos/$REPO/git/refs" -f ref="refs/heads/$BRANCH" -f sha="$main_sha" >/dev/null || {
      echo "repo-standard-apply-codeowners: could not create branch '$BRANCH' on $REPO." >&2
      exit 1
    }

    content_b64="$(printf '%s\n' "$TARGET_LINE" | base64 | tr -d '\n')"
    gh api --method PUT "repos/$REPO/contents/.github/CODEOWNERS" \
      -f message="chore: add CODEOWNERS (repo hardening)" \
      -f content="$content_b64" -f branch="$BRANCH" >/dev/null || {
      echo "repo-standard-apply-codeowners: could not commit CODEOWNERS to '$BRANCH' on $REPO." >&2
      exit 1
    }
  fi

  pr_body="$(printf 'Repo hardening: codify `.github/CODEOWNERS` per `plugin/contracts/repo-standard.md`.\n\n[no-close: repo-hardening bootstrap — no tracking issue on %s]\n' "$REPO")"

  pr_url="$(gh pr create --repo "$REPO" --head "$BRANCH" --base main --draft \
    --title "chore: add CODEOWNERS (repo hardening)" --body "$pr_body")" || {
    echo "repo-standard-apply-codeowners: gh pr create failed." >&2
    exit 1
  }
  echo "repo-standard-apply-codeowners: APPLIED — opened draft PR $pr_url"

  pr_number="$(gh pr view "$pr_url" --repo "$REPO" --json number --jq .number)"
  bash "$HERE/request-reviewers.sh" "$REPO" "$pr_number"
else
  # --- genuinely empty repo: Contents API creates the first commit AND main (Decision D7/D8) ---
  content_b64="$(printf '%s\n' "$TARGET_LINE" | base64 | tr -d '\n')"
  commit_sha="$(gh api --method PUT "repos/$REPO/contents/.github/CODEOWNERS" \
    -f message="chore: add CODEOWNERS (repo hardening)" \
    -f content="$content_b64" -f branch="main" --jq '.commit.sha' 2>/dev/null)" || {
    echo "repo-standard-apply-codeowners: direct commit to $REPO failed." >&2
    exit 1
  }
  echo "repo-standard-apply-codeowners: APPLIED — direct commit $commit_sha on main."
fi
