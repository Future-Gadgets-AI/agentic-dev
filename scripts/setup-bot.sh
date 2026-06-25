#!/usr/bin/env bash
# setup-bot.sh — one-time: capture the bot PAT, verify it resolves to the expected
# account, probe the fine-grained-PAT permission gotcha, and store credentials
# (chmod 600, outside any repo) for bot-auth.sh to consume. Never prints the token.
#
# Usage:
#   scripts/setup-bot.sh --from-env ~/path/to/.env [--login <bot-login>] \
#                        [--probe-repo Future-Gadgets-AI/agentic-dev]
#   scripts/setup-bot.sh --token <PAT> [--login ...] [--probe-repo ...]
#   GITHUB_PAT=... scripts/setup-bot.sh
#
# The credentials file is written to ${AGENTIC_DEV_CONFIG_DIR:-~/.config/agentic-dev}.
set -euo pipefail

CONFIG_DIR="${AGENTIC_DEV_CONFIG_DIR:-$HOME/.config/agentic-dev}"
CONFIG_FILE="$CONFIG_DIR/credentials"
EXPECT_LOGIN=""
PROBE_REPO=""
REVIEWERS="${AGENTIC_REVIEWERS:-}"
TOKEN="${GITHUB_PAT:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --from-env)
      shift; envfile="${1:?--from-env needs a path}"
      [ -f "$envfile" ] || { echo "setup: env file not found: $envfile" >&2; exit 1; }
      # Extract GITHUB_PAT=... into a variable WITHOUT echoing the value.
      TOKEN="$(grep -E '^[[:space:]]*GITHUB_PAT[[:space:]]*=' "$envfile" | tail -1 \
               | sed -E 's/^[^=]*=[[:space:]]*//; s/^["'\'']//; s/["'\'']$//')"
      [ -n "$TOKEN" ] || { echo "setup: no GITHUB_PAT=... line in $envfile" >&2; exit 1; }
      ;;
    --token)       shift; TOKEN="${1:?--token needs a value}" ;;
    --login)       shift; EXPECT_LOGIN="${1:?--login needs a value}" ;;
    --probe-repo)  shift; PROBE_REPO="${1:?--probe-repo needs OWNER/REPO}" ;;
    --reviewers)   shift; REVIEWERS="${1:?--reviewers needs a space-separated list}" ;;
    *) echo "setup: unknown argument: $1" >&2; exit 1 ;;
  esac
  shift
done

if [ -z "$TOKEN" ]; then
  echo "setup: no token supplied. Use --from-env <file>, --token <PAT>, or export GITHUB_PAT." >&2
  exit 1
fi

# 1) Verify the token resolves to the expected account (no token echoed).
if ! login="$(GH_TOKEN="$TOKEN" gh api user --jq .login 2>/dev/null)"; then
  echo "setup: the token is invalid or expired ('gh api user' failed)." >&2
  exit 1
fi
uid="$(GH_TOKEN="$TOKEN" gh api user --jq .id 2>/dev/null)" || uid=""
if [ -n "$EXPECT_LOGIN" ] && [ "$login" != "$EXPECT_LOGIN" ]; then
  echo "setup: token resolves to '$login', but expected '$EXPECT_LOGIN'." >&2
  echo "  If '$login' is correct, re-run with: --login '$login'." >&2
  echo "  Otherwise you likely copied the wrong account's PAT." >&2
  exit 1
fi

# 2) Probe the known gotcha: a fine-grained PAT can pass 'gh api user' yet 403 on
#    push/PR. Confirm real write access before we declare success.
if [ -n "$PROBE_REPO" ]; then
  push="$(GH_TOKEN="$TOKEN" gh api "repos/$PROBE_REPO" --jq '.permissions.push' 2>/dev/null)" || push=""
  if [ "$push" != "true" ]; then
    {
      echo "setup: WARNING — token cannot push to $PROBE_REPO (permissions.push=${push:-none})."
      echo "  A fine-grained PAT must: Resource owner = the ORG, be APPROVED by an org owner,"
      echo "  and grant Contents:write + Pull requests:write (+ Issues:write)."
      echo "  'gh api user' works without these, but push/PR/issue calls will 403."
      echo "  Fix the PAT in GitHub settings, then re-run setup."
    } >&2
    exit 1
  fi
fi

# 3) Derive the GitHub-linked commit identity (so commits attribute to the account).
email="${uid:+${uid}+}${login}@users.noreply.github.com"

# 4) Store with tight permissions; never echo the token.
mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR" 2>/dev/null || true
umask 177
cat > "$CONFIG_FILE" <<EOF
# agentic-dev bot credentials — DO NOT COMMIT. Consumed by scripts/bot-auth.sh.
# Single source of truth for the bot identity used by all git skills.
GITHUB_PAT='$TOKEN'
GITHUB_LOGIN='$login'
GITHUB_NAME='$login'
GITHUB_EMAIL='$email'
# Reviewers requested on every PR (space-separated; edit here to change globally).
AGENTIC_REVIEWERS='$REVIEWERS'
EOF
chmod 600 "$CONFIG_FILE"

echo "setup: stored credentials for '$login' at $CONFIG_FILE (chmod 600)."
echo "setup: commit identity -> $login <$email>"
echo "setup: PR reviewers     -> $REVIEWERS"
[ -n "$PROBE_REPO" ] && echo "setup: verified push access to $PROBE_REPO ✓"
echo "setup: this file is OUTSIDE the repo — never commit it."
