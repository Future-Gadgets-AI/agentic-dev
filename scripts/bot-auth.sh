#!/usr/bin/env bash
# bot-auth.sh — assume the configured GitHub bot identity for the current shell.
# SOURCE this at the top of every git/gh WRITE block; do not execute it:
#
#     source "${CLAUDE_PLUGIN_ROOT}/scripts/bot-auth.sh" || exit 1
#
# FAIL-FAST, no fallback (see git-collaboration -> "Bot identity (run as the bot)"):
#   success -> exports GH_TOKEN, ephemeral GIT_AUTHOR_*/GIT_COMMITTER_*, and
#              AGENTIC_REVIEWERS for THIS shell; prints one non-sensitive line.
#   failure -> actionable error on stderr + non-zero return. It NEVER falls back to
#              a personal gh login, and it NEVER prints the token.
#
# Why a sourced helper (not a wrapper): each tool/Bash call is a fresh shell, so the
# identity must be re-established per write block. Sourcing sets GH_TOKEN + the git
# author env in *this* shell so the git/gh commands that follow inherit them.

__bot_auth() {
  local cfg="${AGENTIC_DEV_CONFIG:-$HOME/.config/agentic-dev/credentials}"

  # Resolve the token. Precedence: an already-exported GITHUB_PAT, else the
  # gitignored credentials file written by setup-bot.sh. No token => fail fast.
  if [ -z "${GITHUB_PAT:-}" ] && [ -f "$cfg" ]; then
    set -a; . "$cfg"; set +a
  fi

  if [ -z "${GITHUB_PAT:-}" ]; then
    {
      echo "bot-auth: no bot credentials found (checked \$GITHUB_PAT and $cfg)."
      echo "  Fix: scripts/setup-bot.sh --from-env <your .env containing GITHUB_PAT=...>"
      echo "  Refusing to act as a personal gh account (fail-fast)."
    } >&2
    return 1
  fi

  export GH_TOKEN="$GITHUB_PAT"

  # Route git pushes through the same token (gh as credential helper). Idempotent.
  if ! gh auth setup-git >/dev/null 2>&1; then
    echo "bot-auth: 'gh auth setup-git' failed — git push can't use the bot token." >&2
    unset GH_TOKEN; return 1
  fi

  # Identity guardrail: the token MUST resolve to the expected bot, or we stop.
  local expected="${GITHUB_LOGIN:-komiko-bot}" actual
  if ! actual="$(gh api user --jq .login 2>/dev/null)"; then
    echo "bot-auth: identity check failed (gh api user). PAT invalid, expired, or 403?" >&2
    unset GH_TOKEN; return 1
  fi
  if [ "$actual" != "$expected" ]; then
    echo "bot-auth: identity mismatch — token is '$actual', expected '$expected'. Refusing to proceed." >&2
    unset GH_TOKEN; return 1
  fi

  # Ephemeral commit identity — exported, NOT written to git config, so it cannot
  # hijack your later manual commits in this repo. Prefer configured name/email;
  # else derive the GitHub-linked noreply address from the verified account.
  local name="${GITHUB_NAME:-$actual}" email="${GITHUB_EMAIL:-}"
  if [ -z "$email" ]; then
    local uid; uid="$(gh api user --jq .id 2>/dev/null)" || uid=""
    email="${uid:+${uid}+}${actual}@users.noreply.github.com"
  fi
  export GIT_AUTHOR_NAME="$name"   GIT_AUTHOR_EMAIL="$email"
  export GIT_COMMITTER_NAME="$name" GIT_COMMITTER_EMAIL="$email"

  # Single source of truth for PR reviewers (override in the credentials file).
  export AGENTIC_REVIEWERS="${AGENTIC_REVIEWERS:-lucasbrandao4770 gustavomoura628}"

  echo "bot-auth: acting as ${actual} ✓ (commits -> ${name} <${email}>)"
  return 0
}

__bot_auth; __bot_auth_rc=$?
unset -f __bot_auth
# Propagate status to the caller's `source ... || exit 1`. `return` at the top level
# of a sourced file is valid in bash and zsh; if this file is *executed* by mistake
# it errors here, which is the intended "don't run me, source me" failure.
return $__bot_auth_rc
