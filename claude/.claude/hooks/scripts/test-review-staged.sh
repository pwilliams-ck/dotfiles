#!/usr/bin/env bash
# Tests for review-staged.sh: the pure helpers via REVIEW_STAGED_LIB_ONLY, and
# the target resolution via --dry-run, which stops before claude is invoked.
# A linked worktree is the case that matters: the sentinel keys off the MAIN
# checkout (matching review-gate.sh and claude-gate) while the diff must come
# from the worktree that was passed in.
set -u
SCRIPT="$(cd "$(dirname "$0")" && pwd)/review-staged.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
export HOME="$T/home"; mkdir -p "$HOME/.claude/hooks/state"

pass=0; fail=0
check() { # desc want got
  if [[ "$2" == "$3" ]]; then pass=$((pass+1)); echo "PASS: $1"
  else fail=$((fail+1)); echo "FAIL: $1 — want '$2', got '$3'"; fi
}
sha() { shasum -a 256 | awk '{print $1}'; }

REVIEW_STAGED_LIB_ONLY=1 source "$SCRIPT"

# ---- auto_reviewer: model ladder ----
check "fable author -> fable"             fable  "$(auto_reviewer claude-fable-5)"
check "haiku author -> opus"              opus   "$(auto_reviewer claude-haiku-4-5)"
check "sonnet author -> opus"             opus   "$(auto_reviewer claude-sonnet-5)"
check "opus-4-6 author -> opus"           opus   "$(auto_reviewer claude-opus-4-6)"
check "opus-4-8 author -> opus"           opus   "$(auto_reviewer claude-opus-4-8)"
check "latest opus -> opus"               opus   "$(auto_reviewer claude-opus-5)"
check "unknown author -> empty"           ""     "$(auto_reviewer gpt-x)"

# ---- auto_effort: effort ladder ----
check "effort low -> medium"              medium "$(auto_effort low)"
check "effort medium -> high"             high   "$(auto_effort medium)"
check "effort high -> xhigh"              xhigh  "$(auto_effort high)"
check "effort xhigh stays xhigh"          xhigh  "$(auto_effort xhigh)"
check "effort max -> xhigh cap"           xhigh  "$(auto_effort max)"
check "effort unknown -> empty"           ""     "$(auto_effort bogus)"

# ---- --bump: double step (+2) ----
check "bump low -> high"                  high   "$(auto_effort "$(auto_effort low)")"
check "bump medium -> xhigh"              xhigh  "$(auto_effort "$(auto_effort medium)")"
check "bump high -> xhigh cap"            xhigh  "$(auto_effort "$(auto_effort high)")"
check "bump max -> xhigh cap"             xhigh  "$(auto_effort "$(auto_effort max)")"

M="$T/main"; W="$T/wt"
g() { git -c user.email=t@example -c user.name=t -c commit.gpgsign=false "$@"; }
g init -q -b main "$M"
echo base > "$M/f"; g -C "$M" add f; g -C "$M" commit -qm base
g -C "$M" worktree add -q -b wt "$W"
main_real=$(cd "$M" && pwd -P)

check "main_root of main checkout"        "$main_real" "$(main_root "$M")"
check "main_root of linked worktree"      "$main_real" "$(main_root "$W")"
mkdir -p "$W/sub"
check "main_root of worktree subdir"      "$main_real" "$(main_root "$W/sub")"

echo in-main > "$M/f";  g -C "$M" add f
echo in-wt   > "$W/f";  g -C "$W" add f
wt_hash=$(g -C "$W" diff --staged | sha)
main_hash=$(g -C "$M" diff --staged | sha)
[[ "$wt_hash" != "$main_hash" ]] || { echo "test setup: hashes must differ"; exit 1; }
key=$(printf '%s' "$main_real" | sha)

out=$("$SCRIPT" "$W" --dry-run)
check "dry-run: staged hash is the worktree's"        "$wt_hash"                                        "$(sed -n 's/^staged=//p' <<<"$out")"
check "dry-run: repo is the main checkout"            "$main_real"                                      "$(sed -n 's/^repo=//p' <<<"$out")"
check "dry-run: worktree is the worktree"             "$(cd "$W" && pwd -P)"                            "$(sed -n 's/^worktree=//p' <<<"$out")"
check "dry-run: sentinel keyed by main checkout"      "$HOME/.claude/hooks/state/review-ok-$key"        "$(sed -n 's/^sentinel=//p' <<<"$out")"

out=$("$SCRIPT" "$W/sub" --dry-run)
check "dry-run from a subdir resolves the worktree"   "$wt_hash"                                        "$(sed -n 's/^staged=//p' <<<"$out")"

printf '%s\n' "$wt_hash" > "$HOME/.claude/hooks/state/review-ok-$key"
"$SCRIPT" "$W" --dry-run >/dev/null
check "dry-run leaves an existing approval in place"  "$wt_hash" "$(cat "$HOME/.claude/hooks/state/review-ok-$key" 2>/dev/null)"

echo "---"
echo "$pass passed, $fail failed"
exit $((fail > 0))
