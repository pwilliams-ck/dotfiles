#!/usr/bin/env bash
# pr-size-lib.sh — shared net-changed-line logic for pr-size-gate.sh (hard cap
# at PR create) and branch-size-warn.sh (growing-size warning after commit).
#
# "Net changed lines" = added + deleted on <base>...HEAD, EXCLUDING lockfiles,
# generated code, vendored/build dirs, and docs/ — matching the PR-size budget
# in CLAUDE.md (~500 max). This is a best-effort mirror of that budget's
# exclusions, never a perfect match for a hand-written PR description.

# Budget thresholds — single source of truth for both hooks. Cap mirrors
# CLAUDE.md's ~400-line max. The count is a best-effort, non-exact mirror of
# the PR-description budget, so it's a firm wall, not a precise measure.
PR_SIZE_CAP=500   # gh pr create is denied above this (net changed lines)
PR_SIZE_WARN=350  # post-commit warning fires above this

# ERE of paths excluded from the budget.
PR_SIZE_EXCLUDE_RE='(^|/)(vendor|node_modules|third_party|dist|build|docs)/|(^|/)go\.sum$|(^|/)package-lock\.json$|(^|/)pnpm-lock\.yaml$|\.lock$|\.pb\.go$|_gen\.go$|\.generated\.'

# resolve_base <gitdir> [explicit] — echo the ref to diff against, or "" if none
# can be determined. Prefers an explicit --base, then the remote default branch
# (origin/HEAD), then the usual local/remote main/master names.
resolve_base() {
  local gitdir="$1" explicit="${2:-}"
  if [[ -n "$explicit" ]]; then printf '%s' "$explicit"; return 0; fi
  local d
  d=$(git -C "$gitdir" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null || true)
  if [[ -n "$d" ]]; then printf '%s' "${d#refs/remotes/}"; return 0; fi
  local c
  for c in origin/main origin/master main master; do
    if git -C "$gitdir" rev-parse --verify --quiet "$c" >/dev/null 2>&1; then
      printf '%s' "$c"; return 0
    fi
  done
  return 0
}

# net_changed_lines <gitdir> <base> — echo net added+deleted lines on
# base...HEAD after exclusions. Echoes "" when the diff can't be computed
# (unknown base, not a repo) so callers can fail open.
net_changed_lines() {
  local gitdir="$1" base="$2"
  [[ -z "$base" ]] && return 0
  git -C "$gitdir" rev-parse --verify --quiet "$base" >/dev/null 2>&1 || return 0
  git -C "$gitdir" diff --numstat "$base...HEAD" 2>/dev/null | awk -v re="$PR_SIZE_EXCLUDE_RE" '
    $3 ~ re { next }
    { a = ($1=="-"?0:$1); d = ($2=="-"?0:$2); sum += a + d }
    END { print sum+0 }'
}
