#!/usr/bin/env bash
# pr-size-gate.sh — PreToolUse(Bash) advisory. When `gh pr create` runs with a
# diff past the suggested size (PR_SIZE_SUGGEST net changed lines), it injects
# a suggestion to split — it never denies. The PR always defers to the static
# `Bash(gh:*)` ask rule.
#
# Fails OPEN (silent): if the base branch can't be determined, no suggestion.
# Kill switch: touch ~/.claude/hooks/.no-pr-size-gate
source "$HOME/.claude/hooks/scripts/common.sh"
source "$HOME/.claude/hooks/scripts/pr-size-lib.sh"

check_disabled
require_jq
read_input

SUGGEST=$PR_SIZE_SUGGEST

cmd=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
cwd=$(echo "$INPUT" | jq -r '.cwd // ""'); [[ -z "$cwd" ]] && cwd="$(pwd)"
[[ -z "$cmd" ]] && exit 0

# Only act on `gh pr create` (allow flags between the words).
echo "$cmd" | grep -Eq '\bgh\b.*\bpr\b.*\bcreate\b' || exit 0

# Resolve the repo dir: honor a leading `cd <path> &&` (gh has no -C).
gitdir="$cwd"
cd_arg=$(echo "$cmd" | sed -nE 's/^[[:space:]]*cd[[:space:]]+([^;&|]+)(&&|;).*/\1/p' \
         | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//; s/^["'\'']//; s/["'\'']$//')
if [[ -n "$cd_arg" ]]; then
  cd_arg="${cd_arg/#\~/$HOME}"
  [[ "$cd_arg" != /* ]] && cd_arg="$cwd/$cd_arg"
  gitdir="$cd_arg"
fi

# Explicit --base / -B wins; else fall back to the remote/local default.
explicit=$(echo "$cmd" | grep -oE -- '(--base[= ]|-B[= ])[^[:space:]]+' | head -1 \
           | sed -E 's/^(--base|-B)[= ]//; s/^["'\'']//; s/["'\'']$//' || true)
base=$(resolve_base "$gitdir" "$explicit")
[[ -z "$base" ]] && { log_info "pr-size-gate: no base ref, staying silent"; exit 0; }

net=$(net_changed_lines "$gitdir" "$base")
[[ -z "$net" ]] && exit 0
[[ "$net" =~ ^[0-9]+$ ]] || exit 0

if (( net > SUGGEST )); then
  jq -n --arg r "PR is ~$net net changed lines vs $base (suggested max ~$SUGGEST; excl. lockfiles/generated/vendored/docs). Consider splitting into vertical slices — size is a suggestion, not a cap; proceeding is fine." \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$r}}'
  exit 0
fi

exit 0   # within suggestion -> defer to the static gh ask
