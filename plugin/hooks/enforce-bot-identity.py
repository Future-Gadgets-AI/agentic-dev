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
- Fail-OPEN by default: on any ambiguity (can't parse, can't resolve the org) it
  ALLOWS. This is heuristic defense-in-depth, not a cryptographic guarantee — the
  skills' source lines remain the primary mechanism, and a false block is worse than
  a rare miss. Two deliberate exceptions (issue #57):
    * `gh pr merge` ALWAYS requires the `agentic:allow-ambient` marker, even when
      the command already runs as the bot (bot-auth.sh sourced / GH_TOKEN= set).
      Merges are the one deliberate, always-human-or-explicitly-marked decision
      (the constitution's merge rule) — identity alone never bypasses this verb.
    * `gh repo delete` fails CLOSED (denies) when its org target can't be resolved
      at all. Repo deletion is high-consequence enough that "can't tell" should
      deny, not allow — the marker and bot-auth/GH_TOKEN= still bypass it normally;
      only the *unresolved-target default* flips, and only for this one verb. Every
      other write verb, including the other `gh repo *` verbs, keeps fail-open.
- Escape hatch: put the marker `agentic:allow-ambient` in a command to bypass —
  the only thing that bypasses an unmarked `gh pr merge`.

PreToolUse contract: exit 0 = allow; exit 2 = block, with the reason on stderr.
"""
import json
import os
import re
import subprocess
import sys

EXPECTED_ORG = os.environ.get("AGENTIC_BOT_ORG", "Future-Gadgets-AI").lower()

# The write verbs the skills actually use. `gh pr review` is intentionally absent
# (it's the human reviewer's verb). `gh repo create/delete/rename/edit/archive` WAS
# assumed to be human-only admin ops — issue #57 found agent sessions do call these,
# so they're matched below like every other write verb. `gh pr merge` is
# deliberately NOT matched here: it's gated separately in main() via MERGE_RE,
# unconditionally, because it needs the marker-required-regardless-of-identity rule
# this regex alone can't express (see MERGE_RE below).
WRITE_RE = re.compile(
    r"""
      \bgit\s+commit\b
    | \bgit\s+push\b
    | \bgh\s+issue\s+(?:create|edit|close|reopen|comment|delete|transfer|lock|unlock|pin|unpin)\b
    | \bgh\s+pr\s+(?:create|edit|close|reopen|ready|comment|lock|unlock)\b
    | \bgh\s+repo\s+(?:create|delete|rename|edit|archive)\b
    | \bgh\s+label\s+(?:create|edit|delete|clone)\b
    | \bgh\s+release\s+(?:create|edit|delete)\b
    | \bgh\s+api\b[^\n]*\s(?:-X|--method)\s+(?:POST|PUT|PATCH|DELETE)\b
    | \bgh\s+api\b[^\n]*requested_reviewers
    | \bgh\s+api\s+graphql\b[\s\S]*\bmutation\b
    """,
    re.VERBOSE | re.IGNORECASE,
)

# `gh pr merge` — gated separately from WRITE_RE (see main()): unlike every other
# verb, identity alone (bot-auth.sh / GH_TOKEN=) must NOT bypass it, only the
# `agentic:allow-ambient` marker may (issue #57, binding policy decision 2).
MERGE_RE = re.compile(r"\bgh\s+pr\s+merge\b", re.IGNORECASE)

# `gh repo delete` — the one verb whose *unresolved*-target default flips from
# allow to deny (issue #57, binding policy decision 3). Every other `gh repo *`
# verb (matched above, in WRITE_RE) keeps the fail-open default.
REPO_DELETE_RE = re.compile(r"\bgh\s+repo\s+delete\b", re.IGNORECASE)


def allow():
    """Not applicable / ambiguous -> let the tool call proceed."""
    sys.exit(0)


def deny(reason):
    """Block the tool call, with the reason on stderr."""
    print(reason, file=sys.stderr)
    sys.exit(2)


def targets_expected_org(cmd, cwd):
    """True/False if we can determine the target org, else None (unknown)."""
    # gh --repo OWNER/REPO  or  -R OWNER/REPO
    m = re.search(r'(?:--repo|-R)[=\s]+([^/\s]+)/', cmd)
    if m:
        return m.group(1).lower() == EXPECTED_ORG
    # URL-form: https://github.com/OWNER/... or git@github.com:OWNER/... (issue #57,
    # binding policy decision 3). Checked before the cwd-remote fallback so a
    # `gh pr merge <url>` (or any command carrying a github.com URL) resolves
    # without the fallback ever running — for every verb class, not just
    # merge/repo-delete.
    m = re.search(r'\bgithub\.com[:/]([^/\s]+)/', cmd)
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


AMBIENT_WRITE_REASON = (
    f"BLOCKED by agentic-dev: a git/gh write to the {EXPECTED_ORG} org must run as "
    "the configured bot, but this command does not assume it.\n"
    "Re-run inside a block that first does:\n"
    '  source "${CLAUDE_PLUGIN_ROOT}/scripts/bot-auth.sh" || exit 1\n'
    "(fail-fast — never fall back to a personal account).\n"
    "`gh pr review` (the human reviewer's verb) is exempt. For a deliberate "
    "non-bot action, append '# agentic:allow-ambient'. See git-collaboration -> Bot identity."
)

MERGE_REASON = (
    f"BLOCKED by agentic-dev: `gh pr merge` against the {EXPECTED_ORG} org always "
    f"requires the '# agentic:allow-ambient' marker whenever its target is (or can't be "
    f"proven NOT to be) the {EXPECTED_ORG} org — even when this command already runs as "
    "the configured bot (bot-auth.sh / GH_TOKEN=). Merges are a deliberate, "
    "explicitly-marked decision; identity alone is not enough for this one verb.\n"
    "If this merge is intentional, append '# agentic:allow-ambient' (delegated-human "
    "/ night-shift sessions already do this for every merge). See git-collaboration "
    "-> Bot identity."
)

REPO_DELETE_REASON = (
    f"BLOCKED by agentic-dev: this `gh repo delete` command's target org could not be "
    f"resolved, and a possible write to the {EXPECTED_ORG} org is high-consequence enough "
    "that an unresolved target defaults to DENY (the opposite default from every other "
    "write verb).\n"
    "Make the target explicit (`--repo <owner>/<repo>`), run inside a block that "
    'first does `source "${CLAUDE_PLUGIN_ROOT}/scripts/bot-auth.sh" || exit 1`, or '
    "for a deliberate non-bot action append '# agentic:allow-ambient'. See "
    "git-collaboration -> Bot identity."
)


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
    cwd = data.get("cwd") or os.getcwd()

    # The marker is a universal escape hatch, checked first, for every write class
    # — including an otherwise-unmarked `gh pr merge` (AC7).
    if "agentic:allow-ambient" in cmd:
        allow()

    # `gh pr merge` requires the marker regardless of identity (AC6/AC7/AC8). This
    # gate MUST run before the bot-auth/GH_TOKEN identity-bypass check below, or a
    # bot-authed (or GH_TOKEN=-carrying) unmarked merge would wrongly slip through
    # that shortcut before ever reaching this check.
    if MERGE_RE.search(cmd):
        if targets_expected_org(cmd, cwd) is False:  # confirmed a DIFFERENT org
            allow()  # out of scope for this hook (AC8) — no opinion on other orgs
        deny(MERGE_REASON)  # confirmed our org, or unresolved -> deny (AC6)

    # Already running as the bot, or an explicit GH_TOKEN -> allow (every
    # remaining write class; merge was already handled above and never reaches
    # here).
    if "bot-auth.sh" in cmd or re.search(r'\bGH_TOKEN=', cmd):
        allow()

    if not WRITE_RE.search(cmd):
        allow()

    resolved = targets_expected_org(cmd, cwd)
    if resolved is True:
        deny(AMBIENT_WRITE_REASON)
    if resolved is None and REPO_DELETE_RE.search(cmd):
        deny(REPO_DELETE_REASON)  # AC9: this one verb fails CLOSED on unresolved

    allow()  # False (confirmed other org), or None for every other verb (fail-open)


if __name__ == "__main__":
    main()
