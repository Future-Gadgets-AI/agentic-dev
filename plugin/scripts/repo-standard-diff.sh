#!/usr/bin/env bash
# repo-standard-diff.sh OWNER/REPO [--reviewers "login1 login2 ..."]
#
# Phase A of /harden-repo: read-only diff of OWNER/REPO against
# plugin/contracts/repo-standard.md (branch protection, branch-naming ruleset,
# label scheme, CODEOWNERS, bot-wiring readiness, required-check workflow-file
# probes). This script IS verify mode in its entirety, and ALSO apply mode's
# mandatory first phase (Decision D3) — one engine, reused, never
# re-implemented. That is why it contains ZERO write verbs anywhere below (no
# `create`, `edit`, no `-X`/`--method POST|PUT|PATCH|DELETE`): AT-2's
# "byte-identical no-writes proof" is true by construction, not convention.
#
# Runs as the AMBIENT (human) gh identity. Never sources bot-auth.sh — a read
# needs no bot identity, and it keeps Phase C's later ambient-identity story
# coherent end to end. The one deliberate exception is the bot-wiring
# readiness probe below, which needs to test the BOT's own push access; it
# does so with a one-off `GH_TOKEN=<bot pat> gh api ...` prefix scoped to that
# single command only (never exported, never printed, unset immediately after
# — same technique fine-grained-pat.md's own sanity check uses).
#
# Writes (as data, never as GitHub state):
#   ${TMPDIR:-/tmp}/agentic-dev/repo-standard/<owner>__<repo>/
#     plan.json                  — full machine-readable diff (read by every later phase)
#     protection-put-body.json   — precomputed merge, ready to PUT verbatim if apply confirms
#     ruleset-post-body.json     — present only if ruleset status != "match"
set -uo pipefail

usage() {
  cat <<'EOF'
usage: repo-standard-diff.sh OWNER/REPO [--reviewers "login1 login2 ..."]

Read-only diff of OWNER/REPO against plugin/contracts/repo-standard.md: branch
protection, branch-naming ruleset, label scheme, CODEOWNERS, and bot-wiring
readiness. Writes plan.json + precomputed PUT/POST bodies to a deterministic
tmp dir and renders a human-readable report on stdout.

  OWNER/REPO           Target repo, e.g. Future-Gadgets-AI/gear
  --reviewers "..."    Space-separated GitHub logins for the CODEOWNERS target
                        line. Defaults to AGENTIC_REVIEWERS from the bot
                        credentials file when omitted.

Never writes to GitHub — this is the entire verify mode, and apply mode's
mandatory read-only first phase.
EOF
}

case "${1:-}" in -h|--help) usage; exit 0 ;; esac

REPO="${1:?usage: repo-standard-diff.sh OWNER/REPO [--reviewers \"...\"]}"
shift || true
REVIEWERS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --reviewers) shift; REVIEWERS="${1:?--reviewers needs a value}" ;;
    *) echo "repo-standard-diff: unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift || true
done

case "$REPO" in
  */*) ;;
  *) echo "repo-standard-diff: OWNER/REPO required, got '$REPO'" >&2; exit 1 ;;
esac

command -v python3 >/dev/null 2>&1 || {
  echo "repo-standard-diff: python3 is required (parses plugin/contracts/repo-standard.md's JSON blocks — Decision D2) and is not on PATH." >&2
  exit 1
}

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/.." && pwd)"
CONTRACT="$PLUGIN_ROOT/contracts/repo-standard.md"
[ -f "$CONTRACT" ] || { echo "repo-standard-diff: missing contract file: $CONTRACT" >&2; exit 1; }

# --- identity config: parse only what's needed, never source the credentials file ---
CFG="${AGENTIC_DEV_CONFIG_DIR:-$HOME/.config/agentic-dev}/credentials"
_extract() {  # <KEY> — prints the value, or nothing if the file/key is absent
  local key="$1"
  [ -f "$CFG" ] || return 0
  grep -E "^[[:space:]]*${key}[[:space:]]*=" "$CFG" 2>/dev/null | tail -1 \
    | sed -E 's/^[^=]*=[[:space:]]*//; s/^["'\'']//; s/["'\'']$//'
}
BOT_LOGIN="$(_extract GITHUB_LOGIN)"
[ -n "$REVIEWERS" ] || REVIEWERS="$(_extract AGENTIC_REVIEWERS)"

# --- confirm read access up front; let the native error surface otherwise ---
gh api "repos/$REPO" >/dev/null 2>&1 || {
  echo "repo-standard-diff: cannot read repos/$REPO (missing repo, or no read access with the current gh identity)." >&2
  exit 1
}

# --- bot-wiring readiness probe: one-off, never exported, never printed ---
BOT_PAT="$(_extract GITHUB_PAT)"
if [ -z "$BOT_PAT" ]; then
  BW_READY=false
  BW_REASON="no credentials file"
else
  BW_PUSH="$(GH_TOKEN="$BOT_PAT" gh api "repos/$REPO" --jq '.permissions.push' 2>/dev/null || echo "")"
  if [ "$BW_PUSH" = "true" ]; then
    BW_READY=true
    BW_REASON=""
  else
    BW_READY=false
    BW_REASON="push-probe to $REPO failed (403/no access)"
  fi
fi
unset BOT_PAT

PLAN_DIR="${TMPDIR:-/tmp}/agentic-dev/repo-standard/${REPO/\//__}"
mkdir -p "$PLAN_DIR"

# --- the substantial diff/merge computation: one python3 pass (Patterns 1 & 2) ---
# All `gh api` reads happen FROM HERE DOWN, inside python via subprocess — never
# a shell-out to a write verb; grep this file for `-X`/`--method` and the only
# hits are read-safe (none — GET is the default gh api method).
python3 - "$REPO" "$PLUGIN_ROOT" "$PLAN_DIR" "$BOT_LOGIN" "$REVIEWERS" "$BW_READY" "$BW_REASON" <<'PY'
import base64
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone

repo, plugin_root, plan_dir, bot_login, reviewers, bw_ready, bw_reason = sys.argv[1:8]
bw_ready = bw_ready == "true"


def gh(path):
    """Run `gh api <path>` (GET only). Return (ok, stdout, stderr)."""
    proc = subprocess.run(["gh", "api", path], capture_output=True, text=True)
    return proc.returncode == 0, proc.stdout, proc.stderr


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


def exists(path):  # 200 -> True, 404 -> False, anything else -> hard fail
    ok, out, err = gh(path)
    if ok:
        return True
    if is_missing(err):
        return False
    sys.exit(f"repo-standard-diff: GET {path} failed: {err.strip()}")


def normalize(x):
    return json.dumps(x, sort_keys=True)


def flag(x):  # GET returns {"enabled": bool} where the PUT payload takes a bare bool
    return x.get("enabled") if isinstance(x, dict) and "enabled" in x else x


def slugs(seq, key):  # GET returns object arrays where PUT takes login/slug strings
    return [item[key] for item in seq if isinstance(item, dict) and key in item]


# --- Pattern 1: parse the contract's JSON blocks directly (Decision D2) ---
def block(text, heading):
    m = re.search(re.escape("## " + heading) + r"\n```json\n(.*?)\n```", text, re.DOTALL)
    if not m:
        sys.exit(f"repo-standard-diff: missing or malformed section {heading!r} in repo-standard.md")
    return json.loads(m.group(1))


contract_path = os.path.join(plugin_root, "contracts", "repo-standard.md")
contract = open(contract_path).read()
protection_target = block(contract, "Branch protection — managed fields (target)")
ruleset_target = block(contract, "Branch-naming ruleset — target creation payload")
label_manifest = block(contract, "Label rollout manifest (target — create if missing; never touch existing)")

# --- branch protection: read-merge-write, never a blind PUT (Decision D4/D5, Pattern 2) ---
main_branch_exists = exists(f"repos/{repo}/branches/main")
current_protection = get_or_empty(f"repos/{repo}/branches/main/protection")

def workflow_file_exists(context):
    return exists(f"repos/{repo}/contents/.github/workflows/{context}.yml")


candidate_contexts = protection_target["required_status_checks"]["contexts"]
detected = [c for c in candidate_contexts if workflow_file_exists(c)]

# Drift detection compares GET shapes normalized to PUT shapes (flag()): the API
# returns {"enabled": bool} objects where PUT takes bare booleans — a raw compare
# false-drifts every already-hardened repo and breaks AT-1's second-run no-op.
target_rpr = protection_target["required_pull_request_reviews"]
current_rpr = current_protection.get("required_pull_request_reviews", {})
current_rsc = current_protection.get("required_status_checks")

if detected:
    desired_rsc = {
        "strict": bool((current_rsc or {}).get("strict", False)),
        "contexts": sorted(set((current_rsc or {}).get("contexts") or []) | set(detected)),
    }
elif current_rsc is not None:
    desired_rsc = {
        "strict": bool(current_rsc.get("strict", False)),
        "contexts": sorted(current_rsc.get("contexts") or []),
    }  # untouched — passthrough, normalized
else:
    desired_rsc = None

protection_diff_fields = []
if any(current_rpr.get(k) != v for k, v in target_rpr.items()):
    protection_diff_fields.append("required_pull_request_reviews")
if flag(current_protection.get("enforce_admins")) != protection_target["enforce_admins"]:
    protection_diff_fields.append("enforce_admins")
if flag(current_protection.get("allow_force_pushes")) != protection_target["allow_force_pushes"]:
    protection_diff_fields.append("allow_force_pushes")
if flag(current_protection.get("allow_deletions")) != protection_target["allow_deletions"]:
    protection_diff_fields.append("allow_deletions")
if desired_rsc is not None and (
    current_rsc is None
    or bool(current_rsc.get("strict", False)) != desired_rsc["strict"]
    or sorted(current_rsc.get("contexts") or []) != desired_rsc["contexts"]
):
    protection_diff_fields.append("required_status_checks")

# The PUT body is built in the PUT endpoint's own schema — never the GET shape.
# GET-only fields (required_signatures, url/*_url) are dropped; restrictions and
# dismissal_restrictions map object arrays to login/slug strings; the four
# top-level nullable params are always present, as the endpoint requires.
put_rpr = {k: current_rpr[k] for k in ("require_last_push_approval",) if k in current_rpr}
put_rpr.update(target_rpr)
dismissal = current_rpr.get("dismissal_restrictions")
if isinstance(dismissal, dict) and (dismissal.get("users") or dismissal.get("teams") or dismissal.get("apps")):
    put_rpr["dismissal_restrictions"] = {
        "users": slugs(dismissal.get("users") or [], "login"),
        "teams": slugs(dismissal.get("teams") or [], "slug"),
        "apps": slugs(dismissal.get("apps") or [], "slug"),
    }

current_restrictions = current_protection.get("restrictions")
put_restrictions = None
if isinstance(current_restrictions, dict):
    put_restrictions = {
        "users": slugs(current_restrictions.get("users") or [], "login"),
        "teams": slugs(current_restrictions.get("teams") or [], "slug"),
        "apps": slugs(current_restrictions.get("apps") or [], "slug"),
    }

put_body = {
    "required_status_checks": desired_rsc,
    "enforce_admins": protection_target["enforce_admins"],
    "required_pull_request_reviews": put_rpr,
    "restrictions": put_restrictions,
    "allow_force_pushes": protection_target["allow_force_pushes"],
    "allow_deletions": protection_target["allow_deletions"],
}
for k in ("required_linear_history", "block_creations", "required_conversation_resolution", "lock_branch", "allow_fork_syncing"):
    if k in current_protection:
        put_body[k] = bool(flag(current_protection[k]))  # unmanaged — preserved verbatim

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

# --- branch-naming ruleset: create only if none exists targeting branch creation ---
rulesets_list = get_list_or_empty(f"repos/{repo}/rulesets")
branch_target_summaries = [r for r in rulesets_list if r.get("target") == "branch"]


def ruleset_detail(ruleset_id):
    ok, out, err = gh(f"repos/{repo}/rulesets/{ruleset_id}")
    if not ok:
        sys.exit(f"repo-standard-diff: GET repos/{repo}/rulesets/{ruleset_id} failed: {err.strip()}")
    return json.loads(out)


def ruleset_substantive(d):
    return {k: d.get(k) for k in ("name", "target", "enforcement", "conditions", "rules", "bypass_actors")}


creation_ruleset = None
for summary in branch_target_summaries:
    detail = ruleset_detail(summary["id"])
    if any(r.get("type") == "creation" for r in detail.get("rules", [])):
        creation_ruleset = detail
        break

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

# --- labels: missing-only, exact-match against a generously-paged list ---
labels_proc = subprocess.run(["gh", "api", f"repos/{repo}/labels?per_page=100"], capture_output=True, text=True)
if labels_proc.returncode != 0:
    sys.exit(f"repo-standard-diff: GET repos/{repo}/labels failed: {labels_proc.stderr.strip()}")
labels_list = json.loads(labels_proc.stdout) if labels_proc.stdout.strip() else []
if len(labels_list) >= 100:
    print(f"repo-standard-diff: WARN label list hit the 100-result page cap — some existing labels may be unreported.", file=sys.stderr)
existing_label_names = {label_row["name"] for label_row in labels_list}
target_label_names = [row["name"] for row in label_manifest]
missing_labels = [name for name in target_label_names if name not in existing_label_names]

# --- CODEOWNERS: current vs target, never a PR/branch lookup here (that's the apply script's job) ---
reviewer_logins = reviewers.split()
target_codeowners = ("* " + " ".join(f"@{login}" for login in reviewer_logins)) if reviewer_logins else None

codeowners_raw = get_or_empty(f"repos/{repo}/contents/.github/CODEOWNERS")
if codeowners_raw and "content" in codeowners_raw:
    current_codeowners = base64.b64decode(codeowners_raw["content"]).decode("utf-8").strip()
else:
    current_codeowners = None

def codeowners_rules(text):
    # Effective rules only: comment/blank lines are cosmetic, and owner order
    # within a rule is cosmetic (the contract says so) — a raw byte compare
    # false-drifts every commented-but-correct file into a comment-stripping PR.
    rules = []
    for ln in (text or "").splitlines():
        s = ln.strip()
        if not s or s.startswith("#"):
            continue
        parts = s.split()
        rules.append((parts[0], tuple(sorted(parts[1:]))))
    return rules


if target_codeowners is None:
    codeowners_status = "blocked_no_reviewers"
elif current_codeowners is None:
    codeowners_status = "absent"
elif codeowners_rules(current_codeowners) == codeowners_rules(target_codeowners):
    codeowners_status = "match"
else:
    codeowners_status = "drift"


# --- repo emptiness (Decision D7/D8): commits-endpoint 409, fallback .size == 0 ---
def repo_has_history():
    ok, out, err = gh(f"repos/{repo}/commits?per_page=1")
    if ok:
        return True
    if "409" in err or "Git Repository is empty" in err:
        return False
    repo_info = get_or_empty(f"repos/{repo}")
    if repo_info.get("size") == 0:
        return False
    sys.exit(f"repo-standard-diff: could not determine commit history for {repo}: {err.strip()}")


repo_has_history_flag = repo_has_history()

# --- bot wiring: pure readout of the probe bash already ran (never re-derived here) ---
bot_wiring = {
    "ready": bw_ready,
    "reason": None if bw_ready else bw_reason,
    "fix": None if bw_ready else (
        "1. /agentic-dev:init (guided), or "
        f'2. plugin/scripts/setup-bot.sh --from-env <file> --login <bot> --probe-repo {repo} --reviewers "<...>"'
    ),
}

plan = {
    "repo": repo,
    "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "bot_wiring": bot_wiring,
    "labels": {
        "missing": missing_labels,
        "existing_scheme_count": len(target_label_names) - len(missing_labels),
        "target_count": len(target_label_names),
    },
    "codeowners": {
        "status": codeowners_status,
        "current": current_codeowners,
        "target": target_codeowners,
        "repo_has_history": repo_has_history_flag,
    },
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
    "required_checks_detected": detected,
}

os.makedirs(plan_dir, exist_ok=True)
with open(os.path.join(plan_dir, "plan.json"), "w") as f:
    json.dump(plan, f, indent=2, sort_keys=True)
    f.write("\n")
with open(os.path.join(plan_dir, "protection-put-body.json"), "w") as f:
    json.dump(put_body, f, indent=2, sort_keys=True)
    f.write("\n")
ruleset_body_path = os.path.join(plan_dir, "ruleset-post-body.json")
if ruleset_post_body is not None:
    with open(ruleset_body_path, "w") as f:
        json.dump(ruleset_post_body, f, indent=2, sort_keys=True)
        f.write("\n")
elif os.path.exists(ruleset_body_path):
    os.remove(ruleset_body_path)  # stale body from a prior drifted run — keep re-runs clean

# --- render the human-readable report ---
lines = []
lines.append(f"# Repo hardening — {repo} — PLAN (read-only)\n")

lines.append("## Bot wiring")
if bot_wiring["ready"]:
    lines.append("Status: READY (verified push access)\n")
else:
    lines.append(f"Status: NOT WIRED ({bot_wiring['reason']})")
    lines.append(f"Fix: {bot_wiring['fix']}\n")

lines.append("## Labels")
if not missing_labels:
    lines.append(f"MATCH — all {len(target_label_names)} scheme labels already present.\n")
else:
    lines.append(f"DRIFT — {len(missing_labels)} of {len(target_label_names)} scheme labels missing on {repo}:")
    lines.append("  " + ", ".join(missing_labels) + "\n")

lines.append("## CODEOWNERS")
lines.append(f"Status: {codeowners_status.upper()}")
lines.append(f"  current: {current_codeowners!r}")
lines.append(f"  target:  {target_codeowners!r}")
lines.append(f"  repo_has_history: {repo_has_history_flag}\n")

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

lines.append("## Summary")
lines.append("| Sub-step               | Identity                  | Status |")
lines.append("|-------------------------|---------------------------|--------|")
lines.append(f"| Labels                  | bot                       | {'MATCH' if not missing_labels else 'DRIFT'} |")
codeowners_report_status = {"match": "MATCH", "absent": "ABSENT", "drift": "DRIFT", "blocked_no_reviewers": "BLOCKED (no reviewers configured)"}[codeowners_status]
lines.append(f"| CODEOWNERS              | bot                       | {codeowners_report_status} |")
lines.append(f"| Bot wiring              | —                         | {'READY' if bot_wiring['ready'] else 'NOT WIRED'} |")
lines.append(f"| Protection + ruleset    | ambient (not yet asserted)| {protection_status.upper()} / {ruleset_status.upper()} |")
lines.append("")
lines.append(f"Writes performed: 0 (verify mode — read-only). Plan dir: {plan_dir}")

print("\n".join(lines))
PY
