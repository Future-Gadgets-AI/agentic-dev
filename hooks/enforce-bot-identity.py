#!/usr/bin/env python3
"""PreToolUse(Bash) guard — refuse git/gh WRITES to the bot's org that don't run
as the configured bot.

Defense-in-depth for the agentic-dev bot-identity model. The action skills route
every GitHub write through scripts/bot-auth.sh (which exports GH_TOKEN + the bot's
commit identity, fail-fast). A write block that *forgets* to source it would run as
the user's ambient gh login — the wrong-account write we forbid. This hook denies
such commands so a missed `source` can't slip through.

Scope & stance (read before tightening):
- Scoped to the bot's org (AGENTIC_BOT_ORG, default Future-Gadgets-AI) so it never
  interferes with personal / other-repo git or gh usage.
- Conservative: only the specific write verbs the skills use are matched; reads are
  untouched; `gh pr review` (the human reviewer's verb) is exempt by design.
- Fail-OPEN: on any ambiguity (can't parse, can't resolve the org) it ALLOWS. This
  is heuristic defense-in-depth, not a cryptographic guarantee — the skills' source
  lines remain the primary mechanism, and a false block is worse than a rare miss.
- Escape hatch: put the marker `agentic:allow-ambient` in a command to bypass.

PreToolUse contract: exit 0 = allow; exit 2 = block, with the reason on stderr.
"""
import json
import os
import re
import subprocess
import sys

EXPECTED_ORG = os.environ.get("AGENTIC_BOT_ORG", "Future-Gadgets-AI").lower()

# The write verbs the skills actually use. `gh pr review` is intentionally absent
# (it's the human reviewer's verb). `gh repo *` is absent (human admin ops).
WRITE_RE = re.compile(
    r"""
      \bgit\s+commit\b
    | \bgit\s+push\b
    | \bgh\s+issue\s+(?:create|edit|close|reopen|comment|delete|transfer|lock|unlock|pin|unpin)\b
    | \bgh\s+pr\s+(?:create|edit|close|reopen|merge|ready|comment|lock|unlock)\b
    | \bgh\s+label\s+(?:create|edit|delete|clone)\b
    | \bgh\s+release\s+(?:create|edit|delete)\b
    | \bgh\s+api\b[^\n]*\s(?:-X|--method)\s+(?:POST|PUT|PATCH|DELETE)\b
    | \bgh\s+api\b[^\n]*requested_reviewers
    """,
    re.VERBOSE | re.IGNORECASE,
)


def allow():
    """Not applicable / ambiguous -> let the tool call proceed."""
    sys.exit(0)


def targets_expected_org(cmd, cwd):
    """True/False if we can determine the target org, else None (unknown)."""
    # gh --repo OWNER/REPO  or  -R OWNER/REPO
    m = re.search(r'(?:--repo|-R)[=\s]+([^/\s]+)/', cmd)
    if m:
        return m.group(1).lower() == EXPECTED_ORG
    # gh api repos/OWNER/...  or  orgs/OWNER
    m = re.search(r'\b(?:repos|orgs)/([^/\s"\']+)', cmd)
    if m and "$" not in m.group(1):  # skip unexpanded shell vars like repos/$REPO
        return m.group(1).lower() == EXPECTED_ORG
    # git (or gh without an explicit repo): resolve the local origin remote
    try:
        url = subprocess.run(
            ["git", "-C", cwd or ".", "remote", "get-url", "origin"],
            capture_output=True, text=True, timeout=3,
        ).stdout.strip()
    except Exception:
        return None
    return (EXPECTED_ORG in url.lower()) if url else None


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        allow()

    if data.get("tool_name") != "Bash":
        allow()
    cmd = (data.get("tool_input") or {}).get("command") or ""
    if not cmd:
        allow()

    # Already running as the bot, or an explicit opt-out -> allow.
    if "bot-auth.sh" in cmd or re.search(r'\bGH_TOKEN=', cmd) or "agentic:allow-ambient" in cmd:
        allow()

    if not WRITE_RE.search(cmd):
        allow()

    cwd = data.get("cwd") or os.getcwd()
    if targets_expected_org(cmd, cwd) is not True:  # None (unknown) or False -> fail-open
        allow()

    reason = (
        f"BLOCKED by agentic-dev: a git/gh write to the {EXPECTED_ORG} org must run as "
        "the configured bot, but this command does not assume it.\n"
        "Re-run inside a block that first does:\n"
        '  source "${CLAUDE_PLUGIN_ROOT}/scripts/bot-auth.sh" || exit 1\n'
        "(fail-fast — never fall back to a personal account).\n"
        "`gh pr review` (the human reviewer's verb) is exempt. For a deliberate "
        "non-bot action, append '# agentic:allow-ambient'. See git-collaboration -> Bot identity."
    )
    print(reason, file=sys.stderr)
    sys.exit(2)


if __name__ == "__main__":
    main()
