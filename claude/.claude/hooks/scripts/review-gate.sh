#!/usr/bin/env bash
# review-gate.sh — PreToolUse(Bash). Blocks `git commit` in opted-in repos
# unless the currently STAGED diff has a matching review approval, forcing a
# fresh-context review (diff-reviewer agent) before every commit.
#
# Opt-in: absolute repo roots, one per line, in ~/.claude/hooks/review-gate-repos
# (machine-local runtime config, untracked — like the kill-switch files).
# Approval: after the reviewer returns PASS, write the staged diff's sha256 to
#   ~/.claude/hooks/state/review-ok-<sha256 of repo root path>
# Restaging changes the hash, so any fix forces a fresh review. The gate only
# ever DENIES; a reviewed commit still falls through to the static
# `git commit` ask, so per-command human approval is preserved.
#
# Known limits (accepted):
#   - `git commit -a/--all` bypasses the reviewed staged snapshot -> denied.
#   - `git commit <pathspec>` also bypasses staging; not detected. Workflow
#     stages via approval-gated `git add`, so this path isn't exercised.
#   - `--amend` with an empty stage (message-only) falls through to the ask.
# Per-script kill switch: touch ~/.claude/hooks/.no-review-gate
source "$HOME/.claude/hooks/scripts/common.sh"

check_disabled
require_jq
read_input

cmd=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
cwd=$(echo "$INPUT" | jq -r '.cwd // ""'); [[ -z "$cwd" ]] && cwd="$(pwd)"
[[ -z "$cmd" ]] && exit 0

# only git commit commands (robust to `git -C x commit`, `git --no-pager commit`)
echo "$cmd" | grep -Eq '\bgit\b([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+commit\b' || exit 0

deny(){ jq -n --arg r "$1" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'; exit 0; }

# honour `git -C <path>`: the repo is where -C points, not the shell cwd
dir="$cwd"
# (no \b here — macOS sed -E lacks it; anchor on the literal "git -C" adjacency)
c_arg=$(echo "$cmd" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+([^[:space:]]+).*/\1/p')
[[ -n "$c_arg" ]] && dir="${c_arg/#\~/$HOME}"

repo=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)
[[ -z "$repo" ]] && exit 0

repos_file="$HOOKS_DIR/review-gate-repos"
[[ -f "$repos_file" ]] || exit 0
grep -Fxq "$repo" "$repos_file" || exit 0

# -a/--all commits unstaged work the reviewed snapshot never saw
echo "$cmd" | grep -Eq '\bcommit\b.*([[:space:]]-[a-zA-Z]*a|[[:space:]]--all\b)' \
  && deny "review-gate: 'git commit -a' bypasses the reviewed staged diff. Stage explicitly with git add, get the staged diff reviewed, then commit."

staged_hash=$(git -C "$dir" diff --staged | shasum -a 256 | awk '{print $1}')
empty_hash=$(printf '' | shasum -a 256 | awk '{print $1}')
[[ "$staged_hash" == "$empty_hash" ]] && exit 0  # nothing staged -> normal ask

repo_key=$(printf '%s' "$repo" | shasum -a 256 | awk '{print $1}')
sentinel="$HOOKS_DIR/state/review-ok-$repo_key"

[[ -f "$sentinel" && "$(<"$sentinel")" == "$staged_hash" ]] && exit 0  # reviewed -> static ask

deny "review-gate: staged diff has no passing fresh-context review. Run: ~/.claude/hooks/scripts/review-staged.sh $repo  (headless claude -p reviewer — give the Bash call a 600000ms timeout). Fix its findings, restage, rerun until PASS; the script writes the approval sentinel itself. Never write $sentinel yourself. Then retry the commit."
