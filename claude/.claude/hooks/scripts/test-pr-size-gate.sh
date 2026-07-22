#!/usr/bin/env bash
# Pipe-test suite for ~/.claude/hooks/scripts/pr-size-gate.sh
# Builds a repo on a feature branch with a controllable net-line diff, then
# checks that oversized `gh pr create` gets a split suggestion (never a deny)
# and everything else stays silent.
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
check() { # $1=desc $2=cmd $3=expected (suggest|silent)
  out=$(jq -n --arg c "$2" --arg w "$R" '{tool_input:{command:$c},cwd:$w}' | "$HOOK")
  deny=$(echo "$out" | jq -r '.hookSpecificOutput.permissionDecision // ""' 2>/dev/null)
  ctx=$(echo "$out" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)
  got=silent
  [[ -n "$ctx" ]] && got=suggest
  [[ -n "$deny" ]] && got=deny
  if [[ "$got" == "$3" ]]; then pass=$((pass+1)); echo "PASS: $1"
  else fail=$((fail+1)); echo "FAIL: $1 — expected $3, got $got"; fi
}

# Small diff (10 code lines): under suggestion -> silent, defer to static gh ask
add_lines src/small.txt 10
check "small pr create silent"           'gh pr create --fill'                       silent
check "small pr list silent"             'gh pr list'                                silent

# Push over the 500 suggestion with pure code lines
add_lines src/big.txt 600
check "oversized pr create suggests"     'gh pr create --fill'                       suggest
check "oversized pr list silent"         'gh pr list'                                silent
check "oversized non-create gh silent"   'gh pr view 12'                             silent

# Excluded paths must not count: docs/lockfiles ignored, only 20 code lines
gc switch -q main
gc switch -q -c feat/excluded
add_lines docs/todo/task01.md 800        # docs/ excluded
add_lines yarn.lock 800                  # lockfile excluded
add_lines src/tiny.txt 20                # only 20 counted
check "excluded paths stay silent"       'gh pr create --fill'                       silent

# Boundary: 380 net lines is under the 500 suggestion -> silent
gc switch -q main
gc switch -q -c feat/mid
add_lines src/mid.txt 380
check "380 lines under 500 silent"       'gh pr create --fill'                       silent

echo "---"
echo "$pass passed, $fail failed"
exit $((fail > 0))
