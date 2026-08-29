#!/usr/bin/env bash
# Exercises pre-push in throwaway repos under a fake HOME. Covers both halves
# of the hook: the remote-write denials (trunk, tags, deletions, force) and the
# review gate that replaced the commit-time one.
#
# No network and no pushing: remote-tracking refs are fabricated with
# update-ref, and the hook is fed ref lines on stdin exactly as git would.
set -u
# Claude Code exports CLAUDECODE, and the remote-write half of the hook keys off
# it. Clear it so the review-gate cases below see the human path; the denial
# cases re-export it deliberately.
unset CLAUDECODE
here=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$here/../../../.." && pwd)
lib="$repo_root/claude/.claude/hooks/scripts/review-branch.sh"
S=$(mktemp -d)
trap 'rm -rf "$S"' EXIT

export HOME="$S/home"
mkdir -p "$HOME/.claude/hooks/state" "$S/hooks"
cp "$here/pre-push" "$S/hooks/pre-push"; chmod +x "$S/hooks/pre-push"
hook="$S/hooks/pre-push"

g() { git -c user.name=t -c user.email=t@example -c commit.gpgsign=false "$@"; }
sha() { shasum -a 256 | cut -d' ' -f1; }
zero=0000000000000000000000000000000000000000
pass=0; fail=0
check() { # name expected-exit actual-exit
  if [[ "$2" == "$3" ]]; then echo "ok   $1"; pass=$((pass+1)); else echo "FAIL $1 (want exit $2, got $3)"; fail=$((fail+1)); fi
}

# push <remote-ref> <local-sha> [remote-sha] — feed the hook one ref line.
push() { printf 'refs/heads/x %s %s %s\n' "$2" "$1" "${3:-$zero}" | sh "$hook" origin "$S/up" 2>"$S/err"; }

# expected_hash <worktree> <base> <tip> — through review-branch.sh's own
# branch_diff(), so the test proves the two sides agree instead of
# reimplementing one of them.
expected_hash() {
  REVIEW_BRANCH_LIB_ONLY=1 bash -c '. "$1"; branch_diff "$2" "$3" "$4"' _ "$lib" "$1" "$2" "$3" | sha
}
approve() { local h; h=$(expected_hash "$1" "$2" "$3"); printf '%s\n' "$h" > "$HOME/.claude/hooks/state/review-ok-branch-$h"; }

# ---- repo with a resolvable default branch ----
g init -q -b trunk "$S/repo"; cd "$S/repo"
root=$(pwd -P)
echo base > a.txt; g add a.txt; g commit -qm base
g update-ref refs/remotes/origin/trunk "$(g rev-parse HEAD)"
g symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk
g switch -qc feat
echo change > b.txt; g add b.txt; g commit -qm change
tip=$(g rev-parse HEAD)

echo "$root" > "$HOME/.claude/hooks/review-gate-repos"

push refs/heads/feat "$tip"; check "unreviewed branch diff is denied" 1 $?
grep -q 'pre-push: blocked' "$S/err"; check "deny message names the gate" 0 $?
grep -q 'review-branch.sh' "$S/err"; check "deny message names the remedy" 0 $?

approve "$root" origin/trunk "$tip"
push refs/heads/feat "$tip"; check "matching sentinel lets the push through" 0 $?

# The hash is over rendered diff text, so an unpinned rendering knob would make
# review and push disagree. HOME here is already fake, and the sentinel above
# was written under it — this asserts the pinning holds across that boundary.
h_here=$(expected_hash "$root" origin/trunk "$tip")
h_realhome=$(HOME=$(getconf DARWIN_USER_DIR 2>/dev/null || echo /tmp) expected_hash "$root" origin/trunk "$tip")
[[ "$h_here" == "$h_realhome" ]]; check "diff hash is independent of git config HOME" 0 $?

echo more >> b.txt; g add b.txt; g commit -qm more
tip2=$(g rev-parse HEAD)
push refs/heads/feat "$tip2"; check "a new commit invalidates the approval" 1 $?
approve "$root" origin/trunk "$tip2"
push refs/heads/feat "$tip2"; check "re-review after the new commit passes" 0 $?

push refs/heads/feat "$zero"; check "branch deletion skips the review gate" 0 $?

touch "$HOME/.claude/hooks/.no-review-gate"
echo yet >> b.txt; g add b.txt; g commit -qm yet
push refs/heads/feat "$(g rev-parse HEAD)"; check "kill switch lifts the gate" 0 $?
rm "$HOME/.claude/hooks/.no-review-gate"

touch "$HOME/.claude/hooks/.disabled"
push refs/heads/feat "$(g rev-parse HEAD)"; check ".disabled lifts the gate" 0 $?
rm "$HOME/.claude/hooks/.disabled"

# ---- the property the commit-time gate could not hold ----
# review-staged.sh keyed the sentinel by worktree while pre-commit looked it up
# by main checkout, so an approval earned in a linked worktree was never found.
# Content-keying removes the path from the key entirely.
g worktree add -q -b wt "$S/wt" >/dev/null 2>&1; cd "$S/wt"
echo wt > c.txt; g add c.txt; g commit -qm wt
wt_tip=$(g rev-parse HEAD)
push refs/heads/wt "$wt_tip"; check "worktree: unreviewed diff is denied" 1 $?
approve "$S/wt" origin/trunk "$wt_tip"
push refs/heads/wt "$wt_tip"; check "worktree: its own approval is honoured" 0 $?
cd "$S/repo"

# ---- remote-write denials must survive the review gate being added ----
export CLAUDECODE=1
approve "$root" origin/trunk "$tip2"
push refs/heads/master "$tip2"; check "pushing the master literal stays human-only" 1 $?
# This repo's default branch is named trunk, which the literals miss entirely.
push refs/heads/trunk "$tip2"; check "pushing the real default branch stays human-only" 1 $?
push refs/tags/v1 "$tip2"; check "pushing a tag stays human-only" 1 $?
printf 'refs/heads/x %s refs/heads/feat %s\n' "$zero" "$tip2" | sh "$hook" origin "$S/up" 2>/dev/null
check "deleting a branch stays human-only" 1 $?
push refs/heads/feat "$tip" "$tip2"; check "non-fast-forward push stays human-only" 1 $?
unset CLAUDECODE

# ---- no resolvable default branch: fail open ----
g init -q -b odd "$S/nobase"; cd "$S/nobase"
nb=$(pwd -P); echo x > x; g add x; g commit -qm x
echo "$nb" > "$HOME/.claude/hooks/review-gate-repos"
push refs/heads/odd "$(g rev-parse HEAD)"; check "unresolvable base fails open" 0 $?
grep -q 'review gate skipped' "$S/err"; check "skip is announced on stderr" 0 $?

# ---- repo not opted in ----
g init -q -b trunk "$S/other"; cd "$S/other"
echo y > y; g add y; g commit -qm y
push refs/heads/trunk "$(g rev-parse HEAD)"; check "non-opted repo is untouched" 0 $?

echo "--- $pass passed, $fail failed"
exit $fail
