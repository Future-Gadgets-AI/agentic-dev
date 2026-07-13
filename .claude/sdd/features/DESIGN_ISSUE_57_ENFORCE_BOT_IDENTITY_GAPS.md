# DESIGN — ISSUE_57_ENFORCE_BOT_IDENTITY_GAPS

**Source issue:** `Future-Gadgets-AI/agentic-dev#57` — [BUG] enforce-bot-identity hook: org writes
pass ambient via missing verbs and org-resolution fail-open

Security-sensitive bugfix, not a system design: `plugin/hooks/enforce-bot-identity.py` (a
`PreToolUse(Bash)` hook, wired via `plugin/hooks/hooks.json`, unchanged by this design) is
defense-in-depth against a forgotten `source bot-auth.sh` — it should deny any git/gh **write to
the bot's org** that doesn't run as the bot. Two gap classes let ambient writes slip through today
(missing `gh repo *` / `gh api graphql` mutation verbs; org-resolution fail-open on an
unresolvable or URL-form target), plus one policy tightening (`gh pr merge` must require the
marker regardless of identity). The three binding policy decisions were already made by the repo
owner on the issue and are restated below for traceability, not re-derived. Every behavior in this
design traces back to one of AC1–AC12 or an explicitly named edge case; where the issue text left
a genuine gap, it's called out under **Open questions**, not silently decided.

This entire design was prototyped and executed against real fixtures before being written down —
see **Verification evidence** in each of the two implementation sections below. Nothing in this
document is untested pseudocode.

## Policy recap (binding, not re-litigated — `Future-Gadgets-AI/agentic-dev#57` policy-decisions comment)

1. **Repo verbs.** `gh repo create|delete|rename|edit|archive` against the org join the
   deny-ambient list, escapable only via `# agentic:allow-ambient`.
2. **Merge policy.** `gh pr merge` requires the marker **even under ambient identity** — an
   unmarked merge is denied regardless of who it authenticates as.
3. **Fail mode.** Unresolvable org target + high-consequence verb (`pr merge`, `repo delete`) ⇒
   fail CLOSED, message names the marker escape. Every other verb keeps fail-open. URL-form target
   parsing shrinks the ambiguity surface for **every** verb, not just the two fail-closed ones.
4. Also in scope per the issue body: `gh api graphql` with a `mutation` payload matches as a write.

---

## 1. Code plan — `plugin/hooks/enforce-bot-identity.py`

### 1.1 Summary of changes, mapped to ACs

| Region | Change | AC(s) |
|---|---|---|
| Module docstring | Rewrite the "Fail-OPEN" bullet to name the two fail-closed exceptions; extend the "Escape hatch" bullet to note the marker is the *only* thing that bypasses an unmarked merge | traceability only, no behavior |
| `WRITE_RE` comment | Reverse the "`gh repo *` is absent (human admin ops)" claim; explain why `gh pr merge` is deliberately *not* in this regex | traceability only |
| `WRITE_RE` | Add `gh repo (create\|delete\|rename\|edit\|archive)` alternative | AC1, AC2, AC10 |
| `WRITE_RE` | Remove `merge` from the `gh pr` alternative (moves to its own gate — see 1.2) | AC6, AC7, AC8 |
| `WRITE_RE` | Add `gh api graphql ... mutation` alternative (cross-newline safe) | AC3, AC4 |
| New: `MERGE_RE` | Standalone compiled regex, `gh pr merge` | AC6, AC7, AC8 |
| New: `REPO_DELETE_RE` | Standalone compiled regex, `gh repo delete` | AC9, AC10 |
| New: `deny(reason)` helper | Symmetric to the existing `allow()`, replaces the inline `print`+`sys.exit(2)` at the bottom of `main()` | no behavior change, enables the 3 distinct reasons below |
| `targets_expected_org()` | New URL-form branch (`github.com[:/]OWNER/`), inserted **before** the cwd-remote fallback | AC5 |
| `main()` | Restructured control flow — marker check, then a dedicated merge gate *before* the bot-auth/GH_TOKEN identity-bypass check, then the identity bypass, then `WRITE_RE`, then org resolution with the repo-delete-only fail-closed carve-out | AC6, AC7, AC8, AC9, AC11 |
| New constants: `AMBIENT_WRITE_REASON`, `MERGE_REASON`, `REPO_DELETE_REASON` | Three distinct denial messages (the original inline message is preserved byte-for-byte, just hoisted to a module constant for consistency with the two new ones) | AC1, AC6, AC9 |

No other file changes are required to close AC1–AC11 — see the **File manifest** and **Out of
scope** sections. `hooks.json` is untouched (same matcher, same invocation).

### 1.2 The critical ordering: merge-gate before the identity-bypass shortcut

This is the single most important control-flow fact in this design, called out explicitly because
getting it backwards silently reintroduces the exact bug AC6 exists to close:

> The merge-marker-required-regardless-of-identity rule (AC6/AC7/AC8) **must** run before the
> existing early-exit shortcut that allows any command containing `bot-auth.sh` or `GH_TOKEN=`.
> If the identity shortcut ran first, a bot-authed (or `GH_TOKEN=`-carrying) **unmarked** `gh pr
> merge` would hit `bot-auth.sh` in cmd → `allow()` and exit before the merge-specific check ever
> ran — exactly the wrong-slips-through failure mode the DEFINE names.

Concretely, `main()`'s checks run in this order, each one an unconditional early exit:

1. **Parse / shape guards** (unchanged): bad JSON → allow; `tool_name != "Bash"` → allow; empty
   `command` → allow. `cwd` is now resolved here too (moved up from its old position near the
   bottom, since the new merge gate in step 3 needs it — pure reordering, no behavior change,
   `os.getcwd()` is a cheap, side-effect-free call either way).
2. **Marker check** (`"agentic:allow-ambient" in cmd`) → allow. Universal, runs before *everything
   else*, including the merge gate — this is what makes AC7 ("marker escapes an unmarked merge")
   correct: the marker is checked strictly before the merge-specific deny.
3. **Merge gate** (`MERGE_RE.search(cmd)`) — new, and the reason this whole reordering exists:
   - Resolve the org target. If **confirmed a different org** (`is False`) → `allow()` (AC8 — this
     hook has no opinion on other orgs' merges).
   - Otherwise (confirmed *our* org, **or** unresolved) → `deny(MERGE_REASON)` (AC6).
   - This block is reached for every `gh pr merge` command regardless of `bot-auth.sh`/`GH_TOKEN=`
     presence, because it runs *before* step 4 below ever gets a chance to short-circuit.
4. **Identity bypass** (`"bot-auth.sh" in cmd or GH_TOKEN=` regex) → allow. Only reached for
   commands that didn't match `MERGE_RE` in step 3 (every write class *except* merge — AC11(b)).
5. `WRITE_RE.search(cmd)` — no match → allow (unchanged).
6. **Org resolution** on the remaining ambient, write-verb-matched command:
   - `resolved is True` (confirmed org) → `deny(AMBIENT_WRITE_REASON)` (this is also how AC1's
     repo-verb block and AC3's graphql-mutation block resolve when tested with a cwd that IS the
     org — no special-casing needed, they fall through to this same pre-existing branch now that
     they're matched by `WRITE_RE`).
   - `resolved is None` **and** `REPO_DELETE_RE.search(cmd)` → `deny(REPO_DELETE_REASON)` (AC9 —
     the one verb whose unresolved default flips).
   - Otherwise (`False`, or `None` for every verb except repo-delete) → `allow()` (AC8's repo-delete
     analogue, AC10).

Note what `gh repo delete` does **not** need, unlike merge: it is *not* pulled ahead of the
identity-bypass check. AC9's own text says "marker still escapes it, bot-auth still escapes it —
only the default-on-unresolved direction changes," so it stays in the normal step-4/5/6 flow and
only changes step 6's `None` branch. Only merge needs the special early gate, because only merge's
policy says identity must **not** be sufficient.

### 1.3 `targets_expected_org()` — URL-form resolution (AC5)

One new branch, inserted between the existing `--repo`/`-R` check and the existing `repos/OWNER` /
`orgs/OWNER` REST-path check (order relative to those two doesn't affect any AC or edge case — no
fixture combines a URL with a conflicting `--repo`/REST-path in the same string — but it must run
before the cwd-remote fallback, which is the one ordering AC5 actually requires):

```python
# URL-form: https://github.com/OWNER/... or git@github.com:OWNER/...
m = re.search(r'\bgithub\.com[:/]([^/\s]+)/', cmd)
if m:
    return m.group(1).lower() == EXPECTED_ORG
```

`[:/]` matches both the HTTPS form (`github.com/OWNER/...`) and the SSH form
(`git@github.com:OWNER/...`) with one pattern. No `re.IGNORECASE` flag — consistent with the
function's two pre-existing checks, which also match their literal markers (`--repo`, `repos/`)
case-sensitively and only lowercase the *captured* comparison value; real URLs are always
lowercase `github.com` in practice, and this function's existing style never special-cased
matcher-literal case, so this doesn't either.

Because `targets_expected_org()` is called from both the new merge gate (1.2, step 3) and the
generic resolution at the bottom (1.2, step 6), URL-form resolution is automatically available to
**every** verb class, exactly as AC5 requires ("for every verb class, not just merge/repo-delete")
— it needed no additional wiring beyond the one function change.

### 1.4 Fail-open → fail-closed scoping for `gh repo delete` (AC9), narrowly

The flip is exactly one condition, guarded by a dedicated regex that matches only the literal verb
`delete` — not `create`, `rename`, `edit`, or `archive`, which stay in `WRITE_RE`'s shared
`gh repo (...)` alternative and therefore keep the ordinary fail-open `None` handling (AC10):

```python
REPO_DELETE_RE = re.compile(r"\bgh\s+repo\s+delete\b", re.IGNORECASE)
...
if resolved is None and REPO_DELETE_RE.search(cmd):
    deny(REPO_DELETE_REASON)
```

This is the narrowest possible scoping: a command has to (a) match `WRITE_RE` at all, (b) resolve
to `None` (not `True` — that's already denied by the line above; not `False` — that's out of
scope), **and** (c) match `REPO_DELETE_RE` specifically. The other four `gh repo *` verbs, and
`gh api graphql ... mutation`, and every other matched verb, all fall through the same `None` case
to the final `allow()` unchanged.

### 1.5 Docstring / comment updates

Per the task brief, both are updated (full text in 1.6):

- **Module docstring's "Fail-OPEN" bullet** now names the two deliberate exceptions (merge always
  needs the marker regardless of identity; repo-delete flips its unresolved default), and the
  "Escape hatch" bullet notes the marker is the only thing that bypasses an unmarked merge.
- **The `WRITE_RE` comment** ("`gh repo *` is absent (human admin ops)") is reversed: it now says
  issue #57 found that assumption false and the verbs are matched below, and separately explains
  why `gh pr merge` is deliberately *not* in this regex (gated in `main()` instead).

### 1.6 Full replacement content — `plugin/hooks/enforce-bot-identity.py`

This is the complete file (195 lines, up from the original 111). It was written to disk and executed against all 54 cases in
section 2.3 before being pasted here — see **Verification evidence** below.

```python
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
```

### 1.7 Design decision — reconciling AC8's wording with AC11's last clause

AC8 is explicit and worked-example-complete: *"`gh pr merge` whose target is **confirmed** a
different org ... ⇒ allow (this hook has no opinion on other orgs' merges — don't widen scope)."*
AC11's regression list ends with a more compressed clause: *"a confirmed-other-org target still
allows (fail-open) for every verb **except the two fail-closed ones**."* Read at face value, that
final clause would contradict AC8 by implying a confirmed-other-org merge should deny.

This design follows AC8, not the literal tail of AC11(i), for the confirmed-other-org (`False`)
case, for both fail-closed verbs (merge **and**, by the same reasoning, repo-delete). Rationale:

- AC8 is a fully-specified, individually-numbered AC with its own explicit worked example and
  rationale sentence — it is unambiguous.
- AC11 is explicitly a *regression* list ("every pre-existing behavior still holds"), summarizing
  claims that are each already pinned down elsewhere. Its wording most plausibly means "the
  fail-open-on-*unresolved* default flips for the two fail-closed verbs" (which is exactly AC9's
  and policy-decision-3's subject — *unresolved* targets, not *confirmed-other-org* ones) and
  simply reused the phrase "confirmed-other-org" imprecisely where "unresolved" was meant. Binding
  policy decision 3 itself only ever pairs "fail CLOSED" with "unresolvable org target," never with
  "confirmed a different org."
- Treating a confirmed-other-org repo-delete the same way as a confirmed-other-org merge (both
  allow) is also the only reading consistent with this hook's own stated scope ("no opinion on
  other orgs'" — stated once, generally, in the Problem statement, not merge-specifically) and
  with "don't widen fail-closed beyond `pr merge`/`repo delete`" (AC10) — widening a *confirmed*
  non-org write into a deny would be widening scope in exactly the direction every other AC pushes
  against.

Test coverage makes this decision falsifiable either way (section 2.2's AC8 group, specifically
`AC8 merge confirmed-other-org via cwd`, plus the AC9 group has no equivalent "confirmed-other-org"
case for repo-delete — see **Open questions** below for why that asymmetry is deliberate, not an
oversight).

---

## 2. Test-file plan — `plugin/hooks/enforce-bot-identity.test.sh`

### 2.1 Harness design

Colocated with the hook (`plugin/hooks/enforce-bot-identity.test.sh`), following
`.github/scripts/check-closing-keyword.test.sh`'s convention exactly: real script, subprocess,
`pass`/`fail` tally, non-zero exit on any failure. Adapted for how *this* hook receives input —
JSON on stdin, not an env var — via three building blocks:

- **`build_payload <command> <cwd>`** — constructs the exact PreToolUse(Bash) JSON shape
  (`{"tool_name": "Bash", "tool_input": {"command": ...}, "cwd": ...}`) using a `python3 -c`
  one-liner with `json.dumps` and `sys.argv`, not hand-rolled string concatenation. python3 is
  already a hard dependency of the hook itself, so this adds no new tooling dependency, and
  `json.dumps` correctly escapes quotes/newlines — needed because the AC3 heredoc fixture (2.2)
  embeds real newlines in the command string.
- **`check_raw <expected 0|2> <desc> <raw stdin text>`** — for fixtures that are not a normal
  (command, cwd) pair: empty stdin, unparseable stdin, non-`Bash` `tool_name`. Feeds the raw text
  directly to `python3 plugin/hooks/enforce-bot-identity.py` on stdin.
- **`check <expected 0|2> <desc> <command> <cwd>`** — the common case; builds the payload via
  `build_payload` then delegates to `check_raw`.

Both assert the **exact** exit code (0 or 2) via `[ "$got" -eq "$expected" ]` — no normalization of
non-zero to a generic "1" the way `check-closing-keyword.test.sh` does (that script only ever
produces 0/1; this hook's contract is specifically 0/2, and an uncaught crash producing some other
code should show up as a *failed* assertion, not be silently coerced into looking like a correct
deny). On failure, the hook's captured stderr is printed under the `FAIL` line for debuggability.

`set -uo pipefail` (no `-e`), matching the sibling file's own reasoning — the script must keep
running every case even after an individual `check` "fails," tallying at the end. The file carries
a `#!/usr/bin/env bash` shebang but is always invoked explicitly as `bash
plugin/hooks/enforce-bot-identity.test.sh` (stated in its own header, matching the sibling's `Run:`
line) — so it runs under bash regardless of the caller's login shell (this environment's Bash tool
runs zsh by default), and no zsh-safety concern applies the way it would for a *sourced* file.

**cwd fixtures — exactly how to construct them (per the task's explicit instruction not to leave
this to guesswork):**

| Fixture | Resolves to | How it's built |
|---|---|---|
| `ORG_CWD` | `True` via cwd-remote fallback | `"$(cd "${SCRIPT_DIR}/../.." && pwd)"` — the test file lives at `plugin/hooks/`, so two directories up is the repo root. **Not** a hardcoded absolute path (a fixed path like the design session's own scratch-clone location would be invalid the moment this file is checked out anywhere else) — this resolves correctly in any clone of `Future-Gadgets-AI/agentic-dev`, verified against the actual remote (`https://github.com/Future-Gadgets-AI/agentic-dev.git`) during this design. |
| `NOGIT_CWD` | `None` (unresolvable) | `mktemp -d` — a fresh, empty temp directory with no `.git` at all. `git -C <dir> remote get-url origin` fails (empty stdout), so `targets_expected_org` returns `None`. |
| `OTHERORG_CWD` | `False` (confirmed a different org) | `mktemp -d`, then `git -C "$dir" init -q && git -C "$dir" remote add origin https://github.com/some-other-org/some-other-repo.git`. |

`NOGIT_CWD`/`OTHERORG_CWD` are **real `mktemp -d` temp directories, never subdirectories of the
repo tree** — a nested `git init` inside the repo would corrupt `git status` for the outer repo
(submodule-like confusion) if ever created there by mistake. Both are removed via `trap cleanup
EXIT` so a run never leaves stray temp directories behind (`ORG_CWD` needs no cleanup — it's a
read-only reference to the existing checkout, never written to).

### 2.2 Full test-file content

This is the complete file. Every case is labeled with the AC (or edge case) it covers per the
task's instruction to specify "exact fixture command strings and expected exit codes... don't
leave this to the build agent's judgment." It was executed for real — see **Verification
evidence**, 2.3.

```bash
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
check 2 'AC5 https URL resolves org despite non-org cwd (gh issue comment)' \
  'gh issue comment 5 --body "see https://github.com/Future-Gadgets-AI/agentic-dev/issues/1"' \
  "$NOGIT_CWD"
check 2 'AC5 ssh URL resolves org despite non-org cwd (git push by URL)' \
  'git push git@github.com:Future-Gadgets-AI/agentic-dev.git HEAD:main' \
  "$NOGIT_CWD"

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
```

### 2.3 Verification evidence (design-time, real execution — not a paraphrase)

The hook content from 1.6 and the test file from 2.2 were both written to disk and actually
executed together during this design (`bash plugin/hooks/enforce-bot-identity.test.sh`, hook and
test file colocated exactly as they will be in the repo, `ORG_CWD` resolved via the real
`$SCRIPT_DIR/../..` relative-path construction against a git-inited directory carrying the real
org remote). Full transcript:

```
=== AC1 — repo-verb block (gh repo create|delete|rename|edit|archive), ambient, org via cwd ===
ok   [exit 2] AC1 repo create
ok   [exit 2] AC1 repo delete
ok   [exit 2] AC1 repo rename
ok   [exit 2] AC1 repo edit
ok   [exit 2] AC1 repo archive
=== AC2 — repo-verb marker escape ===
ok   [exit 0] AC2 repo create + marker
ok   [exit 0] AC2 repo delete + marker
=== AC3 — graphql-mutation block ===
ok   [exit 2] AC3 graphql -f mutation
ok   [exit 2] AC3 graphql heredoc mutation (keyword only in the heredoc body)
=== AC4 — graphql-mutation marker escape ===
ok   [exit 0] AC4 graphql mutation + marker
=== AC5 — URL-form org resolution, before the cwd fallback, for a non-merge/repo-delete verb ===
ok   [exit 2] AC5 https URL resolves org despite non-org cwd (gh issue comment)
ok   [exit 2] AC5 ssh URL resolves org despite non-org cwd (git push by URL)
=== AC6 — gh pr merge: unmarked block regardless of identity or how the target resolves ===
ok   [exit 2] AC6 URL merge, ambient, unresolved cwd
ok   [exit 2] AC6 URL merge, bot-auth.sh present (!!)
ok   [exit 2] AC6 URL merge, GH_TOKEN= present (!!)
ok   [exit 2] AC6 bare merge, confirmed org via cwd
ok   [exit 2] AC6 bare merge, target fails to resolve
=== AC7 — merge marker escape, regardless of identity ===
ok   [exit 0] AC7 URL merge + marker, ambient
ok   [exit 0] AC7 bare merge + marker, org cwd
=== AC8 — merge out-of-org passthrough (hook has no opinion on other orgs' merges) ===
ok   [exit 0] AC8 merge --repo confirms other org
ok   [exit 0] AC8 merge non-org URL
ok   [exit 0] AC8 merge confirmed-other-org via cwd
=== AC9 — repo-delete fails CLOSED when unresolvable; marker/bot-auth/GH_TOKEN= still escape it ===
ok   [exit 2] AC9 repo delete, unresolved, ambient
ok   [exit 0] AC9 repo delete, unresolved + marker
ok   [exit 0] AC9 repo delete, unresolved + bot-auth
ok   [exit 0] AC9 repo delete, unresolved + GH_TOKEN=
=== AC10 — every OTHER matched write verb still fails OPEN when unresolvable (narrow scoping) ===
ok   [exit 0] AC10 gh issue create, unresolved
ok   [exit 0] AC10 git commit, unresolved
ok   [exit 0] AC10 gh label create, unresolved
ok   [exit 0] AC10 gh repo create, unresolved
ok   [exit 0] AC10 gh repo rename, unresolved
ok   [exit 0] AC10 gh repo edit, unresolved
ok   [exit 0] AC10 gh repo archive, unresolved
ok   [exit 0] AC10 graphql mutation, unresolved
=== AC11 — regression: every pre-existing behavior still holds ===
ok   [exit 2] AC11 git commit in-org ambient blocked (pre-existing)
ok   [exit 2] AC11 git push in-org ambient blocked (pre-existing)
ok   [exit 0] AC11 bot-auth allows git commit
ok   [exit 0] AC11 GH_TOKEN= allows gh issue create
ok   [exit 0] AC11 marker allows git commit
ok   [exit 0] AC11 gh pr review stays exempt (never matched)
ok   [exit 0] AC11 non-Bash tool_name allowed
ok   [exit 0] AC11 empty stdin allowed
ok   [exit 0] AC11 unparseable stdin allowed
ok   [exit 0] AC11 no write verb (gh issue list)
ok   [exit 0] AC11 no write verb (git status)
ok   [exit 2] AC11 --repo owner/repo resolution still works
ok   [exit 2] AC11 -R owner/repo resolution still works
ok   [exit 2] AC11 repos/owner resolution still works
ok   [exit 2] AC11 orgs/owner resolution still works
ok   [exit 0] AC11 confirmed-other-org via --repo still allows
ok   [exit 0] AC11 confirmed-other-org via cwd still allows
=== Edge cases (DEFINE, explicit — must keep passing) ===
ok   [exit 0] edge: night-shift documented merge form (url + marker)
ok   [exit 0] edge: bot-auth allows a non-merge write in-org
ok   [exit 0] edge: unrelated non-org working directory allowed
---
passed: 54   failed: 0
```

Also checked during this design (all against the exact 1.6 content): `python3 -m py_compile`
clean; `ruff check` (default ruleset) clean; no line exceeds 100 columns (matches the original
file's own convention — it has none over 100 either). `bash -n` on the 2.2 test file is clean.

As independent grounding that these are real, previously-existing gaps (not hypothetical), the
five most significant new-deny cases (AC1 repo-create, AC3 graphql-mutation, AC6
bot-auth-present-merge, AC9 repo-delete-unresolved, AC5 URL-form) were also run against the
**unmodified** `plugin/hooks/enforce-bot-identity.py` on `main` — every one of them returns exit 0
(wrongly **allow**) today, confirming the DEFINE's problem statement and giving each fix a real
before/after.

Build must re-run this transcript for real against the actual committed files (not reuse this
one) — this is design-time verification of the plan, not the verify-gate's own evidence, which the
DEFINE's Test requirements section requires as "a real execution (not a paraphrase)."

---

## 3. AC12 — plugin validity

`claude plugin validate plugin/` was run against the current tree (before any edit in this design)
and passes:

```
Validating plugin manifest: <repo>/plugin/.claude-plugin/plugin.json
✔ Validation passed
```

Neither change in this design is structural — both edits are content-only changes to an existing
file (`enforce-bot-identity.py`) and one new file colocated in an existing directory
(`enforce-bot-identity.test.sh`, alongside the existing `hooks.json`). No manifest field, no
directory layout, no hook registration changes. Build should re-run `claude plugin validate
plugin/` after making the edits and confirm it still exits 0 — this is AC12's own requirement, not
optional, and the task brief explicitly asked this be called out so build doesn't skip it.

Separately (not one of AC1–AC12, flagged only for build's awareness): this repo's
`.github/workflows/bump-gate.yml` runs a `plugin-validate` job on any PR that touches `plugin/`
(which this one does) — the same `claude plugin validate plugin/` command — and a *separate*
`bump-gate` job requires `plugin/.claude-plugin/plugin.json`'s version to be bumped above `main`'s
whenever `plugin/` changes (`plugin/scripts/bump.sh --check`, waivable only via a `no-release`
label). This is a pre-existing, mechanical, repo-wide gate unrelated to issue #57's own policy —
not something this design is introducing or mandating — but build/PR-creation will hit it
regardless, so it's noted here rather than being a surprise later.

---

## File manifest

| # | File | Action | Agent | AC(s) |
|---|------|--------|-------|-------|
| 1 | `plugin/hooks/enforce-bot-identity.py` | Edit — full replacement content given in 1.6 | general — Python, precise control-flow, exact content given, no specialist judgment needed | AC1–AC11 |
| 2 | `plugin/hooks/enforce-bot-identity.test.sh` | Create — full content given in 2.2 | general — bash, exact fixtures given, no specialist judgment needed | AC1–AC11 + regressions |

No other file requires a change to satisfy AC1–AC12 (`hooks.json` is unchanged; see **Out of
scope** for what else was considered and deliberately not touched).

---

## Open questions flagged for build/verify stage

These are genuine gaps the DEFINE file doesn't name. Neither is invented policy — both are
pre-existing characteristics of `targets_expected_org()` that this design doesn't change, flagged
so build doesn't "fix" them as undocumented scope creep and so verify/review isn't surprised if a
reviewer notices them independently.

1. **Positional `OWNER/REPO` arguments are still unresolved.** `targets_expected_org()` resolves
   `--repo`/`-R OWNER/REPO`, a `github.com` URL, or a `repos/OWNER`/`orgs/OWNER` REST path — but
   several `gh repo <verb>` invocations take the target as a **bare positional** argument (e.g.
   `gh repo edit Future-Gadgets-AI/some-repo --description x`, `gh repo rename new-name
   Future-Gadgets-AI/old-repo`). None of the three structured checks match that shape, so such a
   command run from an unrelated cwd resolves `None`, not `True`. For `gh repo delete` this is
   safe by construction (AC9 now denies on `None` too — same outcome, different reason). For the
   other four `gh repo *` verbs (which keep the AC10 fail-open default on `None`), this means a
   command that unambiguously names the org *positionally* could still be allowed ambient. No AC
   or edge case in the DEFINE names positional-argument parsing, and the DEFINE's own "Out of
   scope" section places the general class of cwd/target-resolution false-negatives outside this
   issue's boundary (via the explicitly out-of-scope harness-cwd-vs-actual-cwd bug) — so this
   design does not add a fourth resolution branch for it. Flagging for awareness, not fixing.
2. **AC8 vs. AC11's last clause** — already resolved with explicit rationale in section 1.7, listed
   here too because it's the kind of place-value judgment call the task asked to be surfaced rather
   than silently made. If the repo owner disagrees with the reading in 1.7, the fix is a one-line
   change (drop the `is False` short-circuit in the merge gate, and add the analogous check to the
   repo-delete branch) — flagging so that's a quick, deliberate revisit rather than a silent guess
   discovered later.

---

## Out of scope — confirmed, not touched

Per the DEFINE's own "Out of scope" section, re-confirmed against the live tree during this design:

- **The harness-cwd-vs-actual-cwd false positive** (issue comment 2) — a different bug (the
  PreToolUse harness's reported `cwd` can mismatch the Bash tool call's *actual* working directory
  when a command itself does `cd`). Not one of the three binding policy decisions; not touched.
- **`plugin/hooks/hooks.json`** — no change. Same matcher (`Bash`), same invocation
  (`python3 "${CLAUDE_PLUGIN_ROOT}/hooks/enforce-bot-identity.py"`).
- **Any hook other than `enforce-bot-identity.py`** — none exist in `plugin/hooks/` besides this
  one (confirmed: the directory contains only `enforce-bot-identity.py` and `hooks.json`).
- **CI wiring for the new test file** — the DEFINE is explicit that this is not in the DoD; no
  `.github/workflows/*.yml` is added or edited to run `enforce-bot-identity.test.sh`. The verify
  gate is the captured local execution transcript (section 2.3 here is the design-time version;
  build/verify owns the real one).
- **`plugin/skills/git-collaboration/SKILL.md`'s "Bot identity" section** — its prose ("it fails
  *open* on ambiguity") describes the hook's *old*, fully-fail-open stance and is now only
  partially accurate (two verbs now fail closed on an unresolved target). The task brief for this
  design scoped documentation updates specifically to the hook's own module docstring and the
  `gh repo *` comment (section 1.5) — it did not name this skill file, and the DEFINE's AC list is
  scoped to "exactly five code changes to `plugin/hooks/enforce-bot-identity.py`" plus the new test
  file, nothing else. Left unedited here; noted so a reviewer doesn't wonder whether it was missed.
  If this drift should be fixed, it's a small follow-up, not part of issue #57's own scope.

---

## Verification checklist for build/verify

1. Write the 1.6 content to `plugin/hooks/enforce-bot-identity.py` (full-file replacement).
2. Create `plugin/hooks/enforce-bot-identity.test.sh` with the 2.2 content; `chmod +x` it
   (matching the executable bit on `enforce-bot-identity.py` and on the sibling
   `check-closing-keyword.test.sh`).
3. Run `bash plugin/hooks/enforce-bot-identity.test.sh` for real against the committed files;
   confirm `passed: 54   failed: 0` (or investigate any delta from this design's own transcript in
   2.3 — a delta here means either this document or the committed files disagree, and that must be
   resolved before proceeding, not silently accepted).
4. Run `python3 -m py_compile plugin/hooks/enforce-bot-identity.py` and, if available, `ruff check
   plugin/hooks/enforce-bot-identity.py`.
5. Run `claude plugin validate plugin/`; confirm `✔ Validation passed` (AC12).
6. Capture the real transcripts from steps 3 and 5 as the verify-gate evidence (per the DEFINE's
   Test requirements: "a real execution (not a paraphrase)").
7. Cite `Future-Gadgets-AI/agentic-dev#57` (not this DESIGN doc's own path, and not the gitignored
   DEFINE synthesis doc that was this design's own input) as the requirements source in any
   committed artifact, per this repo's own convention (`fix(implement-skill): committed artifacts
   must cite the source issue, not the gitignored DEFINE`).

---

**Status: ready for Build.** 2 files (1 edit, 1 create), 0 structural plugin changes, 0 git/gh
operations performed by this design phase. Both files' exact content was verified by real
execution before being written into this document (section 2.3).
