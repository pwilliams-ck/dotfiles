#!/usr/bin/env bash
# agent-ask-gate.sh — PreToolUse(Agent) gate. Subagent spawns must never fire
# without explicit per-call approval. A hook decision overrides settings
# allow-lists, so this survives an accidental "Agent" re-added to
# settings.local.json by a "don't ask again" click — it always prompts,
# never hard-blocks.
# Per-script kill switch: touch ~/.claude/hooks/.no-agent-ask-gate
source "$HOME/.claude/hooks/scripts/common.sh"

check_disabled
require_jq
read_input

# Matcher already scopes this to Agent, but re-check defensively so a broadened
# matcher can never make this ask on unrelated tools.
tool=$(echo "$INPUT" | jq -r '.tool_name // ""')
[[ "$tool" == "Agent" ]] || exit 0

jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:"Subagent spawns require explicit per-call approval — never auto-allowed."}}'
