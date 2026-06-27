#!/usr/bin/env bash
# bump.sh — single source of truth for the version-bump rule (ADR-0006, issue #33).
#
#   plugin/scripts/bump.sh --check    # CI gate: is the version correctly bumped vs main? (no writes)
#   plugin/scripts/bump.sh --apply    # executor: set the version to a valid bump vs main (idempotent)
#
# "Shipped" = the plugin/ subtree. Any change under plugin/ requires the version in
# plugin/.claude-plugin/plugin.json to be strictly greater than main's. --apply derives
# the level from the branch prefix and writes ONLY when a bump is actually needed
# (current <= main); if the branch is already ahead of main it is a no-op. Never
# blind-increments — safe for a2a-workflow to call more than once in a run.
set -euo pipefail

readonly PLUGIN_JSON="plugin/.claude-plugin/plugin.json"
readonly BASE_REF="origin/main"
readonly SHIPPED_PREFIX="plugin/"

die() { echo "bump: $*" >&2; exit 1; }

# --- version IO (python3: robust read; minimal-diff regex write) ---
read_version_stdin() { python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])'; }
version_in_tree()    { read_version_stdin < "$PLUGIN_JSON"; }
version_on_base()    { git show "${BASE_REF}:${PLUGIN_JSON}" | read_version_stdin; }
write_version() {  # <new-version> — rewrites only the version value, preserving all else
  python3 - "$PLUGIN_JSON" "$1" <<'PY'
import re,sys
path,newv=sys.argv[1],sys.argv[2]
s=open(path).read()
s2,n=re.subn(r'("version"\s*:\s*")[^"]+(")', r'\g<1>'+newv+r'\g<2>', s, count=1)
if n!=1: sys.exit("bump: could not locate a single version field in "+path)
open(path,"w").write(s2)
PY
}

# --- semver (pure bash, portable) ---
semver_gt() {  # "is A > B ?" -> exit 0 if yes
  local aM aN aP bM bN bP
  IFS=. read -r aM aN aP <<<"$1"
  IFS=. read -r bM bN bP <<<"$2"
  [ "$aM" -gt "$bM" ] && return 0; [ "$aM" -lt "$bM" ] && return 1
  [ "$aN" -gt "$bN" ] && return 0; [ "$aN" -lt "$bN" ] && return 1
  [ "$aP" -gt "$bP" ]
}
bump_version() {  # <base-version> <level>
  local M N P; IFS=. read -r M N P <<<"$1"
  case "$2" in
    major) echo "$((M+1)).0.0" ;;
    minor) echo "${M}.$((N+1)).0" ;;
    patch) echo "${M}.${N}.$((P+1))" ;;
    *) die "unknown level: $2" ;;
  esac
}
require_semver() {  # accept only plain X.Y.Z integers — fail fast on pre-release/build suffixes
  printf '%s' "$1" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' \
    || die "version '$1' is not plain X.Y.Z (pre-release/build suffixes unsupported)"
}

# --- inputs ---
level_from_branch() {  # branch prefix -> bump level; anything unrecognized -> patch.
  # Major is signaled by a `major/*` branch. ADR-0006 also names a `breaking-change` label,
  # but --apply runs at P5.5 (before the PR exists), so a PR label cannot drive it — the
  # branch prefix is the mechanism.
  case "$(git rev-parse --abbrev-ref HEAD)" in
    feat/*|feature/*) echo minor ;;
    major/*)          echo major ;;
    *)                echo patch ;;  # fix/ task/ docs/ chore/ refactor/ ci/ … and the rest
  esac
}
ensure_base() {
  git fetch -q origin "main:refs/remotes/origin/main" 2>/dev/null \
    || git fetch -q origin main 2>/dev/null || true
  git rev-parse --verify -q "${BASE_REF}" >/dev/null \
    || die "cannot resolve ${BASE_REF} (fetch failed?)"
}
plugin_changed() { ! git diff --quiet "${BASE_REF}" -- "${SHIPPED_PREFIX}"; }

main() {
  local mode="${1:-}"
  case "$mode" in --check|--apply) ;; *) die "usage: bump.sh --check | --apply" ;; esac
  [ -f "$PLUGIN_JSON" ] || die "missing $PLUGIN_JSON — run from the repo root"
  ensure_base
  local cur base level target
  case "$mode" in
    --check)
      if ! plugin_changed; then echo "bump: no shipped (plugin/) change vs main — OK"; exit 0; fi
      cur="$(version_in_tree)"; base="$(version_on_base)"; require_semver "$cur"; require_semver "$base"
      if semver_gt "$cur" "$base"; then echo "bump: plugin/ changed; version $cur > main $base — OK"; exit 0; fi
      die "plugin/ changed but version $cur is not > main $base — run: plugin/scripts/bump.sh --apply"
      ;;
    --apply)
      if ! plugin_changed; then echo "bump: no shipped (plugin/) change — nothing to bump"; exit 0; fi
      cur="$(version_in_tree)"; base="$(version_on_base)"; require_semver "$cur"; require_semver "$base"
      if semver_gt "$cur" "$base"; then echo "bump: version $cur already ahead of main $base — no-op"; exit 0; fi
      level="$(level_from_branch)"; target="$(bump_version "$base" "$level")"
      write_version "$target"
      echo "bump: $cur -> $target ($level vs main $base)"
      ;;
  esac
}
main "$@"
