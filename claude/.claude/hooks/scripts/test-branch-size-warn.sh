#!/usr/bin/env bash
# Pipe-test suite for ~/.claude/hooks/scripts/branch-size-warn.sh
set -u
HOOK="$HOME/.claude/hooks/scripts/branch-size-warn.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

R="$T/repo"
git init -q -b main "$R"
gc() { git -C "$R" -c user.email=t@t -c user.name=t "$@"; }
gc commit -q --allow-empty -m init
gc switch -q -c feat/x
add_lines() { local p="$R/$1" n="$2" i; mkdir -p "$(dirname "$p")"; : > "$p"
  for ((i=0;i<n;i++)); do printf 'line %d\n' "$i" >> "$p"; done; gc add -A; gc commit -q -m "add $1"; }

pass=0; fail=0
check() { # $1=desc $2=cmd $3=expect (warn|silent)
  out=$(jq -n --arg c "$2" --arg w "$R" '{tool_input:{command:$c},cwd:$w}' | "$HOOK")
  has=$(echo "$out" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)
  got=silent; [[ -n "$has" ]] && got=warn
  if [[ "$got" == "$3" ]]; then pass=$((pass+1)); echo "PASS: $1"
  else fail=$((fail+1)); echo "FAIL: $1 — expected $3, got $got ($has)"; fi
}

msg_of() { jq -n --arg c "$1" --arg w "$R" '{tool_input:{command:$c},cwd:$w}' | "$HOOK" \
           | jq -r '.hookSpecificOutput.additionalContext // ""'; }
grepcheck() { # $1=desc $2=cmd $3=needle $4=want(yes|no)
  m=$(msg_of "$2"); if echo "$m" | grep -q "$3"; then g=yes; else g=no; fi
  if [[ "$g" == "$4" ]]; then pass=$((pass+1)); echo "PASS: $1"
  else fail=$((fail+1)); echo "FAIL: $1 — want $4 for '$3', got $g ($m)"; fi
}

add_lines src/a.txt 100
check "under warn threshold silent"     'git commit -m "x: y"'   silent
check "non-commit silent"               'git status'             silent

add_lines src/b.txt 200                  # net 300: over warn (250), under cap (350)
check "over warn under cap warns"        'git commit -m "x: y"'   warn
grepcheck "under-cap msg omits OVER"     'git commit -m "x: y"'   'OVER the'   no

add_lines docs/task01.md 5000            # excluded -> still net 300, still under-cap
grepcheck "excluded lines stay under cap" 'git commit -m "x: y"'  'OVER the'   no

add_lines src/c.txt 150                   # net 450 -> over the 400 cap
grepcheck "over cap uses cap message"    'git commit -m "x: y"'   'OVER the 400 cap'  yes

echo "---"; echo "$pass passed, $fail failed"; exit $((fail > 0))
