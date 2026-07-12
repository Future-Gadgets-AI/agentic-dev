# DESIGN — ISSUE_64_CONFIG_ENV_VAR_NAMING

**Source issue:** `Future-Gadgets-AI/agentic-dev#64` — [TASK] Reconcile AGENTIC_DEV_CONFIG vs AGENTIC_DEV_CONFIG_DIR env-var naming across scripts

Surgical reconciliation, not a system design: `bot-auth.sh` reads the deprecated
`AGENTIC_DEV_CONFIG` (a full file path) while four other readers standardized on
`AGENTIC_DEV_CONFIG_DIR` (a directory). A user who sets one name but not the other gets
scripts silently disagreeing on where the bot's credentials live. This design applies one
precedence rule everywhere: canonical dir var → deprecated var (warn once, stderr) → existing
default.

**Ground truth, re-verified independently for this design** (not assumed from the synthesized
DEFINE doc — grep run fresh against the live tree on `fix/config-dir-env-var`):

```
$ grep -rn "AGENTIC_DEV_CONFIG_DIR" --include="*.sh" --include="*.md" plugin/
plugin/scripts/needs-me.sh:70:CFG="${AGENTIC_DEV_CONFIG_DIR:-$HOME/.config/agentic-dev}/credentials"
plugin/scripts/repo-standard-diff.sh:85:CFG="${AGENTIC_DEV_CONFIG_DIR:-$HOME/.config/agentic-dev}/credentials"
plugin/scripts/setup-bot.sh:12,15:  (write path — out of scope, see below)
plugin/commands/harden-repo.md:44:CFG="${AGENTIC_DEV_CONFIG_DIR:-$HOME/.config/agentic-dev}/credentials"
plugin/commands/harden-repo.md:106:CFG="${AGENTIC_DEV_CONFIG_DIR:-$HOME/.config/agentic-dev}/credentials"
plugin/skills/init/SKILL.md:24:ls -l "${AGENTIC_DEV_CONFIG_DIR:-$HOME/.config/agentic-dev}/credentials" ...

$ grep -rn "AGENTIC_DEV_CONFIG\b" --include="*.sh" --include="*.md" plugin/ | grep -v _DIR
plugin/scripts/bot-auth.sh:18:  local cfg="${AGENTIC_DEV_CONFIG:-$HOME/.config/agentic-dev/credentials}"

$ grep -n "AGENTIC_DEV_CONFIG" README.md ARCHITECTURE.md
(no matches)
```

Confirms the DEFINE's resolution facts exactly: 4 canonical-only readers (`needs-me.sh`,
`repo-standard-diff.sh`, `harden-repo.md` ×2, `init/SKILL.md`) + 1 write-path canonical-only
user (`setup-bot.sh`, out of scope) vs. exactly 1 deprecated-only reader (`bot-auth.sh`); zero
hits in `README.md`/`ARCHITECTURE.md`.

## Approach

Every reader of the bot-credentials config location applies the same three-step precedence:

1. **`AGENTIC_DEV_CONFIG_DIR`** (canonical, a directory) — if set and non-empty, the
   credentials file is `$AGENTIC_DEV_CONFIG_DIR/credentials`.
2. **Else `AGENTIC_DEV_CONFIG`** (deprecated) — if set and non-empty, use it and print
   exactly one deprecation line to stderr.
3. **Else** the existing default — `$HOME/.config/agentic-dev/credentials` (already spelled
   `${...:-$HOME/.config/agentic-dev}/credentials` in the 4 already-canonical readers).

**The one deliberate asymmetry: what shape does the deprecated var mean once honored?**
`bot-auth.sh` is the sole *pre-existing* reader of `AGENTIC_DEV_CONFIG`, and its pre-issue-64
semantics already treat it as a full file path directly — `local cfg="${AGENTIC_DEV_CONFIG:-...}"`
is used as-is, never `"$AGENTIC_DEV_CONFIG/credentials"`. Reconciling priority (canonical now
checked first) must not also silently reconcile *shape* — only the priority changes, the
deprecated var's meaning does not. This carries forward as a design decision (below) to the
three readers that never honored `AGENTIC_DEV_CONFIG` before: `AGENTIC_DEV_CONFIG`, wherever
honored, always means "the credentials file itself"; `AGENTIC_DEV_CONFIG_DIR`, wherever
honored, always means "the directory containing it." One name, one shape, everywhere — that is
what actually closes the "same override, different resolved location" bug the issue describes;
treating the deprecated name as a directory in three readers and a file in the fourth would just
relocate the original inconsistency under a single env-var name instead of removing it.

### Config-resolution call graph

```
 write path (out of scope, unaffected):
   setup-bot.sh ─────────────────────────▶ writes credentials file at
                                             $AGENTIC_DEV_CONFIG_DIR/credentials  (canonical-only)

 read paths (this design — same precedence, applied independently in each):
   bot-auth.sh            (sourced)   ┐
   needs-me.sh             (executed) │   AGENTIC_DEV_CONFIG_DIR set? → $AGENTIC_DEV_CONFIG_DIR/credentials
   repo-standard-diff.sh   (executed) ├─▶ else AGENTIC_DEV_CONFIG set? → $AGENTIC_DEV_CONFIG (+1-line warn, stderr)
   harden-repo.md A2       (embedded) │   else                        → ~/.config/agentic-dev/credentials
   harden-repo.md C        (embedded) ┘

 init/SKILL.md's existing-credentials probe: canonical-only, UNCHANGED — gains one doc line
 pointing at the read-path fallback above.
```

## Acceptance criteria (restated from the issue, for traceability — not re-litigated)

| AC | Requirement |
|----|-------------|
| AC-1 | Every config-resolving script applies the same precedence. Touches `bot-auth.sh`, `needs-me.sh`, `repo-standard-diff.sh`. |
| AC-2 | `bot-auth.sh` prefers the canonical dir var first; deprecated fallback keeps its exact pre-existing full-file-path semantics. |
| AC-3 | `needs-me.sh` and `repo-standard-diff.sh` gain the deprecated-name fallback + warning. |
| AC-4 | `harden-repo.md`'s A2 and C snippets get the same pattern, independently (neither sources `bot-auth.sh`). |
| AC-5 | `init/SKILL.md`'s existing-credentials probe stays canonical-only; add one line noting the read-path fallback. |
| AC-6 | No doc introduces the deprecated name as a first-class option — fallback only, one line. |
| AC-7 | Each script keeps its existing style/minimal diff; doc-embedded snippets are zsh-safe. |

## Design decisions (issue #64 — ambiguities resolved during this design)

**1 — Deprecated var's shape is uniform across all readers, not just `bot-auth.sh`.**
The issue states the full-file-path requirement explicitly only for `bot-auth.sh`; it's silent
on what `AGENTIC_DEV_CONFIG` means in the three readers that never honored it before. Resolved
by extending the identical meaning everywhere: `CFG="$AGENTIC_DEV_CONFIG"`, never
`"$AGENTIC_DEV_CONFIG/credentials"`. Rationale is in Approach above.

**2 — `bot-auth.sh`'s replacement is written zsh-safe even though it's one of the "standalone
`.sh` files."** `needs-me.sh` and `repo-standard-diff.sh` are always invoked via an explicit
`bash script.sh ...` — confirmed by each file's own header comment ("This file has a bash
shebang, so executing it always runs under bash regardless of the caller's login shell") and by
`harden-repo.md`'s Phase A line (`bash "${CLAUDE_PLUGIN_ROOT}/scripts/repo-standard-diff.sh" ...`)
— so bash is guaranteed for those two regardless of caller shell. `bot-auth.sh` is different: its
own header says "SOURCE this... do not execute it," and every call site (`init/SKILL.md` Step 5,
the write skills' git-collaboration protocol) sources it, never executes it. Sourcing does not
honor the shebang — the file runs in the interpreter of whatever shell sources it, which may be
zsh. `bot-auth.sh`'s own closing comment already anticipates this ("`return` at the top level of
a sourced file is valid in bash and zsh"). Its replacement snippet below is therefore written in
the same POSIX-safe subset as the `harden-repo.md` snippets for a real reason, not just
consistency.

**3 — "one warning line" is per script invocation, not per `/harden-repo --apply` run.**
`harden-repo.md`'s A2 and C snippets deliberately don't share code (AC-4), and each Bash-tool
call is a fresh shell (stated structurally in `bot-auth.sh`'s own header, re-stated in
`harden-repo.md`'s C section). A single `/harden-repo --apply` run with only `AGENTIC_DEV_CONFIG`
set may therefore legitimately print the deprecation line twice total — once from A2, once from
C — each independently satisfying "exactly one warning line" for its own invocation. The issue's
verification matrix is scoped "per touched script," not per end-to-end command run.

**4 — Message prefix per site matches that file's existing stderr-message convention.**
`bot-auth: ...`, `needs-me: ...`, `repo-standard-diff: ...` are each script's own established
prefix (grep-confirmed against each file's existing error strings). Both `harden-repo.md`
snippets use `harden-repo: ...`, matching the prefix the C section's own existing messages
already use (e.g. `"harden-repo: refusing — current gh identity..."`).

**5 — `${VAR:-}` is required for correctness, not just style, in the two `set -u` scripts.**
`needs-me.sh` (line 37) and `repo-standard-diff.sh` (line 35) both run under `set -uo pipefail`.
A bare `$AGENTIC_DEV_CONFIG_DIR` reference — even inside `[ -n "$AGENTIC_DEV_CONFIG_DIR" ]` — on a
variable that was never exported would abort the script with "unbound variable" before the
fallback logic ever runs. `${VAR:-}` sidesteps that unconditionally. `bot-auth.sh` doesn't
declare `set -u` at all (deliberately: it's sourced, and `set -u`/`set -e` inside a sourced file
would leak into the caller's shell) but already uses `${VAR:-}` defensively throughout its
existing code (`${GITHUB_PAT:-}`, `${GITHUB_LOGIN:-}`), so the same form is used here too, for
consistency with the file's own pattern. `harden-repo.md`'s embedded snippets don't declare
`set -u` themselves, but the surrounding shell they're pasted into might — same form used
defensively there as well.

**6 — No prose paragraph added around either `harden-repo.md` snippet.** AC-6 is satisfied by
construction: the only place `AGENTIC_DEV_CONFIG` appears in `harden-repo.md` is the one `elif`
line inside each code block, plus its one-line warning string. No surrounding Markdown prose is
added — the deprecated name stays entirely inside "how the script resolves its own config," never
promoted to a documented option in the command's own prose.

## File manifest

| # | File | Region | AC(s) |
|---|------|--------|-------|
| 1 | `plugin/scripts/bot-auth.sh` | line 18, `local cfg=...` inside `__bot_auth()` | AC-1, AC-2, AC-7 |
| 2 | `plugin/scripts/needs-me.sh` | line 70, `CFG=...` top-level | AC-1, AC-3, AC-7 |
| 3 | `plugin/scripts/repo-standard-diff.sh` | line 85, `CFG=...` top-level | AC-1, AC-3, AC-7 |
| 4 | `plugin/commands/harden-repo.md` | A2 section, line 44, `CFG=...` | AC-4, AC-6, AC-7 |
| 5 | `plugin/commands/harden-repo.md` | C section, line 106, `CFG=...` | AC-4, AC-6, AC-7 |
| 6 | `plugin/skills/init/SKILL.md` | after Step 0's credentials-probe block (after line 26) | AC-5, AC-6 |

Rows 4–5 are the two independent embedded snippets inside the same file (`harden-repo.md`), so
this is 6 edit sites across 5 files, matching the issue's file list exactly.

---

### 1. `plugin/scripts/bot-auth.sh` — `local cfg` inside `__bot_auth()`

**Before** (line 18, verbatim):
```bash
  local cfg="${AGENTIC_DEV_CONFIG:-$HOME/.config/agentic-dev/credentials}"
```

**After** (replaces line 18 only; line 16's blank line and line 17's `__bot_auth() {` above,
and line 19's blank line + lines 20–24's token-resolution block below, are unchanged):
```bash
  local cfg
  if [ -n "${AGENTIC_DEV_CONFIG_DIR:-}" ]; then
    cfg="$AGENTIC_DEV_CONFIG_DIR/credentials"
  elif [ -n "${AGENTIC_DEV_CONFIG:-}" ]; then
    cfg="$AGENTIC_DEV_CONFIG"
    echo "bot-auth: AGENTIC_DEV_CONFIG is deprecated, use AGENTIC_DEV_CONFIG_DIR instead." >&2
  else
    cfg="$HOME/.config/agentic-dev/credentials"
  fi
```
Indentation matches the function's existing 2-space base / 4-space nested-body convention (see
the file's own existing `if [ -z "${GITHUB_PAT:-}" ] && [ -f "$cfg" ]; then` block right below
it). `$cfg` is used unchanged everywhere else in the function (line 22 `[ -f "$cfg" ]`, line 23
`. "$cfg"`, line 28's error message) — no other line in this file changes.

### 2. `plugin/scripts/needs-me.sh` — top-level `CFG=`

**Before** (line 70, verbatim):
```bash
CFG="${AGENTIC_DEV_CONFIG_DIR:-$HOME/.config/agentic-dev}/credentials"
```

**After** (replaces line 70 only; line 69's `# --- identity config: ... ---` comment above and
line 71's `_extract() { ... }` function definition below are unchanged):
```bash
if [ -n "${AGENTIC_DEV_CONFIG_DIR:-}" ]; then
  CFG="$AGENTIC_DEV_CONFIG_DIR/credentials"
elif [ -n "${AGENTIC_DEV_CONFIG:-}" ]; then
  CFG="$AGENTIC_DEV_CONFIG"
  echo "needs-me: AGENTIC_DEV_CONFIG is deprecated, use AGENTIC_DEV_CONFIG_DIR instead." >&2
else
  CFG="$HOME/.config/agentic-dev/credentials"
fi
```
Top-level (0-indent), matching the file's existing top-level statement style. `_extract()`
still reads `$CFG` generically — no change needed there.

### 3. `plugin/scripts/repo-standard-diff.sh` — top-level `CFG=`

**Before** (line 85, verbatim):
```bash
CFG="${AGENTIC_DEV_CONFIG_DIR:-$HOME/.config/agentic-dev}/credentials"
```

**After** (replaces line 85 only; line 84's `# --- identity config: ... ---` comment above and
line 86's `_extract() { ... }` function definition below are unchanged):
```bash
if [ -n "${AGENTIC_DEV_CONFIG_DIR:-}" ]; then
  CFG="$AGENTIC_DEV_CONFIG_DIR/credentials"
elif [ -n "${AGENTIC_DEV_CONFIG:-}" ]; then
  CFG="$AGENTIC_DEV_CONFIG"
  echo "repo-standard-diff: AGENTIC_DEV_CONFIG is deprecated, use AGENTIC_DEV_CONFIG_DIR instead." >&2
else
  CFG="$HOME/.config/agentic-dev/credentials"
fi
```
Identical shape to `needs-me.sh`, own `repo-standard-diff:` prefix. Nothing else in this file
changes — in particular, the `python3` block that consumes `BOT_LOGIN`/`REVIEWERS` further down
is untouched, since it only ever sees the already-resolved values.

### 4. `plugin/commands/harden-repo.md` — A2 section (embedded snippet #1)

**Before** (lines 43–47, verbatim, fenced block included):
````
```bash
CFG="${AGENTIC_DEV_CONFIG_DIR:-$HOME/.config/agentic-dev}/credentials"
REVIEWERS="$(grep -E '^[[:space:]]*AGENTIC_REVIEWERS[[:space:]]*=' "$CFG" | tail -1 | sed -E 's/^[^=]*=[[:space:]]*//; s/^["'"'"']//; s/["'"'"']$//')"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/repo-standard-apply-codeowners.sh" "<owner/repo>" --reviewers "$REVIEWERS" --confirmed
```
````

**After** (only the `CFG=` line is replaced; the `REVIEWERS=` and `bash .../apply-codeowners.sh`
lines are unchanged, byte-for-byte, including the existing `'"'"'`-style sed quoting):
````
```bash
if [ -n "${AGENTIC_DEV_CONFIG_DIR:-}" ]; then
  CFG="$AGENTIC_DEV_CONFIG_DIR/credentials"
elif [ -n "${AGENTIC_DEV_CONFIG:-}" ]; then
  CFG="$AGENTIC_DEV_CONFIG"
  echo "harden-repo: AGENTIC_DEV_CONFIG is deprecated, use AGENTIC_DEV_CONFIG_DIR instead." >&2
else
  CFG="$HOME/.config/agentic-dev/credentials"
fi
REVIEWERS="$(grep -E '^[[:space:]]*AGENTIC_REVIEWERS[[:space:]]*=' "$CFG" | tail -1 | sed -E 's/^[^=]*=[[:space:]]*//; s/^["'"'"']//; s/["'"'"']$//')"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/repo-standard-apply-codeowners.sh" "<owner/repo>" --reviewers "$REVIEWERS" --confirmed
```
````
No prose around this block changes (AC-6, Design decision 6).

### 5. `plugin/commands/harden-repo.md` — C section (embedded snippet #2)

**Before** (lines 106–117, verbatim, fenced block included):
````
```bash
CFG="${AGENTIC_DEV_CONFIG_DIR:-$HOME/.config/agentic-dev}/credentials"
BOT_LOGIN="$(grep -E '^[[:space:]]*GITHUB_LOGIN[[:space:]]*=' "$CFG" 2>/dev/null | tail -1 \
  | sed -E 's/^[^=]*=[[:space:]]*//; s/^["'"'"']//; s/["'"'"']$//')"
CURRENT_LOGIN="$(gh api user --jq .login 2>/dev/null)" \
  || { echo "harden-repo: cannot resolve current gh identity — run 'gh auth login' as yourself." >&2; exit 1; }
if [ -n "$BOT_LOGIN" ] && [ "$CURRENT_LOGIN" = "$BOT_LOGIN" ]; then
  echo "harden-repo: refusing — current gh identity ($CURRENT_LOGIN) IS the configured bot." >&2
  echo "  Branch protection/ruleset must run under YOUR OWN identity, never the bot's." >&2
  exit 1
fi
echo "harden-repo: protection/ruleset will run as '$CURRENT_LOGIN' (ambient, non-bot) ✓"
```
````

**After** (only the `CFG=` line is replaced; every line from `BOT_LOGIN=` through the final
`echo` — including the identity-guardrail `if` block — is unchanged, byte-for-byte):
````
```bash
if [ -n "${AGENTIC_DEV_CONFIG_DIR:-}" ]; then
  CFG="$AGENTIC_DEV_CONFIG_DIR/credentials"
elif [ -n "${AGENTIC_DEV_CONFIG:-}" ]; then
  CFG="$AGENTIC_DEV_CONFIG"
  echo "harden-repo: AGENTIC_DEV_CONFIG is deprecated, use AGENTIC_DEV_CONFIG_DIR instead." >&2
else
  CFG="$HOME/.config/agentic-dev/credentials"
fi
BOT_LOGIN="$(grep -E '^[[:space:]]*GITHUB_LOGIN[[:space:]]*=' "$CFG" 2>/dev/null | tail -1 \
  | sed -E 's/^[^=]*=[[:space:]]*//; s/^["'"'"']//; s/["'"'"']$//')"
CURRENT_LOGIN="$(gh api user --jq .login 2>/dev/null)" \
  || { echo "harden-repo: cannot resolve current gh identity — run 'gh auth login' as yourself." >&2; exit 1; }
if [ -n "$BOT_LOGIN" ] && [ "$CURRENT_LOGIN" = "$BOT_LOGIN" ]; then
  echo "harden-repo: refusing — current gh identity ($CURRENT_LOGIN) IS the configured bot." >&2
  echo "  Branch protection/ruleset must run under YOUR OWN identity, never the bot's." >&2
  exit 1
fi
echo "harden-repo: protection/ruleset will run as '$CURRENT_LOGIN' (ambient, non-bot) ✓"
```
````
This block still never sources `bot-auth.sh` — deliberate and structural (unchanged rationale,
see the file's own surrounding prose at lines 103/119). No prose around this block changes
(AC-6, Design decision 6).

### 6. `plugin/skills/init/SKILL.md` — one added doc line (not a logic change)

**Before** (lines 22–28, verbatim — Step 0's existing-credentials probe, followed by the Step 1
heading):
```
**Already configured?** If credentials exist, offer to *verify* (re-probe — useful after a token expires) instead of overwriting:
```bash
ls -l "${AGENTIC_DEV_CONFIG_DIR:-$HOME/.config/agentic-dev}/credentials" 2>/dev/null \
  && echo "already configured — re-running setup overwrites it"
```

## Step 1 — Gather the details (ask first)
```

**After** (the `ls -l` probe itself — line 24 — is unchanged, canonical-only, matching
`setup-bot.sh`'s write-path resolution; one blockquote line is inserted between the closing
` ``` ` fence and the `## Step 1` heading):
```
**Already configured?** If credentials exist, offer to *verify* (re-probe — useful after a token expires) instead of overwriting:
```bash
ls -l "${AGENTIC_DEV_CONFIG_DIR:-$HOME/.config/agentic-dev}/credentials" 2>/dev/null \
  && echo "already configured — re-running setup overwrites it"
```
> Read paths also accept the deprecated `AGENTIC_DEV_CONFIG` (a full file path) as a fallback — see `bot-auth.sh`, `needs-me.sh`, `repo-standard-diff.sh`, and `harden-repo.md`'s CFG snippets. This probe and `setup-bot.sh`'s write path stay canonical-only (`AGENTIC_DEV_CONFIG_DIR`).

## Step 1 — Gather the details (ask first)
```
This is the entire change to this file: no logic, no script, no other line touched — matching
AC-5's "add one line noting the deprecated fallback exists on the read paths" exactly, and
AC-6's "mentioned only as the fallback, in one line."

## Out of scope — confirmed untouched

Per the issue's explicit scope notes, independently re-checked (not re-derived from the
synthesized DEFINE doc alone) against the live tree on this branch:

- **`plugin/scripts/setup-bot.sh`** — not touched. It already writes the credentials file via
  `AGENTIC_DEV_CONFIG_DIR` only (confirmed: `CONFIG_DIR="${AGENTIC_DEV_CONFIG_DIR:-$HOME/.config/agentic-dev}"`
  at its line 15, `CONFIG_FILE="$CONFIG_DIR/credentials"` at line 16). `AGENTIC_DEV_CONFIG` was
  never directory-shaped anywhere in this codebase — its one pre-existing usage (`bot-auth.sh`)
  always treated it as a full file path — so giving the *write* path a fallback onto it would
  invent a new semantic that never existed, rather than reconcile one that did. `setup-bot.sh` is
  establishing a location, not re-reading one written elsewhere; this is confirmed pre-existing
  behavior, not a regression this design would introduce.
- **`README.md`, `ARCHITECTURE.md`** — not touched. Grep-reconfirmed for this design
  (`grep -n "AGENTIC_DEV_CONFIG" README.md ARCHITECTURE.md` → no matches, see Ground truth above):
  neither file names either env var anywhere, so there is nothing in either to reconcile.
- **Historical SDD docs** (`.claude/sdd/features/DESIGN_ISSUE_{34,36,66}*.md`,
  `.claude/sdd/reports/BUILD_REPORT_ISSUE_34*.md`) — not touched. These are point-in-time records
  of already-shipped issues that happen to quote the pre-issue-64 snippet; rewriting them would
  falsify history a reader relies on to understand what a past PR actually shipped. (This design
  doc, once merged, becomes exactly this kind of historical record for issue #64 — nothing in it
  edits an earlier one.)
- **The credentials file's own format or default location** — not touched. Only the *env-var
  resolution* that locates that file changes; nothing about its contents, or
  `~/.config/agentic-dev` as the ultimate default, changes.

## Zsh-safety

`harden-repo.md`'s two embedded snippets (A2, C) are pasted directly into whatever shell tool
executes them — for this session (and any zsh-backed Bash tool), that's zsh, not bash. Every
replacement snippet in this design — in `harden-repo.md` and in all three affected `.sh` files —
therefore uses only the POSIX-portable subset already this codebase's convention: plain
`if/elif/else/fi` (no `[[ ]]`), `[ -n "${VAR:-}" ]` (never a bare `${VAR}` reference, which would
also break `needs-me.sh`/`repo-standard-diff.sh`'s own `set -u` — see Design decision 5),
double-quoted expansions, no arrays. `needs-me.sh` and `repo-standard-diff.sh` are always invoked
as `bash script.sh ...` (their own header comments say so explicitly), so bash is guaranteed
regardless of caller shell for those two — but their snippets use the same portable subset anyway,
for consistency. `bot-auth.sh` is the one `.sh` file where zsh-safety is load-bearing, not just
consistent: it is *sourced*, never executed (Design decision 2), so it runs in the sourcing
shell's own interpreter.

## Verification

Issue's matrix, applied per edit site, in a throwaway `HOME`/tmp dir with a dummy credentials
file — never the real `~/.config/agentic-dev`:

| Case | Canonical set? | Deprecated set? | Expected resolution | Expected stderr |
|------|-----------------|-------------------|----------------------|-------------------|
| (a) | yes | no | via canonical | none |
| (b) | no | yes | via deprecated | exactly 1 warning line |
| (c) | yes | yes | via canonical (wins) | none |
| (d) | no | no | existing default | none |

Applies independently to all 6 edit sites: `bot-auth.sh` verified by `source`-ing it (both under
`bash` and under `zsh`, per Design decision 2); `needs-me.sh` and `repo-standard-diff.sh` verified
by executing them; `harden-repo.md`'s A2 and C snippets each verified as their own standalone
shell block (both under `bash` and under `zsh`). `init/SKILL.md` has no logic to verify — doc-only
change, checked by inspection (AC-5, AC-6).

Additional checks, from the issue:
- `bash -n` on `bot-auth.sh`, `needs-me.sh`, `repo-standard-diff.sh` — syntax only. Recommend also
  `zsh -n plugin/scripts/bot-auth.sh`, since `bash -n` alone doesn't prove the sourced file parses
  cleanly under zsh too (Design decision 2).
- The repo's test suite, if it covers the touched scripts — checked during this design: it
  doesn't. The only `*.test.sh` in the repo is `.github/scripts/check-closing-keyword.test.sh`,
  unrelated to any of the 5 in-scope files. This clause is currently a no-op, not a gap introduced
  by this design.
- `claude plugin validate plugin/` at 0 errors — CLI confirmed present this session
  (`claude` 2.1.207).

---

**Status: ready for Build.** 6 edit sites across 5 files (`bot-auth.sh` ×1, `needs-me.sh` ×1,
`repo-standard-diff.sh` ×1, `harden-repo.md` ×2, `init/SKILL.md` ×1 doc line). 0 files created or
deleted. 0 git/gh operations performed by this design phase.
