#!/usr/bin/env bash
# common.sh — Shared functions for all hook scripts
# Source this at the top of every hook script:
#   source "$HOME/.claude/hooks/scripts/common.sh"

set -euo pipefail

HOOKS_DIR="$HOME/.claude/hooks"
LOG_FILE="$HOOKS_DIR/logs/hook-errors.log"
SCRIPT_NAME="$(basename "${BASH_SOURCE[1]:-${0}}" .sh)"

# --- Logging ---

# Rotate log if over 1MB — keeps current as .log, old as .log.1
_rotate_log() {
    if [[ -f "$LOG_FILE" ]]; then
        local size
        size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        if (( size > 1048576 )); then
            mv "$LOG_FILE" "${LOG_FILE}.1" 2>/dev/null || true
        fi
    fi
}

log_error() {
    local msg="$1"
    _rotate_log
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR [$SCRIPT_NAME] $msg" >> "$LOG_FILE" 2>/dev/null || true
}

log_warn() {
    local msg="$1"
    _rotate_log
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN  [$SCRIPT_NAME] $msg" >> "$LOG_FILE" 2>/dev/null || true
}

log_info() {
    local msg="$1"
    _rotate_log
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO  [$SCRIPT_NAME] $msg" >> "$LOG_FILE" 2>/dev/null || true
}

# --- Error trap ---
# Default is fail-open: exit 1 = hooks framework ignores the hook, the tool
# call proceeds. Right for informational hooks (reminders, context injection)
# where a hook bug must not block every Bash call. Logged as WARN.
#
# Permission gates set HOOK_FAIL_MODE=closed BEFORE sourcing this file:
# exit 2 = blocking error, the tool call is DENIED. A crashed gate must not
# silently allow the write it exists to stop. Logged as ERROR.
# (A mode variable, not a function: without set -E, an ERR trap set inside a
# function does not replace the caller's trap.)
# Either way the timeout path still fails open — the harness kills and
# ignores a hook that overruns its timeout; only crashes are caught here.
if [[ "${HOOK_FAIL_MODE:-open}" == "closed" ]]; then
    trap 'log_error "crashed at line $LINENO (fail-closed, tool call blocked)"; exit 2' ERR
else
    trap 'log_warn "crashed at line $LINENO (fail-open, tool call proceeds)"; exit 1' ERR
fi

# --- Flag file checks ---

check_disabled() {
    # Global kill switch
    if [[ -f "$HOOKS_DIR/.disabled" ]]; then exit 0; fi
    # Per-script toggle
    if [[ -f "$HOOKS_DIR/.no-${SCRIPT_NAME}" ]]; then exit 0; fi
}

# --- jq check ---

require_jq() {
    if ! command -v jq &>/dev/null; then
        log_error "jq is not installed"
        exit 1
    fi
}

# --- JSON helpers ---

# Read and validate stdin JSON, store in INPUT global
read_input() {
    INPUT="$(cat)"
    if ! echo "$INPUT" | jq empty 2>/dev/null; then
        log_error "invalid JSON input"
        exit 1
    fi
}

# Output additionalContext JSON to stdout
output_context() {
    local text="$1"
    jq -n --arg ctx "$text" '{additionalContext: $ctx}'
}

