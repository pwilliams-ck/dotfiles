#!/usr/bin/env bash
# Pipe-test suite for ~/.claude/hooks/scripts/bash-write-gate.sh
# Builds two throwaway repos: repoA on main, repoB on feat/x.
set -u
HOOK="$HOME/.claude/hooks/scripts/bash-write-gate.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

mkrepo() { # $1=dir $2=branch
  git init -q -b main "$1"
  git -C "$1" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  [[ "$2" != main ]] && git -C "$1" switch -q -c "$2"
}
mkrepo "$T/repoA" main
mkrepo "$T/repoB" feat/x

pass=0; fail=0
check() { # $1=desc $2=cwd $3=cmd $4=expected decision (deny|ask|allow|defer)
  out=$(jq -n --arg c "$3" --arg w "$2" '{tool_input:{command:$c},cwd:$w}' | "$HOOK")
  got=$(echo "$out" | jq -r '.hookSpecificOutput.permissionDecision // "defer"' 2>/dev/null)
  [[ -z "$out" ]] && got="defer"
  if [[ "$got" == "$4" ]]; then pass=$((pass+1)); echo "PASS: $1"
  else fail=$((fail+1)); echo "FAIL: $1 — expected $4, got $got"; fi
}

# Regressions that must keep working
check "commit on main (plain) denied"            "$T/repoA" 'git commit -m "x: y"'                     deny
check "commit on feature (plain) asks"           "$T/repoB" 'git commit -m "x: y"'                     ask
check "push from main denied"                    "$T/repoA" 'git push'                                 deny
check "push explicit main denied"                "$T/repoB" 'git push origin main'                     deny
check "merge denied"                             "$T/repoB" 'git merge feat/y'                         deny
check "tag create denied"                        "$T/repoB" 'git tag v1.0.0'                           deny
check "force push denied"                        "$T/repoB" 'git push --force'                         deny
check "read-only git allowed"                    "$T/repoB" 'git status'                               allow
check "git -C feature commit asks"               "$T/repoA" "git -C $T/repoB commit -m 'x: y'"         ask
check "git -C main commit denied"                "$T/repoB" "git -C $T/repoA commit -m 'x: y'"         deny

# The misfire class from insights: cd-prefixed compounds resolve against
# the WRONG repo (session cwd instead of the cd target).
check "cd feature && commit asks (no misfire)"   "$T/repoA" "cd $T/repoB && git commit -m 'x: y'"      ask
check "cd main && commit denied (no miss)"       "$T/repoB" "cd $T/repoA && git commit -m 'x: y'"      deny
check "cd feature && push asks (no misfire)"     "$T/repoA" "cd $T/repoB && git push"                  ask
check "cd quoted feature && commit asks"         "$T/repoA" "cd \"$T/repoB\" && git commit -m 'x: y'"  ask

echo "---"
echo "$pass passed, $fail failed"
exit $((fail > 0))
