#!/usr/bin/env bash
# pr-size-gate.sh — PreToolUse(Bash) gate. Denies `gh pr create` when the PR's
# net changed lines exceed the hard cap (PR_SIZE_CAP). There is NO in-band
# override token: exceeding the cap is allowed only under the user's explicit
# direction, via the kill switch below — never self-authorized by the agent.
# Everything under the cap (and every non-create gh command) defers to the
# static `Bash(gh:*)` ask rule.
#
# Fails OPEN: if the base branch can't be determined, the PR is allowed to
# proceed (to the static ask) rather than blocking legitimate work — enforcement
# without a measurable base is impossible, and a false deny is worse here.
# Kill switch (USER-DIRECTED ONLY): touch ~/.claude/hooks/.no-pr-size-gate
source "$HOME/.claude/hooks/scripts/common.sh"
source "$HOME/.claude/hooks/scripts/pr-size-lib.sh"

check_disabled
require_jq
read_input

CAP=$PR_SIZE_CAP

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
[[ -z "$base" ]] && { log_info "pr-size-gate: no base ref, failing open"; exit 0; }

net=$(net_changed_lines "$gitdir" "$base")
[[ -z "$net" ]] && exit 0
[[ "$net" =~ ^[0-9]+$ ]] || exit 0

if (( net > CAP )); then
  jq -n --arg r "PR is ~$net net changed lines vs $base (hard cap $CAP; excl. lockfiles/generated/vendored/docs). Split into a vertical slice. This cap is bypassed only under the user's explicit direction — do not self-authorize an exception." \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
fi

exit 0   # under cap -> defer to the static gh ask
