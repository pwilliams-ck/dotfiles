#!/usr/bin/env bash
# Pipe-test suite for ~/.claude/hooks/scripts/pr-size-gate.sh
# Builds a repo on a feature branch with a controllable net-line diff, then
# checks that oversized `gh pr create` is denied and everything else defers.
set -u
HOOK="$HOME/.claude/hooks/scripts/pr-size-gate.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

R="$T/repo"
git init -q -b main "$R"
gc() { git -C "$R" -c user.email=t@t -c user.name=t "$@"; }
gc commit -q --allow-empty -m init
gc switch -q -c feat/x

# add_lines <path> <n> — write n lines to path and commit
add_lines() {
  local p="$R/$1" n="$2" i
  mkdir -p "$(dirname "$p")"
  : > "$p"
  for ((i=0;i<n;i++)); do printf 'line %d\n' "$i" >> "$p"; done
  gc add -A; gc commit -q -m "add $1"
}

pass=0; fail=0
check() { # $1=desc $2=cmd $3=expected (deny|defer)
  out=$(jq -n --arg c "$2" --arg w "$R" '{tool_input:{command:$c},cwd:$w}' | "$HOOK")
  got=$(echo "$out" | jq -r '.hookSpecificOutput.permissionDecision // "defer"' 2>/dev/null)
  [[ -z "$out" ]] && got="defer"
  if [[ "$got" == "$3" ]]; then pass=$((pass+1)); echo "PASS: $1"
  else fail=$((fail+1)); echo "FAIL: $1 — expected $3, got $got"; fi
}

# Small diff (10 code lines): under cap -> defer to static gh ask
add_lines src/small.txt 10
check "small pr create defers"           'gh pr create --fill'                       defer
check "small pr list defers"             'gh pr list'                                defer

# Push over the 500 cap with pure code lines
add_lines src/big.txt 600
check "oversized pr create denied"       'gh pr create --fill'                       deny
check "oversized pr list not denied"     'gh pr list'                                defer
check "oversized non-create gh defers"   'gh pr view 12'                             defer

# Excluded paths must not count toward the cap: add 4000 excluded lines,
# net code lines still 610 -> but excluded, so removing code keeps under? Build
# a fresh oversized-but-excluded scenario on a second branch.
gc switch -q main
gc switch -q -c feat/excluded
add_lines docs/todo/task01.md 800        # docs/ excluded
add_lines yarn.lock 800                  # lockfile excluded
add_lines src/tiny.txt 20                # only 20 counted
check "excluded paths under cap defers"  'gh pr create --fill'                       defer

# Boundary: 380 net lines is over the old 350 but at/under the 400 cap -> defer
gc switch -q main
gc switch -q -c feat/mid
add_lines src/mid.txt 380
check "380 lines under 400 cap defers"   'gh pr create --fill'                       defer

echo "---"
echo "$pass passed, $fail failed"
exit $((fail > 0))
