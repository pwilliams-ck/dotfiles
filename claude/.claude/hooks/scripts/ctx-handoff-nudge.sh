#!/usr/bin/env bash
# ctx-handoff-nudge.sh — Stop hook. When context USED reaches
# CTX_NUDGE_USED% (default 15) or above, show the user a one-time
# systemMessage suggesting /handoff before restarting the session.
# (The user runs 1M-context models and restarts around 12-15% used.)
#
# Stop-hook input has no context data, so statusline-command.sh writes the
# used % to $CTX_STATE_DIR/ctx-<session_id> on every render; this reads it.
# Nudges once per session (marker file). Kill switch: ~/.claude/hooks/.no-ctx-handoff-nudge
source "$HOME/.claude/hooks/scripts/common.sh"

check_disabled
require_jq
read_input

THRESHOLD="${CTX_NUDGE_USED:-15}"
STATE_DIR="${CTX_STATE_DIR:-$HOOKS_DIR/state}"

session_id=$(echo "$INPUT" | jq -r '.session_id // empty')
[[ -n "$session_id" ]] || exit 0

state_file="$STATE_DIR/ctx-$session_id"
marker="$STATE_DIR/ctx-nudged-$session_id"
[[ -f "$state_file" ]] || exit 0
[[ -f "$marker" ]] && exit 0

used=$(head -1 "$state_file" 2>/dev/null | tr -d '[:space:]')
used=${used%.*}                          # 15.4 -> 15
[[ "$used" =~ ^[0-9]+$ ]] || exit 0      # garbage -> silent

if (( used >= THRESHOLD )); then
  touch "$marker"
  # Opportunistic cleanup of stale session state (>7 days)
  find "$STATE_DIR" -name 'ctx-*' -mtime +7 -delete 2>/dev/null || true
  jq -n --arg m "⚠ Context ${used}% used (nudge at ${THRESHOLD}%) — run /handoff before restarting." \
    '{systemMessage: $m}'
fi
