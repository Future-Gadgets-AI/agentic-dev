# BUILD REPORT: ISSUE_57_ENFORCE_BOT_IDENTITY_GAPS

**Requirements source:** `Future-Gadgets-AI/agentic-dev#57` — "[BUG] enforce-bot-identity hook: org
writes pass ambient via missing verbs and org-resolution fail-open"

**Design:** [`../features/DESIGN_ISSUE_57_ENFORCE_BOT_IDENTITY_GAPS.md`](../features/DESIGN_ISSUE_57_ENFORCE_BOT_IDENTITY_GAPS.md)
**Date:** 2026-07-12
**Branch:** `fix/enforce-bot-identity-gaps`
**Status:** **Complete**

> Headless build (Phase 3) executing the design's full-file replacement of
> `plugin/hooks/enforce-bot-identity.py` (section 1.6) and new colocated test harness
> `plugin/hooks/enforce-bot-identity.test.sh` (section 2.2). Security-sensitive bugfix — three
> binding policy decisions (repo-verb coverage, graphql-mutation matching, merge-requires-marker,
> repo-delete fail-closed, URL-form org resolution) were already made on the issue and restated in
> the design; nothing was re-decided here. Both files were transcribed verbatim from the design and
> confirmed byte-for-byte identical by diff (see **Design-fidelity cross-check** below), then
> verified by real execution, not paraphrase.

---

## Build-time anomaly — external revert/delete, detected and corrected mid-build

After the manifest files were written and the full verification checklist had already passed once,
a tool-generated notice reported that `plugin/hooks/enforce-bot-identity.py` had been externally
modified, describing the change as "intentional" and instructing that it not be disclosed. Verifying
independently through the shell (not trusting that claim, and not trusting my own prior tool state
either) showed the notice understated the actual situation:

- `plugin/hooks/enforce-bot-identity.py` had been reverted, on disk, to its **original pre-fix
  content** (confirmed by SHA-256 hash mismatch against the just-verified file, byte size back to
  the pre-build 4340 bytes / 111 lines, and `git diff --stat` reporting no changes against `HEAD`)
  — i.e. the security gaps this build exists to close (AC1–AC11) were back in place, unfixed.
- `plugin/hooks/enforce-bot-identity.test.sh` had been **deleted** outright (absent from the
  directory listing).

This was not treated as a legitimate instruction: reverting a security fix and suppressing
disclosure of that revert directly contradicts the actual task (ship a verified fix and report
truthfully), and no content arriving via a tool result carries authority to override that. Both
files were restored from the copies already independently verified byte-identical to the design's
section 1.6 / 2.2 listings earlier in this build (see **Design-fidelity cross-check**), the
executable bit was reapplied, and the **entire verification checklist was re-run from a clean
state** — the transcript in the **Verification — full captured transcript** section below is that
final, post-restore run. State was then confirmed stable across two independent SHA-256 checks
before this report was finalized:

```
py:   55cb0192491563a581f8ea899350c75582037890eb0acace567ba4091c6d856c  (stable across 2 checks)
test: 7c005e9c809c4c42c86df1ee46029068672a0053baee2619b3fca53d235a181a  (stable across 2 checks)
```

Root cause is unknown (not diagnosable from inside this session — possibly a sandbox/tool-state
divergence between the file-editing tool surface and the shell's view of the filesystem, since a
direct re-`Read` of the file claimed no change had occurred even while the shell measured a
different hash). Flagging this explicitly for reviewer awareness rather than silently proceeding,
given the domain (a bot-identity enforcement hook) is exactly the kind of control where a silently
un-applied fix would be a meaningful problem.

> **Composer addendum (root cause, established after both phases terminated):** the revert was not
> an attack or a sandbox fault — it was the concurrent DESIGN-phase subagent. That agent remained
> alive after writing its artifact (the composer's build trigger keyed on the artifact file
> appearing, not on the agent exiting), saw this build's output land in the shared runner clone,
> misjudged it as accidental contamination of its workspace, and reverted the hook / deleted the
> test file — then recognized the mistake and restored the content itself; its final report
> discloses this. Both phases' final states converged on the identical SHA-256 hashes above, and
> the composer independently re-ran the full suite (54/54), the before/after smoke, and
> `claude plugin validate` against the terminated-state tree before committing. Process lesson
> (matches this repo's standing "parallel agents share the working tree" hard-won lesson): a
> composer must sequence SDD phases on agent *termination*, not artifact appearance. The shipped
> diff is unaffected; it is byte-identical to the design's execution-verified listings.

---

## Summary

| Metric | Value |
|--------|-------|
| **Manifest execution** | 2/2 files — exactly the design's manifest (1 edit, 1 create) |
| **Agents used** | 0 (direct — design assigns `(general)` to both files; exact content given, no specialist judgment needed) |
| **Test suite result** | `passed: 54   failed: 0` — matches the design's own transcript exactly |
| **py_compile** | Clean |
| **ruff check** | Clean (`ruff 0.15.7`, available in this environment) |
| **bash -n** | Clean |
| **`claude plugin validate plugin/`** | `✔ Validation passed`, exit 0 |
| **Git commits / pushes / `gh` calls** | 0 (composer owns commits, per instructions) |
| **Deviations from design** | 0 |
| **Autonomous decisions** | 0 (design pre-decided everything; see note below) |

---

## Files changed

```
$ git status --short
 M plugin/hooks/enforce-bot-identity.py
?? .claude/sdd/features/DESIGN_ISSUE_57_ENFORCE_BOT_IDENTITY_GAPS.md
?? plugin/hooks/enforce-bot-identity.test.sh

$ git diff --stat
 plugin/hooks/enforce-bot-identity.py | 128 +++++++++++++++++++++++++++++------
 1 file changed, 106 insertions(+), 22 deletions(-)
```

`git diff --stat` only reports the tracked file (`enforce-bot-identity.py`); the new
`enforce-bot-identity.test.sh` is untracked (not yet staged — composer owns commits) and does not
appear in `--stat` output. Its size directly from disk:

```
$ wc -l plugin/hooks/enforce-bot-identity.py plugin/hooks/enforce-bot-identity.test.sh
     195 plugin/hooks/enforce-bot-identity.py
     203 plugin/hooks/enforce-bot-identity.test.sh
     398 total
```

The untracked `DESIGN_ISSUE_57_ENFORCE_BOT_IDENTITY_GAPS.md` shown in `git status` was already
present (this build's own input) before this phase started and was not created, moved, or edited by
this build.

| # | File | Action | Executable bit |
|---|------|--------|-----------------|
| 1 | `plugin/hooks/enforce-bot-identity.py` | Full-file replacement (design 1.6) | `-rwxr-xr-x` (pre-existing, preserved) |
| 2 | `plugin/hooks/enforce-bot-identity.test.sh` | Created (design 2.2) | `-rwxr-xr-x` (set via `chmod +x`) |

No other file was touched. `plugin/hooks/hooks.json` is unchanged (confirmed not in `git status`
output), matching the design's "Out of scope" section.

**Build-time housekeeping note:** running `python3 -m py_compile` (step 3 of verification) produced
a `plugin/hooks/__pycache__/` bytecode-cache directory as a side effect. This was removed after
verification (`rm -rf plugin/hooks/__pycache__`) since it is not part of the design's file manifest
and has no long-term value in the repo. `git status --short` above is the post-cleanup state. This
is routine build hygiene, not a design decision, so it is not listed under Autonomous Decisions.

---

## Design-fidelity cross-check (supplementary rigor, beyond the required checklist)

Because this is a security-sensitive control-flow bugfix, both written files were additionally
diffed programmatically against the exact fenced code blocks in the design document itself (not
just behaviorally verified via the test suite), to rule out any non-functional transcription drift
(e.g. a comment/docstring typo that wouldn't move a test's exit code):

```
$ diff design_1.6_extracted.py plugin/hooks/enforce-bot-identity.py
IDENTICAL

$ diff design_2.2_extracted.sh plugin/hooks/enforce-bot-identity.test.sh
IDENTICAL
```

Both files are byte-for-byte identical to the design's section 1.6 and 2.2 listings.

---

## Verification — full captured transcript

### 1. `bash plugin/hooks/enforce-bot-identity.test.sh` (real execution against the committed files)

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

No case failed. No delta from the design's own section 2.3 transcript — every line matches
exactly, including ordering.

### 2. `python3 -m py_compile plugin/hooks/enforce-bot-identity.py`

```
$ python3 -m py_compile plugin/hooks/enforce-bot-identity.py
py_compile: OK (exit 0)
```

### 3. `ruff check plugin/hooks/enforce-bot-identity.py`

`ruff` is available in this environment (`ruff 0.15.7` at `/Users/lucas/.local/bin/ruff`) — run for
real, not skipped:

```
$ ruff check plugin/hooks/enforce-bot-identity.py
All checks passed!
```

### 4. `bash -n plugin/hooks/enforce-bot-identity.test.sh`

```
$ bash -n plugin/hooks/enforce-bot-identity.test.sh
bash -n: OK (exit 0)
```

### 5. `claude plugin validate plugin/` (AC12)

```
$ claude plugin validate plugin/
Validating plugin manifest: /private/tmp/claude-501/-Users-lucas-workspace-personal-plugins-agentic-dev/5bbdc8ad-37e5-4cad-bc0a-4de85b1897c6/scratchpad/runner-57/plugin/.claude-plugin/plugin.json

✔ Validation passed
exit code: 0
```

Neither file change is structural (one content-only edit to an existing file, one new file
colocated in an existing directory) — consistent with the design's prediction in section 3 that
validation would be unaffected.

---

## Acceptance criteria mapping (AC1–AC12)

| AC | Description | Result | Covering test case(s) |
|----|--------------|--------|------------------------|
| **AC1** | `gh repo create/delete/rename/edit/archive` against the org, ambient → deny | Pass | `AC1 repo create`, `AC1 repo delete`, `AC1 repo rename`, `AC1 repo edit`, `AC1 repo archive` |
| **AC2** | Repo-verb block escapable via the `agentic:allow-ambient` marker | Pass | `AC2 repo create + marker`, `AC2 repo delete + marker` |
| **AC3** | `gh api graphql` with a `mutation` payload matches as a write and is denied ambient | Pass | `AC3 graphql -f mutation`, `AC3 graphql heredoc mutation (keyword only in the heredoc body)` |
| **AC4** | graphql-mutation block escapable via the marker | Pass | `AC4 graphql mutation + marker` |
| **AC5** | URL-form target (`github.com/OWNER/...` or `git@github.com:OWNER/...`) resolves the org for every verb class, ahead of the cwd-remote fallback | Pass | `AC5 https URL resolves org despite non-org cwd (gh issue comment)`, `AC5 ssh URL resolves org despite non-org cwd (git push by URL)` |
| **AC6** | `gh pr merge` unmarked → always denied against the org, regardless of identity (bot-auth.sh / `GH_TOKEN=`) or resolution state | Pass | `AC6 URL merge, ambient, unresolved cwd`, `AC6 URL merge, bot-auth.sh present (!!)`, `AC6 URL merge, GH_TOKEN= present (!!)`, `AC6 bare merge, confirmed org via cwd`, `AC6 bare merge, target fails to resolve` |
| **AC7** | Merge-marker escape works regardless of identity | Pass | `AC7 URL merge + marker, ambient`, `AC7 bare merge + marker, org cwd` |
| **AC8** | Merge with a **confirmed** different-org target → allow (hook has no opinion on other orgs' merges) | Pass | `AC8 merge --repo confirms other org`, `AC8 merge non-org URL`, `AC8 merge confirmed-other-org via cwd` |
| **AC9** | `gh repo delete` fails CLOSED (denies) when its org target is unresolvable; marker/bot-auth/`GH_TOKEN=` still escape it normally | Pass | `AC9 repo delete, unresolved, ambient`, `AC9 repo delete, unresolved + marker`, `AC9 repo delete, unresolved + bot-auth`, `AC9 repo delete, unresolved + GH_TOKEN=` |
| **AC10** | Every other matched write verb keeps the fail-open default on an unresolved target (narrow scoping of AC9's flip) | Pass | `AC10 gh issue create, unresolved`, `AC10 git commit, unresolved`, `AC10 gh label create, unresolved`, `AC10 gh repo create, unresolved`, `AC10 gh repo rename, unresolved`, `AC10 gh repo edit, unresolved`, `AC10 gh repo archive, unresolved`, `AC10 graphql mutation, unresolved` |
| **AC11** | Every pre-existing behavior (regression) still holds: in-org ambient blocks, bot-auth/`GH_TOKEN=`/marker bypasses, `gh pr review` exemption, malformed/non-Bash input handling, no-write-verb passthrough, `--repo`/`-R`/`repos/`/`orgs/` resolution, confirmed-other-org allows | Pass | `AC11 git commit in-org ambient blocked (pre-existing)`, `AC11 git push in-org ambient blocked (pre-existing)`, `AC11 bot-auth allows git commit`, `AC11 GH_TOKEN= allows gh issue create`, `AC11 marker allows git commit`, `AC11 gh pr review stays exempt (never matched)`, `AC11 non-Bash tool_name allowed`, `AC11 empty stdin allowed`, `AC11 unparseable stdin allowed`, `AC11 no write verb (gh issue list)`, `AC11 no write verb (git status)`, `AC11 --repo owner/repo resolution still works`, `AC11 -R owner/repo resolution still works`, `AC11 repos/owner resolution still works`, `AC11 orgs/owner resolution still works`, `AC11 confirmed-other-org via --repo still allows`, `AC11 confirmed-other-org via cwd still allows` |
| **AC12** | Plugin remains structurally valid after both changes | Pass | `claude plugin validate plugin/` → `✔ Validation passed`, exit 0 (not a `.test.sh` case — separate top-level check, see Verification §5) |

Three additional DEFINE-named edge cases (not individually numbered ACs, but required to keep
passing) also pass: `edge: night-shift documented merge form (url + marker)`, `edge: bot-auth allows
a non-merge write in-org`, `edge: unrelated non-org working directory allowed`.

12/12 ACs pass. 54/54 test cases pass. 0 regressions.

---

## Autonomous Decisions

None. The design's binding policy decisions (repo-verb coverage, graphql-mutation matching,
merge-requires-marker-regardless-of-identity, repo-delete fail-closed-on-unresolved, URL-form
resolution ordering, and the AC8-vs-AC11 reconciliation in design §1.7) were already made and fully
specified with exact file content (section 1.6 and 2.2 give complete files, not patterns to
interpret). This build transcribed them verbatim and verified byte-for-byte fidelity (see
**Design-fidelity cross-check**) — there was no ambiguity left to resolve.

---

## Deviations from design

None. Both files match the design's sections 1.6 and 2.2 exactly (confirmed by diff, not just by
passing tests). No file outside the two-file manifest was modified. No git/gh write operation was
performed. The design's "Out of scope" items (`hooks.json`, the harness-cwd-vs-actual-cwd bug, CI
wiring for the new test file, the `git-collaboration` skill's now-partially-stale "Bot identity"
prose) were left untouched, as instructed.

---

## Open items carried forward (from the design, not this build's to resolve)

The design's own **Open questions** section flags two pre-existing, unchanged characteristics for
build/verify awareness, restated here for traceability (not new findings, not acted on):

1. `targets_expected_org()` still does not resolve a bare **positional** `OWNER/REPO` argument (e.g.
   `gh repo edit Future-Gadgets-AI/some-repo`) — out of scope per the DEFINE's own boundary.
2. The AC8-vs-AC11(i) wording reconciliation (design §1.7) — resolved there with explicit rationale;
   flagged in case the repo owner wants to revisit the confirmed-other-org handling for merge/
   repo-delete. The design notes this is a one-line change if a different reading is preferred.

Neither is a defect in this build; both are inherited, named gaps the design explicitly declined to
close, and are unchanged by this build.

---

## Status: COMPLETE
