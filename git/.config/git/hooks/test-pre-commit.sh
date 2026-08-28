#!/usr/bin/env bash
# Exercises scratchpad/pre-commit in a throwaway repo under a fake HOME.
set -u
here=$(cd "$(dirname "$0")" && pwd)
S=$(mktemp -d)
trap 'rm -rf "$S"' EXIT

export HOME="$S/home"
mkdir -p "$HOME/.claude/hooks/state" "$S/hooks"
cp "$here/pre-commit" "$S/hooks/pre-commit"; chmod +x "$S/hooks/pre-commit"

g() { git -c core.hooksPath="$S/hooks" -c user.name=t -c user.email=t@example -c commit.gpgsign=false "$@"; }
sha() { shasum -a 256 | cut -d' ' -f1; }
pass=0; fail=0
check() { # name expected-exit actual-exit
  if [[ "$2" == "$3" ]]; then echo "ok   $1"; pass=$((pass+1)); else echo "FAIL $1 (want exit $2, got $3)"; fail=$((fail+1)); fi
}

g init -q -b test "$S/repo"; cd "$S/repo"
root=$(pwd -P)
echo "$root" > "$HOME/.claude/hooks/review-gate-repos"
key=$(printf '%s' "$root" | sha)
sentinel="$HOME/.claude/hooks/state/review-ok-$key"

echo one > a.txt; g add a.txt
g commit -qm one 2>"$S/err"; check "unreviewed staged diff is denied" 1 $?
grep -q 'pre-commit: blocked' "$S/err"; check "deny message names the gate" 0 $?

g diff --staged | sha > "$sentinel"
g commit -qm one 2>/dev/null; check "matching sentinel lets the commit through" 0 $?

echo two > a.txt; g add a.txt
g diff --staged | sha > "$sentinel"
echo three > a.txt
g commit -qam two 2>/dev/null; check "commit -a with unreviewed edits is denied" 1 $?
g checkout -q -- a.txt 2>/dev/null || true
g commit -qm two 2>/dev/null; check "reviewed index still commits after -a denial" 0 $?

echo four > a.txt; echo b > b.txt; g add a.txt b.txt
g diff --staged | sha > "$sentinel"
g commit -qm four -- a.txt 2>/dev/null; check "pathspec commit (temp index) is denied" 1 $?
g commit -qm four 2>/dev/null; check "full reviewed index commits" 0 $?

echo five > a.txt; g add a.txt
g commit -q --allow-empty -m empty 2>/dev/null; check "sentinel from earlier diff does not carry over" 1 $?
touch "$HOME/.claude/hooks/.no-review-gate"
g commit -qm five 2>/dev/null; check "kill switch lifts the gate" 0 $?
rm "$HOME/.claude/hooks/.no-review-gate"

g commit -q --allow-empty -m nothing-staged 2>/dev/null; check "empty stage passes (message-only)" 0 $?

g worktree add -q -b wt "$S/wt" 2>/dev/null; cd "$S/wt"
echo wt > a.txt; g add a.txt
g commit -qm wt 2>"$S/err"; check "worktree: unreviewed diff is denied" 1 $?
grep -q "review-staged.sh $(pwd -P)" "$S/err"; check "worktree: remedy names the worktree, not main" 0 $?
g diff --staged | sha > "$sentinel"
g commit -qm wt 2>/dev/null; check "worktree: sentinel keyed by main checkout passes" 0 $?

g init -q -b test "$S/other"; cd "$S/other"; echo x > x; g add x
g commit -qm x 2>/dev/null; check "non-opted repo is untouched" 0 $?

echo "--- $pass passed, $fail failed"
exit $fail
