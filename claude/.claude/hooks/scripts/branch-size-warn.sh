#!/usr/bin/env bash
# branch-size-warn.sh — PostToolUse(Bash). After a `git commit`, report the
# branch's net changed lines vs its base so the size is visible AS IT GROWS
# and a split into vertical slices can be considered early. Advisory only.
# Silent under the warn threshold and on non-commits.
# Per-script kill switch: touch ~/.claude/hooks/.no-branch-size-warn
source "$HOME/.claude/hooks/scripts/common.sh"
source "$HOME/.claude/hooks/scripts/pr-size-lib.sh"

check_disabled
require_jq
read_input

WARN=$PR_SIZE_WARN
SUGGEST=$PR_SIZE_SUGGEST

cmd=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
cwd=$(echo "$INPUT" | jq -r '.cwd // ""'); [[ -z "$cwd" ]] && cwd="$(pwd)"
[[ -z "$cmd" ]] && exit 0

# Only after a git commit (allow VAR=1 / -C / -c opts before the subcommand).
echo "$cmd" | grep -Eq '\bgit\b([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+commit\b' || exit 0

# Resolve repo dir: honor `cd <path> &&` then `git -C <path>`.
gitdir="$cwd"
cd_arg=$(echo "$cmd" | sed -nE 's/^[[:space:]]*cd[[:space:]]+([^;&|]+)(&&|;).*/\1/p' \
         | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//; s/^["'\'']//; s/["'\'']$//')
if [[ -n "$cd_arg" ]]; then
  cd_arg="${cd_arg/#\~/$HOME}"; [[ "$cd_arg" != /* ]] && cd_arg="$cwd/$cd_arg"; gitdir="$cd_arg"
fi
c_arg=$(echo "$cmd" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+([^[:space:]]+).*/\1/p')
if [[ -n "$c_arg" ]]; then
  c_arg="${c_arg/#\~/$HOME}"; [[ "$c_arg" != /* ]] && c_arg="$gitdir/$c_arg"; gitdir="$c_arg"
fi

base=$(resolve_base "$gitdir")
[[ -z "$base" ]] && exit 0
net=$(net_changed_lines "$gitdir" "$base")
[[ "$net" =~ ^[0-9]+$ ]] || exit 0

(( net > WARN )) || exit 0

if (( net > SUGGEST )); then
  msg="Branch is at ~$net net changed lines vs $base — past the suggested ~$SUGGEST (excl. lockfiles/generated/vendored/docs). Consider splitting into vertical slices; size is a suggestion, not a blocker."
else
  msg="Branch is at ~$net net changed lines vs $base (suggested max ~$SUGGEST). Consider planning a split into vertical slices as it grows."
fi
jq -n --arg c "$msg" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}'
exit 0
