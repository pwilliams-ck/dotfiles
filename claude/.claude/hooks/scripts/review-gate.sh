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

# --show-toplevel returns the worktree root in linked worktrees, not the main
# repo root — so it won't match review-gate-repos entries. --git-common-dir
# always points to the main .git; its parent is the canonical repo root.
common=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null || true)
[[ -z "$common" ]] && exit 0
[[ "$common" != /* ]] && common="$dir/$common"
repo=$(dirname "$(cd "$common" && pwd -P)")

repos_file="$HOOKS_DIR/review-gate-repos"
[[ -f "$repos_file" ]] || exit 0
grep -Fxq "$repo" "$repos_file" || exit 0

# -a/--all commits unstaged work the reviewed snapshot never saw
echo "$cmd" | grep -Eq '\bcommit\b.*([[:space:]]-[a-zA-Z]*a|[[:space:]]--all\b)' \
  && deny "review-gate: 'git commit -a' bypasses the reviewed staged diff. Stage explicitly with git add, get the staged diff reviewed, then commit."

staged_hash=$(git -C "$dir" diff --staged | shasum -a 256 | awk '{print $1}')
empty_hash=$(printf '' | shasum -a 256 | awk '{print $1}')
[[ "$staged_hash" == "$empty_hash" ]] && exit 0  # nothing staged -> normal ask

top=$(git -C "$dir" rev-parse --show-toplevel)
wt_key=$(printf '%s' "$top" | shasum -a 256 | awk '{print $1}')
sentinel="$HOOKS_DIR/state/review-ok-$wt_key"
report="$HOOKS_DIR/state/review-$wt_key.md"
live="/tmp/claude-review-$wt_key.log"

[[ -f "$sentinel" && "$(<"$sentinel")" == "$staged_hash" ]] && exit 0  # reviewed -> static ask

last_report=""
[[ -f "$report" ]] && last_report="

--- last review report ($report) ---
$(<"$report")
--- end report ---"

# Escalation: after 3+ consecutive FAILs on this staged hash, downgrade deny → ask.
# Checked before the fable gate so a fable session with repeated failures can still escalate.
failcount="$HOOKS_DIR/state/review-fails-$wt_key"
review_fails=0
if [[ -f "$failcount" ]]; then
  _fc_hash=$(sed -n '1p' "$failcount" 2>/dev/null)
  _fc_count=$(sed -n '2p' "$failcount" 2>/dev/null)
  [[ "$_fc_hash" == "$staged_hash" ]] && review_fails="${_fc_count:-0}"
fi
if [[ "$review_fails" -ge 3 ]]; then
  jq -n --arg r "review-gate: $review_fails consecutive FAIL reviews on this staged hash — escalating to ask. Approve to commit, or fix remaining findings and restage. Report: $report${last_report}" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'; exit 0
fi

# fable gate: a fable-on-fable review measured $2.52 / 4m21s vs $0.49 / 1m25s
# at opus. Surface the choice rather than silently spending. Skip for small or
# docs-only diffs — those route to sonnet regardless of the author model.
source "$HOME/.claude/hooks/scripts/pr-size-lib.sh" 2>/dev/null || true
_staged_lines=$(staged_net_lines "$dir" 2>/dev/null || echo 999)
is_docs_only "$dir" 2>/dev/null && _docs_only=1 || _docs_only=0
_is_small=$(( _staged_lines <= ${REVIEW_SMALL_THRESHOLD:-50} || _docs_only == 1 ))

if [[ "$_is_small" == 0 && -z "${CLAUDE_REVIEW_ACCEPT_FABLE:-}" ]] && command -v jq >/dev/null 2>&1; then
  _gate_model=""
  [[ -n "${CLAUDE_CODE_SESSION_ID:-}" ]] && {
    _gate_tp=$(find "$HOME/.claude/projects" -name "${CLAUDE_CODE_SESSION_ID}.jsonl" 2>/dev/null | head -1)
    [[ -n "$_gate_tp" ]] && _gate_model=$(jq -r 'select(.type=="assistant") | .message.model // empty' "$_gate_tp" 2>/dev/null | tail -1)
  }
  case "$_gate_model" in
    *fable*) deny "review-gate: fable author detected (model=$_gate_model). Fable-reviewing-fable measured \$2.52 and 4m21s per review vs \$0.49 and 1m25s at opus tier. Either:
  1. Switch this session to a non-fable model, or
  2. Restart the session with CLAUDE_REVIEW_ACCEPT_FABLE=1 exported in your shell, or add it to settings.json env.
This is a cost decision, not a quality one.
Watch progress: tail -f $live" ;;
  esac
fi

deny "review-gate: staged diff has no passing fresh-context review ($((review_fails)) prior FAIL(s)). Run ~/.claude/hooks/scripts/review-staged.sh $top in the FOREGROUND (do NOT background it; set a generous Bash timeout, e.g. 600000ms — the review takes minutes and blocks until done). Then read $report, fix any findings, restage, and rerun until it writes the approval sentinel (PASS). Never write $sentinel yourself. Then retry the commit.
Live progress is logged to $live — tail -f $live from a SEPARATE terminal to watch while the foreground run blocks.${last_report}"
