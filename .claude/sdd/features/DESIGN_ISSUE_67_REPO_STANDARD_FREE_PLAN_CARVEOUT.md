# DESIGN — ISSUE_67_REPO_STANDARD_FREE_PLAN_CARVEOUT

> Phase 2 (DESIGN) artifact for issue #67 — a private repo on the org's free GitHub plan 403s on
> branch-protection/rulesets GETs, and today that 403 propagates as an undifferentiated hard
> failure inside `repo-standard-diff.sh`, crashing labels + CODEOWNERS along with it. Headless run.
> The synthesized DEFINE's binding pins (carve-out semantics, shadow-`gh`-shim verification, serial
> dependency on #66/PR #70) are honored as fixed, not re-litigated. `plugin/contracts/repo-standard.md`'s
> canonical Decisions **D1–D10** (recorded in `DESIGN_ISSUE_36_REPO_HARDENING.md`) are referenced,
> not renumbered — this issue mints no "D11"; it adds unnumbered, issue-scoped design notes below,
> exactly as issue #66 did.

## Scope

**In (per the DEFINE, verbatim):**
1. `plugin/contracts/repo-standard.md` gains a new "Free-plan carve-out" section: what still
   applies (labels, CODEOWNERS), what cannot be asserted (protection, rulesets — naming GitHub's
   exact `HTTP 403` / "Upgrade to GitHub Pro or make this repository public" behavior), the
   mandated fallback (process enforcement + a target-repo README note), and the explicit non-goals
   (paying, going public).
2. `repo-standard-diff.sh` classifies that specific 403 shape — on the branch-protection GET
   (`get_or_empty`) and/or the rulesets-list GET (`get_list_or_empty`) — as a new, distinct outcome:
   `plan.json` status `na_plan_limitation`, empty `diff_fields`, never routed into the existing
   `sys.exit` hard-fail path, never conflated with a genuine (404-derived) `absent`.
3. The human-readable report and the Summary table print exactly `N/A (plan limitation)` for this
   case, via a display-mapping dict (mirrors the existing `codeowners_report_status` pattern) —
   never a raw `.upper()` of the new status string.
4. Any other 403 (body not matching the exact phrase) is unaffected — still hard-fails, unchanged.
5. The script's own exit code is `0` when the only findings are plan-limited.
6. `plugin/commands/harden-repo.md` — checked for mis-rendering risk; edited only where the DEFINE
   requires it (see (c) below).

**Out (explicit non-goals, per the DEFINE):**
- Paying for a paid GitHub plan, or making any repo public — neither implemented nor recommended.
- `repo-standard-apply-codeowners.sh` / `repo-standard-apply-labels.sh` — untouched; no plan gating
  touches the Contents/Git Data API writes either script performs.
- The `## repo-standard-*.sh family — CLI convention` section PR #70 added — untouched, only used
  as a placement anchor.
- Any real GitHub write, or enabling protection/rulesets on any real repo — this issue only fixes
  classification + documentation.
- The plugin version bump (`plugin/.claude-plugin/plugin.json`) — the composer's job, after build.
- Redesigning `harden-repo.md`'s **apply-mode** Phase C confirmation/report flow for this status —
  see Inline design decision "Apply-mode Phase C gap — flagged, not fixed" below for why this is a
  conscious deferral, not an oversight.

---

## Architecture — call graph

```
plugin/commands/harden-repo.md
  Phase A: bash .../repo-standard-diff.sh "<owner/repo>" [--reviewers "..."]     (unchanged call)
  Verify-mode Status enum line (×2, "MATCH/DRIFT/ABSENT/BLOCKED")                (THIS issue: (c))
        ▼
plugin/scripts/repo-standard-diff.sh
        │
        ├─ gh api repos/{repo}/labels?per_page=100                    ─┐
        ├─ gh api repos/{repo}/contents/.github/CODEOWNERS              │  NO plan-tier gating
        ├─ gh api repos/{repo}/commits?per_page=1                       │  (Contents/Git Data API,
        ├─ gh api repos/{repo}/branches/main            (exists)        │  per DEFINE) — proceed and
        ├─ gh api repos/{repo}/contents/.github/workflows/*.yml (exists)┘  complete normally, always
        │
        ├─ gh api repos/{repo}/branches/main/protection   (get_or_empty)     ─┐  THIS issue: classify
        └─ gh api repos/{repo}/rulesets                    (get_list_or_empty)┘  a plan-limitation 403
                │                                                                here (only these two)
                ▼
        is_plan_limited(stderr)?  — "HTTP 403" in stderr AND "upgrade to github pro"
                                     in stderr.lower() (case-insensitive substring; NEVER
                                     status-code-alone)
                │
        ┌───────┴────────┐
       yes                no  (incl. every other 403, 401, 5xx, network error, 404-with-
        │                      unrelated-text, etc.)
        ▼                      ▼
  protection/ruleset      existing sys.exit hard-fail path — UNCHANGED, still kills the run
  status =                 (this is the required negative case — see the flow trace below)
  "na_plan_limitation"
  diff_fields = []
  reason = <trimmed body>
        │
        ▼
plugin/contracts/repo-standard.md ── new "Free-plan carve-out" section (a) ── documents what this
   outcome means, the process-enforcement fallback, the README-note mandate, and the non-goals
```

## Architecture — 403 classification flow (the fix, traced in order)

```
get_or_empty("repos/{repo}/branches/main/protection")     ── OR ──     get_list_or_empty("repos/{repo}/rulesets")
        │
        ▼
 [1] gh exit code 0 (HTTP 2xx)?  ───yes──▶  return parsed JSON (dict / list)         [SUCCESS — unchanged]
        │ no
        ▼
 [2] is_missing(stderr)?  ("HTTP 404" in stderr or "Not Found" in stderr)
        │                                        │
       yes ─────────────────────────────────▶  return {} / []                        [404-ABSENT — unchanged;
        │ no                                                                          genuine absence, NOT this
        ▼                                                                              issue's new outcome]
 [3] is_plan_limited(stderr)?
     "HTTP 403" in stderr  AND  "upgrade to github pro" in stderr.lower()
        │                                        │
       yes                                       no  ◀── ANY OTHER 403 (different/absent body text),
        │                                             401, 5xx, network error, malformed response, etc.
        ▼                                        ▼
  raise PlanLimited(stderr)              sys.exit(f"repo-standard-diff: GET {path} failed: ...")
  caught IMMEDIATELY at the                     [HARD FAIL — byte-identical to today; this is the
  one call site that invoked it                  required negative case: a 403 body that does NOT
  (protection GET / rulesets-list GET)            contain the plan-limitation phrase must still kill
        │                                          the whole run, exactly as before this change]
        ▼
  current_protection = {} / rulesets_list = []
  {protection,ruleset}_plan_limited = <trimmed body>   (module-level local, not exported)
        │
        ▼
  status-decision tree: na_plan_limitation is checked FIRST — takes priority over
  main_branch_exists / current_protection == {} / creation_ruleset is None, because a 403 on
  THIS SPECIFIC endpoint is already a definitive, independent signal (see Inline design decision
  "Plan-limited priority ordering" below)
        │
        ▼
  labels + CODEOWNERS sub-steps: entirely separate GET calls (never routed through the two
  call sites above) — unaffected, proceed and report their own MATCH/DRIFT/ABSENT/BLOCKED normally
        │
        ▼
  plan.json written (protection.status/ruleset.status = "na_plan_limitation", diff_fields = [],
  reason = <body>); report rendered ("N/A (plan limitation)" wherever PROTECTION_STATUS.upper() /
  RULESET_STATUS.upper() used to print — 3 occurrences: both per-section headers + the Summary
  table's combined cell); python3 reaches EOF normally — NO sys.exit anywhere on this path
        │
        ▼
  bash script's own exit code = python3's exit code = 0   (last command in the file; nothing
  downstream re-raises or re-checks this — traced completely: no code exists after the `PY`
  heredoc closes)
```

This is exactly the "obviously still true" negative-case proof the task asked for: step [3] is a
**pure addition** between the pre-existing step [2] (`is_missing`) and the pre-existing fallback
(`sys.exit`) — every 403 that fails the new `is_plan_limited` test falls through to the *same*
`sys.exit` line that already existed, completely unedited in wording or position.

---

## Inline design decisions (issue #67 — not part of the D1–D10 canon)

- **Contract section placement**: inserted in the same cross-cutting appendix position issue #66
  used — after `## repo-standard-*.sh family — CLI convention`, before `## Bot wiring — pointer`.
  No clearly better fit surfaced on inspection: the carve-out is cross-cutting (spans the Branch
  protection *and* Branch-naming ruleset sections, plus contrasts with Labels/CODEOWNERS), not an
  edit to any one existing section — the same shape of concern the CLI-convention section has.
- **Detection logic**: `is_plan_limited(err)` requires **both** `"HTTP 403" in err` (status,
  checked case-sensitively — matching `is_missing`'s own precedent for gh's consistently-formatted
  `(HTTP NNN)` annotation) **and** `"upgrade to github pro" in err.lower()` (body text, checked
  case-insensitively, per the task's explicit instruction — GitHub's own casing isn't assumed
  stable). Both conditions AND-ed — never status-code-alone, exactly per the binding pin.
- **Tri-state via a raised exception, not a changed return signature**: `get_or_empty` /
  `get_list_or_empty` are also called from 2 other sites (`repo_has_history()`'s `repo_info`
  fallback; `codeowners_raw`'s Contents-API read) that do **not** need this new outcome — per the
  DEFINE, Contents/Git Data API reads have no plan-tier gating, so those two call sites will never
  realistically hit `is_plan_limited`. Rather than changing both helpers' return shape everywhere
  (forcing every caller to unpack a tuple/status it doesn't care about), a new `PlanLimited`
  exception is raised only at the point of classification and caught **only** at the two call sites
  that need it (branch-protection GET, rulesets-list GET). If it were ever (unexpectedly) raised at
  an uncaught call site, it fails **loud** — an uncaught Python exception, non-zero exit — which is
  no worse than, and arguably clearer than, the `sys.exit` it would have hit before this change.
- **Plan-limited priority ordering**: in both the protection and ruleset status-decision trees, the
  `na_plan_limitation` branch is checked **first**, before `not main_branch_exists`, before
  `current_protection == {}`, before `creation_ruleset is None`. A 403 on the specific
  protection/ruleset endpoint is a definitive, independent signal about *that endpoint* — it does
  not depend on, and should not be overridden by, whatever `main_branch_exists` or an
  (empty-by-necessity) `current_protection`/`rulesets_list` would otherwise imply.
- **`diff_fields = []` and `blocked_on = None` for `na_plan_limitation`, always** — per the binding
  pin ("nothing to diff against when the feature can't be probed"). The pre-existing
  `protection_diff_fields` accumulation loop still runs unconditionally above the decision tree
  (unchanged, to keep the diff minimal) — its result is simply discarded/overridden in this branch,
  exactly as the pre-existing `"match"`/`"drift"`/`"absent"` branches already override each other.
- **`reason` field added to both `plan.json` sub-objects, always present (`None` otherwise)** —
  mirrors the existing `bot_wiring.reason` convention exactly (`"reason": None if bw_ready else
  bw_reason`). Holds the **trimmed** (`.strip()`, same normalization the script's existing
  `sys.exit` messages already apply) 403 body. Named `reason` on both `protection` and `ruleset`
  for symmetry — not `detail` or anything else — precisely because that is the existing sibling
  field's name in this very file.
- **Display-mapping dict, computed once, reused twice** — `status_display = {"match": "MATCH",
  "absent": "ABSENT", "drift": "DRIFT", "na_plan_limitation": "N/A (plan limitation)"}`, indexed
  once each into `protection_status_display` / `ruleset_status_display`, then referenced in *both*
  the per-section header line and the Summary table's combined cell — same technique the file
  already uses for `codeowners_report_status`, applied consistently rather than reinvented.
- **`protection-put-body.json` keeps being written unconditionally, byte-identical to today** —
  this file is *already* written regardless of `protection_status` (even on `"match"`); this issue
  does not change that pre-existing convention, to keep the diff minimal. For `na_plan_limitation`
  it will simply contain the "as if nothing existed" merge — inert, never read for real (see next
  bullet).
- **`ruleset-post-body.json` is *not* written for `na_plan_limitation`** (`ruleset_post_body =
  None`) — this **reuses**, rather than invents, the file's pre-existing conditional-write pattern
  (already `None`-and-not-written for `"match"`; a stale file from an earlier drifted run is already
  removed on a status that no longer needs it). `na_plan_limitation` shares the same "nothing to
  prepare a write body for" semantics as `"match"`, so it reuses the same code path.
- **Apply-mode Phase C gap — flagged, not fixed**: `harden-repo.md`'s apply-mode Phase C ("If
  protection status is already `"match"` and ruleset status is already `"match"` ... nothing to
  confirm") and its Report-block `Status` enum do **not** yet special-case `na_plan_limitation` —
  a real `--apply` run against a plan-limited repo would currently fall through to Phase C's normal
  confirmation flow (rendering a "Planned PUT/POST" prompt from an inert body, and — for ruleset
  specifically — trying to read a `ruleset-post-body.json` that this design deliberately no longer
  writes for this status, which would 404/not-exist on a fresh plan-limited run). This is a **real**
  gap, consciously **not fixed here**: DEFINE's AT-3 explicitly scopes execution to **verify mode**
  ("verify mode, i.e. running `repo-standard-diff.sh`"), and the DEFINE's own out-of-scope list caps
  `harden-repo.md` edits at "strictly necessary to avoid it mis-rendering the new status" for the
  case the ATs actually exercise. Properly closing this gap means deciding new apply-mode UX
  (should Phase C's confirmation-skip treat `na_plan_limitation` like `"match"`? should its own
  Report-block enum gain the same value?) — a legitimate but separate design decision, not something
  to smuggle in un-pinned. Recommended as a natural follow-up, not designed or implemented here.
- **`exists()` and `ruleset_detail()` are untouched** — `exists()` backs `main_branch_exists` and
  the required-check workflow-file probes, neither of which the DEFINE names as an endpoint needing
  this classification (only `branches/main/protection` and `rulesets` do). `ruleset_detail()` is
  only ever called over `branch_target_summaries`, which is empty by construction whenever the
  rulesets-list GET was plan-limited (`rulesets_list = []`) — so it is never reached on this path;
  no defensive change needed there.
- **No CLI/argument-surface change** to `repo-standard-diff.sh` — `usage()`, flag parsing, and
  `--reviewers` behavior are all unaffected; this issue is purely an internal-classification and
  output change, consistent with the DEFINE naming no new flags.
- **Header comment gains one new paragraph** (self-documentation accuracy, matching this file's
  existing habit of documenting its own guarantees inline) — inserted after the existing
  bot-wiring-probe paragraph, before the "Writes (as data...)" paragraph.

---

## (a) `plugin/contracts/repo-standard.md` — new section

**Insert the section below immediately after** the blank line that follows the existing
"CODEOWNERS — format" section's `## repo-standard-*.sh family — CLI convention` content (i.e.,
immediately after its last line — "...offline, syntactic validation only." — and the blank line
after it) **and immediately before** the line `## Bot wiring — pointer (never re-derive credential
logic here)`. This is the exact same appendix position issue #66's own new section used.

**Before** (current lines 186–189):
```markdown
API-based existence verification of the handles themselves is explicitly out of scope — this is
offline, syntactic validation only.

## Bot wiring — pointer (never re-derive credential logic here)
```

**After:**
```markdown
API-based existence verification of the handles themselves is explicitly out of scope — this is
offline, syntactic validation only.

## Free-plan carve-out — private repos cannot assert protection/rulesets

A **private** repository on the org's **free** GitHub plan cannot enable branch protection or
repository rulesets — a GitHub plan-tier limitation, not a bug in this tool or a choice this
contract makes. Discovered hardening the private `second-brain` repo (private by design — it holds
personal client-derived data).

**What still applies** (no plan gating on either — both are bot-driven writes via the Contents/Git
Data API): **labels** (`Label rollout manifest` above) and **CODEOWNERS** (`CODEOWNERS — format`
above). Run these sub-steps normally on a private free-plan repo.

**What cannot be asserted**: **branch protection** and the **branch-naming ruleset** (the `Branch
protection` / `Branch-naming ruleset` sections above). GitHub's exact, observed behavior on both
endpoints for this repo shape: `HTTP 403`, body containing `Upgrade to GitHub Pro or make this
repository public`. `repo-standard-diff.sh` classifies this specific 403 shape as its own outcome
(`na_plan_limitation`) — distinct from genuine absence (an empty/`{}`/`[]` result from a 404, never
a 403) and never routed into the script's hard-fail path. In spirit this is the same restraint as
Decision D4 (never asserted/overwritten beyond the managed fields) and the ruleset-DRIFT row of
`DESIGN_ISSUE_36`'s Error Handling table (never auto-modified): the tool observes and reports what
the platform (or an existing rule) allows, rather than forcing a state.

**Mandated fallback**: **process enforcement** — bot-authored PRs plus human merges (the same
discipline the org's A2A workflow already runs under) stands in for the missing technical
guardrail. **And**: add a note to the *target* repo's own README documenting the residual risk (no
branch protection/ruleset on this repo; merges are enforced by process, not by GitHub) — visible to
anyone working in that repo, not only recorded here.

**Explicitly out of scope** (not this contract's job to do or recommend as a default action):
paying for a paid GitHub plan, and making a data-bearing private repo public. Either remains a
human, case-by-case decision about the target repo, never an automated fallback this tool takes.

## Bot wiring — pointer (never re-derive credential logic here)
```

---

## (b) `plugin/scripts/repo-standard-diff.sh` — classification + reporting changes

Eight precise edits, given as before/after pairs in file order. Line numbers are the current
file's; apply top-to-bottom (each edit's line numbers shift for edits below it once earlier edits
land — locate by the quoted text, not a cached absolute number, if applying out of order).

### (b0) Header comment — new paragraph (insert after line 19, before line 20)

**Before** (current lines 19–20):
```bash
# — same technique fine-grained-pat.md's own sanity check uses).
#
```

**After:**
```bash
# — same technique fine-grained-pat.md's own sanity check uses).
#
# Free-plan carve-out (see plugin/contracts/repo-standard.md, "Free-plan
# carve-out" section): a private repo on the org's free plan 403s on the
# branch-protection and rulesets-list GETs, body naming the upgrade
# requirement. That specific 403 shape is classified as its own outcome —
# protection.status / ruleset.status == "na_plan_limitation" in plan.json,
# reported as "N/A (plan limitation)" — never conflated with a genuine 404
# absence, never routed into this script's hard-fail path. Any OTHER 403
# still hard-fails exactly as before (never classify by status code alone).
#
```

### (b1) `is_missing` / `get_or_empty` / `get_list_or_empty` — replace lines 135–154

**Before:**
```python
def is_missing(err):
    return "HTTP 404" in err or "Not Found" in err


def get_or_empty(path):  # -> dict, {} on 404, hard-fail otherwise
    ok, out, err = gh(path)
    if ok:
        return json.loads(out) if out.strip() else {}
    if is_missing(err):
        return {}
    sys.exit(f"repo-standard-diff: GET {path} failed: {err.strip()}")


def get_list_or_empty(path):  # -> list, [] on 404, hard-fail otherwise
    ok, out, err = gh(path)
    if ok:
        return json.loads(out) if out.strip() else []
    if is_missing(err):
        return []
    sys.exit(f"repo-standard-diff: GET {path} failed: {err.strip()}")
```

**After:**
```python
def is_missing(err):
    return "HTTP 404" in err or "Not Found" in err


def is_plan_limited(err):
    # Free-plan/private-repo carve-out (contract: "Free-plan carve-out"
    # section, repo-standard.md) — GitHub returns HTTP 403 with a body naming
    # the upgrade requirement on branch-protection/rulesets endpoints for a
    # private repo on the org's free plan. Matched on BOTH the 403 status AND
    # this specific body text — NEVER classify a 403 by status code alone;
    # any other 403 (different or absent body text) must still hard-fail via
    # the callers' existing sys.exit path, unchanged.
    return "HTTP 403" in err and "upgrade to github pro" in err.lower()


class PlanLimited(Exception):
    """Raised by get_or_empty/get_list_or_empty when a GET 403s with the
    free-plan carve-out shape (is_plan_limited). Only the two call sites that
    need this distinct outcome (branch protection, rulesets list) catch it;
    every other call site deliberately does not, so an unexpected occurrence
    elsewhere still surfaces loudly (uncaught -> non-zero exit) instead of
    being silently absorbed."""

    def __init__(self, err):
        self.err = err.strip()
        super().__init__(self.err)


def get_or_empty(path):  # -> dict; {} on 404; raises PlanLimited on the carve-out 403; hard-fail otherwise
    ok, out, err = gh(path)
    if ok:
        return json.loads(out) if out.strip() else {}
    if is_missing(err):
        return {}
    if is_plan_limited(err):
        raise PlanLimited(err)
    sys.exit(f"repo-standard-diff: GET {path} failed: {err.strip()}")


def get_list_or_empty(path):  # -> list; [] on 404; raises PlanLimited on the carve-out 403; hard-fail otherwise
    ok, out, err = gh(path)
    if ok:
        return json.loads(out) if out.strip() else []
    if is_missing(err):
        return []
    if is_plan_limited(err):
        raise PlanLimited(err)
    sys.exit(f"repo-standard-diff: GET {path} failed: {err.strip()}")
```

### (b2) Branch-protection GET call site — replace lines 192–194

**Before:**
```python
# --- branch protection: read-merge-write, never a blind PUT (Decision D4/D5, Pattern 2) ---
main_branch_exists = exists(f"repos/{repo}/branches/main")
current_protection = get_or_empty(f"repos/{repo}/branches/main/protection")
```

**After:**
```python
# --- branch protection: read-merge-write, never a blind PUT (Decision D4/D5, Pattern 2) ---
main_branch_exists = exists(f"repos/{repo}/branches/main")
protection_plan_limited = None
try:
    current_protection = get_or_empty(f"repos/{repo}/branches/main/protection")
except PlanLimited as e:
    current_protection = {}
    protection_plan_limited = e.err
```

### (b3) Protection status-decision tree — replace lines 276–289

**Before:**
```python
if not main_branch_exists:
    protection_status = "absent"
    protection_blocked_on = "codeowners"  # A2 creates `main` on a genuinely empty repo (Decision D7)
    protection_diff_fields = ["all"]
elif current_protection == {}:
    protection_status = "absent"
    protection_blocked_on = None
    protection_diff_fields = ["all"]
elif not protection_diff_fields:
    protection_status = "match"
    protection_blocked_on = None
else:
    protection_status = "drift"
    protection_blocked_on = None
```

**After:**
```python
if protection_plan_limited is not None:
    # Takes priority over every branch below: a 403 on THIS endpoint is a
    # definitive plan-tier signal, independent of whether `main` exists or
    # what an (empty-by-necessity) current_protection would otherwise imply.
    protection_status = "na_plan_limitation"
    protection_blocked_on = None
    protection_diff_fields = []
elif not main_branch_exists:
    protection_status = "absent"
    protection_blocked_on = "codeowners"  # A2 creates `main` on a genuinely empty repo (Decision D7)
    protection_diff_fields = ["all"]
elif current_protection == {}:
    protection_status = "absent"
    protection_blocked_on = None
    protection_diff_fields = ["all"]
elif not protection_diff_fields:
    protection_status = "match"
    protection_blocked_on = None
else:
    protection_status = "drift"
    protection_blocked_on = None
```

### (b4) Rulesets-list GET call site — replace lines 291–293

**Before:**
```python
# --- branch-naming ruleset: create only if none exists targeting branch creation ---
rulesets_list = get_list_or_empty(f"repos/{repo}/rulesets")
branch_target_summaries = [r for r in rulesets_list if r.get("target") == "branch"]
```

**After:**
```python
# --- branch-naming ruleset: create only if none exists targeting branch creation ---
ruleset_plan_limited = None
try:
    rulesets_list = get_list_or_empty(f"repos/{repo}/rulesets")
except PlanLimited as e:
    rulesets_list = []
    ruleset_plan_limited = e.err
branch_target_summaries = [r for r in rulesets_list if r.get("target") == "branch"]
```

### (b5) Ruleset status-decision tree — replace lines 314–327

**Before:**
```python
if creation_ruleset is None:
    ruleset_status = "absent"
    ruleset_diff_fields = ["all"]
    ruleset_post_body = dict(ruleset_target)
else:
    target_view = ruleset_substantive(ruleset_target)
    current_view = ruleset_substantive(creation_ruleset)
    if normalize(current_view) == normalize(target_view):
        ruleset_status = "match"
        ruleset_diff_fields = []
    else:
        ruleset_status = "drift"  # never auto-modified — an unreviewed PATCH to an unrelated rule (Error Handling)
        ruleset_diff_fields = [k for k in target_view if current_view.get(k) != target_view.get(k)]
    ruleset_post_body = None
```

**After:**
```python
if ruleset_plan_limited is not None:
    ruleset_status = "na_plan_limitation"
    ruleset_diff_fields = []
    ruleset_post_body = None
elif creation_ruleset is None:
    ruleset_status = "absent"
    ruleset_diff_fields = ["all"]
    ruleset_post_body = dict(ruleset_target)
else:
    target_view = ruleset_substantive(ruleset_target)
    current_view = ruleset_substantive(creation_ruleset)
    if normalize(current_view) == normalize(target_view):
        ruleset_status = "match"
        ruleset_diff_fields = []
    else:
        ruleset_status = "drift"  # never auto-modified — an unreviewed PATCH to an unrelated rule (Error Handling)
        ruleset_diff_fields = [k for k in target_view if current_view.get(k) != target_view.get(k)]
    ruleset_post_body = None
```

### (b6) `plan` dict — replace lines 414–423

**Before:**
```python
    "protection": {
        "status": protection_status,
        "main_branch_exists": main_branch_exists,
        "blocked_on": protection_blocked_on,
        "diff_fields": protection_diff_fields,
    },
    "ruleset": {
        "status": ruleset_status,
        "diff_fields": ruleset_diff_fields,
    },
```

**After:**
```python
    "protection": {
        "status": protection_status,
        "main_branch_exists": main_branch_exists,
        "blocked_on": protection_blocked_on,
        "diff_fields": protection_diff_fields,
        "reason": protection_plan_limited,
    },
    "ruleset": {
        "status": ruleset_status,
        "diff_fields": ruleset_diff_fields,
        "reason": ruleset_plan_limited,
    },
```

### (b7) Report rendering — protection + ruleset sections — replace lines 466–477

**Before:**
```python
lines.append("## Branch protection")
lines.append(f"Status: {protection_status.upper()}" + (f" (blocked on: {protection_blocked_on})" if protection_blocked_on else ""))
lines.append(f"  main_branch_exists: {main_branch_exists}")
if protection_diff_fields:
    lines.append(f"  diff fields: {', '.join(protection_diff_fields)}")
lines.append(f"  required checks detected (workflow file present): {detected or 'none'}\n")

lines.append("## Branch-naming ruleset")
lines.append(f"Status: {ruleset_status.upper()}")
if ruleset_diff_fields:
    lines.append(f"  diff fields: {', '.join(ruleset_diff_fields)}")
lines.append("")
```

**After:**
```python
status_display = {"match": "MATCH", "absent": "ABSENT", "drift": "DRIFT", "na_plan_limitation": "N/A (plan limitation)"}
protection_status_display = status_display[protection_status]
ruleset_status_display = status_display[ruleset_status]

lines.append("## Branch protection")
lines.append(f"Status: {protection_status_display}" + (f" (blocked on: {protection_blocked_on})" if protection_blocked_on else ""))
lines.append(f"  main_branch_exists: {main_branch_exists}")
if protection_diff_fields:
    lines.append(f"  diff fields: {', '.join(protection_diff_fields)}")
if protection_status == "na_plan_limitation":
    lines.append(f"  reason: {protection_plan_limited}")
lines.append(f"  required checks detected (workflow file present): {detected or 'none'}\n")

lines.append("## Branch-naming ruleset")
lines.append(f"Status: {ruleset_status_display}")
if ruleset_diff_fields:
    lines.append(f"  diff fields: {', '.join(ruleset_diff_fields)}")
if ruleset_status == "na_plan_limitation":
    lines.append(f"  reason: {ruleset_plan_limited}")
lines.append("")
```

### (b8) Summary table — replace line 486

**Before:**
```python
lines.append(f"| Protection + ruleset    | ambient (not yet asserted)| {protection_status.upper()} / {ruleset_status.upper()} |")
```

**After:**
```python
lines.append(f"| Protection + ruleset    | ambient (not yet asserted)| {protection_status_display} / {ruleset_status_display} |")
```

(`protection_status_display` / `ruleset_status_display` are already in scope from (b7) — both are
computed earlier in the same top-level Python script, sequential statements, no function boundary
between them.)

---

## (c) `plugin/commands/harden-repo.md` — verify-mode Status enum

**Inspected in full.** Two occurrences of the verify-mode `Status` enum need the new value; every
other status-rendering spot in this file is either apply-mode-only (out of this issue's AT-3 scope
— see the "Apply-mode Phase C gap" design note above) or a pure passthrough that doesn't hardcode
an enum (e.g. the Final report's per-row `Status` cells are rendered as `...` placeholders in the
template, filled in from whatever the sub-step actually reports — no enum to update there).

### (c1) — replace line 31

**Before:**
```markdown
**Verify mode (no `--apply`) stops here.** Render the Final report below with every `Status` limited to `MATCH`/`DRIFT`/`ABSENT`/`BLOCKED`, footer `Writes performed: 0 (verify mode — read-only).` Leave the plan directory in place — nothing outside it was written, and a later `--apply` run (or a fresh Phase A run) can reuse or overwrite it.
```

**After:**
```markdown
**Verify mode (no `--apply`) stops here.** Render the Final report below with every `Status` limited to `MATCH`/`DRIFT`/`ABSENT`/`BLOCKED`/`N/A (plan limitation)` (the last is Protection/ruleset-only — see `plan.json`'s `protection.status`/`ruleset.status` == `na_plan_limitation`), footer `Writes performed: 0 (verify mode — read-only).` Leave the plan directory in place — nothing outside it was written, and a later `--apply` run (or a fresh Phase A run) can reuse or overwrite it.
```

### (c2) — replace line 187

**Before:**
```markdown
Verify mode: every `Status` is `MATCH`/`DRIFT`/`ABSENT`/`BLOCKED`; footer `Writes performed: 0 (verify mode — read-only).`
```

**After:**
```markdown
Verify mode: every `Status` is `MATCH`/`DRIFT`/`ABSENT`/`BLOCKED`/`N/A (plan limitation)` (Protection/ruleset-only); footer `Writes performed: 0 (verify mode — read-only).`
```

**Explicitly checked, no change made:**
- Line 164 (apply-mode Branch protection + ruleset Report-block `Status` enum:
  `APPLIED (confirmed) | NO-OP (already matches) | AWAITING CONFIRMATION | DECLINED | BLOCKED (main
  branch does not exist) | BLOCKED (ambient identity check failed)`) — this is apply-mode, outside
  AT-3's scope (verify mode only); see the "Apply-mode Phase C gap — flagged, not fixed" design
  note. Adding `na_plan_limitation` support here would require redesigning Phase C's
  confirmation-skip logic too, which is a separate decision this issue does not pin.
- Frontmatter (`description`, `argument-hint`), "Parse arguments" section, Labels/CODEOWNERS/Bot
  wiring Report-block templates, and the Final report's table template — all either unrelated to
  protection/ruleset status or render a passthrough placeholder (`...`) rather than a hardcoded
  enum. No change needed.

---

## (d) File manifest

| File | Action | Reason |
|------|--------|--------|
| `plugin/contracts/repo-standard.md` | Modify | New "Free-plan carve-out" section (a): what applies, what cannot, the mandated fallback, the non-goals. |
| `plugin/scripts/repo-standard-diff.sh` | Modify | `is_plan_limited` + `PlanLimited` classification (b1); both call sites wrapped (b2, b4); both status-decision trees gain the `na_plan_limitation` branch (b3, b5); `plan.json` gains `reason` on both sub-objects (b6); report rendering + Summary table print `N/A (plan limitation)` via a display-mapping dict (b7, b8); header comment updated (b0). |
| `plugin/commands/harden-repo.md` | Modify | Both verify-mode `Status` enum occurrences gain `N/A (plan limitation)` (c1, c2). |

**Explicitly NOT in this manifest** (per the DEFINE's hard constraints): `plugin/scripts/repo-standard-apply-codeowners.sh`, `plugin/scripts/repo-standard-apply-labels.sh` (no plan gating touches either), `plugin/.claude-plugin/plugin.json` (composer's version-bump step, after build).

---

## (e) Acceptance-test mapping & verification plan

| AT | DEFINE text (summarized) | How this design satisfies it | Verification |
|----|---------------------------|-------------------------------|---------------|
| **AT-1** | `repo-standard.md` documents the carve-out — what applies, what cannot, the mandated fallback, the non-goals. | New `## Free-plan carve-out` section (a), placed per the pinned appendix position, covering all four required elements verbatim (labels/CODEOWNERS; protection/rulesets + exact `HTTP 403`/"Upgrade to GitHub Pro or make this repository public" wording; process enforcement + target-repo README note; paying/going-public as non-goals). | **Inspection** — read the new section; confirm all four DEFINE-required elements are present. Not executed — a documentation check, per the DEFINE's own framing. |
| **AT-2** | The script distinguishes the 403-plan-limitation shape from real drift/absence on protection **and** ruleset — verifiable via a shadow-`gh` shim against a fake private repo, inspecting `plan.json`. | `is_plan_limited` (b1) classifies the exact shape; `PlanLimited` is raised only at the two relevant call sites (b2, b4); both status trees (b3, b5) emit `"na_plan_limitation"` with `diff_fields: []` and a populated `reason`, never `"absent"` (which stays reserved for a genuine 404/empty result) and never routed into `sys.exit`. | **Execution**, via a shadow-`gh` shim earlier on `PATH` (illustrative shape below) simulating the exact 403 body on `repos/OWNER/REPO/branches/main/protection` and `repos/OWNER/REPO/rulesets`, while `repos/OWNER/REPO`, `.../branches/main`, `.../labels`, `.../contents/.github/CODEOWNERS`, `.../commits`, and `.../contents/.github/workflows/*` all resolve normally (200 or a genuine 404, per fixture). Run `bash plugin/scripts/repo-standard-diff.sh example-org/example-repo --reviewers "alice"`, then inspect the written `plan.json`: expect `.protection.status == "na_plan_limitation"`, `.protection.diff_fields == []`, `.protection.reason` containing the trimmed 403 body; identically for `.ruleset.status` / `.ruleset.diff_fields` / `.ruleset.reason`. |
| **AT-3** | Hardening a private free-plan repo (**verify mode** — running `repo-standard-diff.sh`) completes labels + CODEOWNERS normally, reports the carve-out for protection/ruleset, script exit code `0`. | Labels/CODEOWNERS are computed via entirely separate `gh api` calls (`.../labels`, `.../contents/.github/CODEOWNERS`) never routed through the two `PlanLimited`-aware call sites — unaffected, complete and report their own status normally (traced in the Architecture call graph above). `PlanLimited` is caught locally, never re-raised, never calls `sys.exit` — execution reaches the file's end normally (traced in the flow diagram — no code exists after the `python3` heredoc closes, so the bash script's exit code is exactly `python3`'s). | **Execution**, same shim/fixture as AT-2. After the run, check `$?` — expect `0`. Inspect stdout: `## Labels` and `## CODEOWNERS` sections show ordinary `MATCH`/`DRIFT`/`ABSENT` (proving those sub-steps completed independently); `## Branch protection`, `## Branch-naming ruleset`, and the `## Summary` table's combined cell all show exactly `N/A (plan limitation)` — `grep -c "N/A (plan limitation)"` on stdout should return exactly `3`. |

**Shim shape** (illustrative — for the composer's G2 smoke-gate transcript, per DEFINE pin #3; not
a file this design phase writes):

```bash
#!/usr/bin/env bash
# fake `gh` — placed earlier on PATH than the real one for this exercise only.
# Simplification: omit GITHUB_PAT from the fixture credentials file so the
# bot-wiring probe short-circuits to "no credentials file" without needing a
# `gh api repos/... --jq '.permissions.push'` shim case.
case "$*" in
  "api repos/example-org/example-repo/branches/main/protection"|"api repos/example-org/example-repo/rulesets")
    echo 'gh: Upgrade to GitHub Pro or make this repository public to enable this feature. (HTTP 403)' >&2
    exit 1 ;;
  "api repos/example-org/example-repo")
    echo '{"size": 12}' ;;
  "api repos/example-org/example-repo/branches/main")
    echo '{"name": "main"}' ;;
  "api repos/example-org/example-repo/labels?per_page=100")
    echo '[]' ;;
  "api repos/example-org/example-repo/contents/.github/CODEOWNERS")
    echo 'gh: Not Found (HTTP 404)' >&2; exit 1 ;;
  "api repos/example-org/example-repo/commits?per_page=1")
    echo '[{"sha":"abc123"}]' ;;
  "api repos/example-org/example-repo/contents/.github/workflows/bump-gate.yml"|"api repos/example-org/example-repo/contents/.github/workflows/closing-keyword-gate.yml")
    echo 'gh: Not Found (HTTP 404)' >&2; exit 1 ;;
  *) echo "shim: unhandled gh invocation: $*" >&2; exit 1 ;;
esac
```

The build/composer phase constructs and runs the real equivalent; this snippet exists in this
design artifact only to pin the exact endpoints and response shapes the shim must cover — no
further judgment call about *which* endpoints matter should be needed.

---

## Constraints honored (self-check)

- `repo-standard-apply-codeowners.sh` / `repo-standard-apply-labels.sh` — not touched, not in the
  file manifest. ✓
- No real GitHub write implemented or performed — `repo-standard-diff.sh` remains 100% read-only;
  every edit above is inside the existing read-only engine (Decision D3), zero write verbs added. ✓
- No version bump — `plugin/.claude-plugin/plugin.json` not touched; composer's job. ✓
- No git commit, no git push, no `gh`/GitHub API call made during this design phase — only this
  file was written. ✓
- D1–D10 not renumbered, no "D11" minted — the new contract section is unnumbered/appendix-style,
  cross-referencing D4 and `DESIGN_ISSUE_36`'s ruleset-DRIFT Error Handling row instead. ✓
- File manifest is exactly the three files the task named, no more, no less. ✓
- Every "any OTHER 403 must stay a hard fail" requirement traced explicitly in the 403-classification
  flow diagram: step [3]'s "no" branch falls through to the pre-existing, unedited `sys.exit` line. ✓
- Script's overall exit code traced to `0` for the plan-limited-only case: no new `sys.exit`/`exit`
  introduced on this path; `PlanLimited` is always caught locally; nothing exists downstream of the
  `python3` heredoc in the bash file. ✓
- `plan.json`'s `protection`/`ruleset` objects both gain `status: "na_plan_limitation"` and
  `diff_fields: []` for this case, plus a consistently-named `reason` field, consumed consistently
  by the one renderer that prints them (b7/b8 — no second, stale consumer left un-updated). ✓
- `harden-repo.md` checked in full; changed only where the DEFINE's own AT-3 scope (verify mode)
  requires it; the apply-mode gap is named explicitly, not silently skipped. ✓
