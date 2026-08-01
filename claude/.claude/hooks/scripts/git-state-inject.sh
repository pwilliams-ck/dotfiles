#!/usr/bin/env bash
# git-state-inject.sh — PreToolUse(Bash). Before any write git command, inject
# the measured repo state (branch, upstream, dirty counts) as context so the
# model acts on measured state instead of remembered state.
# Per-script kill switch: touch ~/.claude/hooks/.no-git-state-inject
source "$HOME/.claude/hooks/scripts/common.sh"

check_disabled
require_jq
read_input

cmd=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
cwd=$(echo "$INPUT" | jq -r '.cwd // ""'); [[ -z "$cwd" ]] && cwd="$(pwd)"
[[ -z "$cmd" ]] && exit 0

# Same write-verb match as bash-write-gate.sh, same stash read-only carve-out.
echo "$cmd" | grep -Eq '\bgit\b([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+(add|commit|push|switch|checkout|restore|pull|reset|cherry-pick|revert|rm|mv|am|apply|submodule|worktree|stash)\b' \
  || exit 0
echo "$cmd" | grep -Eq '\bstash[[:space:]]+(list|show)\b' && exit 0

# Resolve where the git command actually runs (mirrors bash-write-gate.sh):
# a leading `cd <path> &&` and `git -C <path>` both override the session cwd.
gitdir="$cwd"
cd_arg=$(echo "$cmd" | sed -nE 's/^[[:space:]]*cd[[:space:]]+([^;&|]+)(&&|;).*/\1/p' \
         | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//; s/^["'\'']//; s/["'\'']$//')
if [[ -n "$cd_arg" ]]; then
  cd_arg="${cd_arg/#\~/$HOME}"
  [[ "$cd_arg" != /* ]] && cd_arg="$cwd/$cd_arg"
  gitdir="$cd_arg"
fi
c_arg=$(echo "$cmd" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+([^[:space:]]+).*/\1/p')
if [[ -n "$c_arg" ]]; then
  c_arg="${c_arg/#\~/$HOME}"
  [[ "$c_arg" != /* ]] && c_arg="$gitdir/$c_arg"
  gitdir="$c_arg"
fi

status=$(git -C "$gitdir" status --porcelain=v1 --branch 2>/dev/null) || exit 0

header=$(head -n1 <<<"$status")          # "## branch...upstream [ahead N, behind M]"
files=$(tail -n +2 <<<"$status")
staged=$(grep -Ec '^[MADRC]' <<<"$files" || true)
unstaged=$(grep -Ec '^.[MD]' <<<"$files" || true)
untracked=$(grep -c '^??' <<<"$files" || true)

msg="MEASURED git state at $gitdir (just now, not remembered): $header; $staged staged, $unstaged unstaged, $untracked untracked. Act on this, not on assumed branch/tree state."

jq -n --arg ctx "$msg" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$ctx}}'
