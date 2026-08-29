#!/usr/bin/env bash
# review-staged.sh <checkout-path> — adversarial fresh-context review of a checkout's
# STAGED diff via headless `claude -p`: a separate process that adopts the full
# harness (global + repo CLAUDE.md, hooks, permissions), billed to the CLI's
# logged-in subscription — no API dollars, but it shares the sub's usage limits.
#
# On VERDICT: PASS it writes the sentinel review-gate.sh checks, so the
# authoring session never writes its own approval. The full report is kept at
# ~/.claude/hooks/state/review-<repo-key>.md (one per repo, overwritten).
# Fail-closed: a missing/garbled verdict counts as FAIL.
#
# <checkout-path> is any path inside a checkout. In a linked worktree the diff
# reviewed is the worktree's, while the sentinel is keyed by the MAIN checkout —
# the path review-gate.sh checks and claude-gate writes to review-gate-repos.
# --dry-run prints that resolution and stops before the reviewer runs.
#
# Reviewer model: sonnet by default (correctness-only scope). --model <name>
# or CLAUDE_REVIEW_MODEL overrides for security/deep review at a stronger tier.
#
# Reviewer effort: one level above the author's (low→medium→high→xhigh),
# capped at xhigh — never max. --bump doubles the step (+2 instead of +1).
# Author model and effort are read from the session transcript; when either
# is undetectable the default is stated on stderr.
set -euo pipefail

# ---- pure helpers (unit-tested via REVIEW_STAGED_LIB_ONLY) ----
auto_reviewer() {  # author model -> reviewer model ("" if unknown)
  case "$1" in
    *fable*)                echo fable ;;
    *haiku*|*sonnet*|*opus*) echo opus ;;
    *)                      echo "" ;;
  esac
}
auto_effort() {  # author effort -> one level above, capped at xhigh ("" if unknown)
  case "$1" in
    low)    echo medium ;;
    medium) echo high ;;
    high)   echo xhigh ;;
    xhigh)  echo xhigh ;;
    max)    echo xhigh ;;
    *)      echo "" ;;
  esac
}
# main_root <path> — root of the MAIN checkout for any path inside a checkout,
# linked worktrees included. pwd -P so the key matches claude-gate's entry even
# when the path runs through a symlink (macOS /var -> /private/var).
main_root() {
  local common
  common=$(git -C "$1" rev-parse --git-common-dir) || return 1
  [[ "$common" == /* ]] || common="$1/$common"
  dirname "$(cd "$common" && pwd -P)"
}
# Tests source this file for the helpers above and stop here.
[[ -n "${REVIEW_STAGED_LIB_ONLY:-}" ]] && return 0

repo=""
cli_model=""   # --model <m>: explicit reviewer model (highest precedence)
bump=""        # --bump: double the effort step (+2 instead of +1)
dry_run=""     # --dry-run: print worktree/repo/hash/sentinel and stop
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)   cli_model="${2:?--model needs a value}"; shift 2 ;;
    --model=*) cli_model="${1#--model=}"; shift ;;
    --bump)    bump=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    --)        shift; break ;;
    -*)        echo "review-staged: unknown flag $1" >&2; exit 1 ;;
    *)         [[ -z "$repo" ]] || { echo "review-staged: unexpected arg $1" >&2; exit 1; }
               repo="$1"; shift ;;
  esac
done
[[ -n "$repo" ]] || { echo "usage: review-staged.sh <checkout-path> [--model <model>] [--bump] [--dry-run]" >&2; exit 1; }
worktree=$(git -C "$repo" rev-parse --show-toplevel)
repo=$(main_root "$worktree")
hash=$(git -C "$worktree" diff --staged | shasum -a 256 | awk '{print $1}')
empty=$(printf '' | shasum -a 256 | awk '{print $1}')
[[ "$hash" == "$empty" ]] && { echo "review-staged: nothing staged in $worktree" >&2; exit 1; }

# diff-size routing: small or docs-only staged diffs get a sonnet reviewer
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/pr-size-lib.sh"
staged_lines=$(staged_net_lines "$worktree")
is_docs_only "$worktree" && docs_only=1 || docs_only=0
is_small=$(( staged_lines <= REVIEW_SMALL_THRESHOLD || docs_only == 1 ))

key=$(printf '%s' "$worktree" | shasum -a 256 | awk '{print $1}')
state="$HOME/.claude/hooks/state"; mkdir -p "$state"
report="$state/review-$key.md"
sentinel="$state/review-ok-$key"
live="/tmp/claude-review-$key.log"
if [[ -n "$dry_run" ]]; then
  printf 'worktree=%s\nrepo=%s\nstaged=%s\nsentinel=%s\n' "$worktree" "$repo" "$hash" "$sentinel"
  exit 0
fi
rm -f "$sentinel"   # a new review run invalidates any prior approval
: > "$live"         # truncate: each run starts a fresh live log
echo "review-staged: live log: $live" >&2

prompt='You are a correctness reviewer. Your ONLY job is to find bugs: logic
errors, crashes, regressions, and broken documented invariants in the STAGED
diff (git diff --staged).

Scope:
- Read the diff hunks and enough surrounding code to judge each hunk in context.
- Read this repo'\''s CLAUDE.md for documented invariants only.
- A finding MUST have a concrete, reproducible failure: specific input or state
  that produces a wrong result, crash, or hang. No finding = PASS.
- Missing tests for new or changed behavior is a FAIL. Judge by READING test
  files — do not run test suites, linters, or formatters. CI covers those.

Out of scope (do NOT fail on these):
- Security surface, permission models, attack scenarios.
- Design decisions, naming, style, architecture.
- Interaction effects between this diff and unrelated subsystems.
- Whether a file "should" exist or a permission "should" be narrower.

Budget: at most 25 tool calls. At 20, stop and report. Over-budget is worse
than incomplete.

ACCEPTED_RISKS_PLACEHOLDER

Output exactly this shape:
## Findings
file:line — bug — concrete failure scenario (most severe first; "none" if none)
## Unverified
(plain statements, or "none")
VERDICT: PASS
(or VERDICT: FAIL — the verdict is the last line, nothing after it)'

# Accepted risks: the author can list known design decisions that the reviewer
# should note in Unverified but not count toward FAIL.
accept_file="${CLAUDE_REVIEW_ACCEPT:-}"
accept_section=""
if [[ -f "$accept_file" ]]; then
  accept_section="Accepted risks (the author has acknowledged these — note them in Unverified,
do NOT count them toward the verdict):
$(cat "$accept_file")"
  echo "review-staged: loaded accepted risks from $accept_file" >&2
fi
prompt="${prompt/ACCEPTED_RISKS_PLACEHOLDER/$accept_section}"

# Detect the author's model and effort from the session transcript (best-effort).
caller_model=""
caller_effort=""
if [[ -n "${CLAUDE_CODE_SESSION_ID:-}" ]] && command -v jq >/dev/null 2>&1; then
  tp=$(find "$HOME/.claude/projects" -name "${CLAUDE_CODE_SESSION_ID}.jsonl" 2>/dev/null | head -1)
  if [[ -n "$tp" ]]; then
    caller_model=$(jq -r 'select(.type=="assistant") | .message.model // empty' "$tp" 2>/dev/null | tail -1)
    caller_effort=$(jq -r 'select(.type=="system" and .subtype=="init") | .cliEffort // .effort // empty' "$tp" 2>/dev/null | tail -1)
  fi
fi

# Pick the reviewer model. The correctness-only prompt is sonnet-tier work;
# opus/fable are reserved for security review (--model or CLAUDE_REVIEW_MODEL).
# Precedence: --model > CLAUDE_REVIEW_MODEL > sonnet (default).
if [[ -n "$cli_model" ]]; then
  review_model="$cli_model"
elif [[ -n "${CLAUDE_REVIEW_MODEL:-}" ]]; then
  review_model="$CLAUDE_REVIEW_MODEL"
else
  review_model=sonnet
fi

# Pick the reviewer effort: one level above the author's, capped at xhigh.
# --bump doubles the step. Unknown author effort defaults to medium.
base_effort="${caller_effort:-medium}"
if [[ -n "$bump" ]]; then
  review_effort=$(auto_effort "$(auto_effort "$base_effort")")
else
  review_effort=$(auto_effort "$base_effort")
fi

echo "review-staged: author='${caller_model:-?}' effort='${caller_effort:-? (defaulting to medium)}' reviewer='${review_model:-<inherited>}' review_effort='$review_effort' staged=${staged_lines}L docs_only=$docs_only" >&2

# fable falls back to opus when unavailable rather than erroring out (which
# under set -e would kill the review and block commits).
review_fallback=""
[[ "$review_model" == "fable" ]] && review_fallback="opus"

run_review() {
  # </dev/null: the prompt is passed as an arg, so claude needs no stdin. Left
  # open (as under Claude's Bash tool, where fd0 is a non-EOF pipe) the child
  # can block on a stdin read forever — a silent hang with zero output.
  cd "$worktree" && claude -p "$prompt" \
    ${review_model:+--model "$review_model"} \
    ${review_effort:+--effort "$review_effort"} \
    ${review_fallback:+--fallback-model "$review_fallback"} \
    "$@" \
    --allowedTools "Read" "Grep" "Glob" "Bash(git diff:*)" "Bash(git log:*)" "Bash(git show:*)" "Bash(git status:*)" \
    </dev/null
}

# Show progress while the reviewer works. stream-json is the SAME generation as
# the default output — rendering each event as a terse step line to stderr costs
# no extra model tokens, it just unbuffers what -p otherwise withholds until the
# end. We tee the raw stream to a file and pull the final result text from it for
# verdict parsing. (--output-format stream-json requires --verbose in print
# mode.) No jq -> fall back to the old blocking capture with no live steps.
if command -v jq >/dev/null 2>&1; then
  stream="$state/review-$key.stream.jsonl"
  set +e
  run_review --output-format stream-json --verbose \
    | tee "$stream" \
    | jq -rj --unbuffered '
        if .type=="system" and .subtype=="init" then
          "▶ reviewing (model=\(.model // "?"))\n"
        elif .type=="assistant" then
          (.message.content[]? |
            if .type=="tool_use" then
              "  → \(.name) \(.input.file_path // .input.pattern // .input.command // .input.path // "")\n"
            elif .type=="text" and ((.text|length)>0) then
              "  ✎ \(.text | gsub("\\s+";" ") | .[0:100])\n"
            else empty end)
        elif .type=="result" then "◀ review complete\n"
        else empty end' \
    | tee -a "$live" >&2
  cstat=${PIPESTATUS[0]}
  set -e
  [[ $cstat -eq 0 ]] || { echo "review-staged: claude exited $cstat" >&2; exit "$cstat"; }
  out=$(jq -r 'select(.type=="result") | .result // empty' "$stream")
else
  out=$(run_review)
fi

{ echo "# Staged-diff review — $worktree"
  echo "- reviewed: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "- staged sha256: $hash"
  [[ -n "$accept_section" ]] && printf '\n## Accepted risks (loaded from %s)\n%s\n' "$accept_file" "$accept_section"
  echo
  echo "$out"
} > "$report"

echo "$out"
echo
verdict=$(echo "$out" | grep -E '^VERDICT: (PASS|FAIL)[[:space:]]*$' | tail -1 || true)
failcount="$state/review-fails-$key"
if [[ "$verdict" == "VERDICT: PASS" ]]; then
  printf '%s\n' "$hash" > "$sentinel"
  rm -f "$failcount"
  echo "review-staged: PASS — sentinel written; report: $report"
else
  # Track consecutive FAILs per staged hash so gates can escalate.
  cur_fails=0
  if [[ -f "$failcount" ]]; then
    saved_hash=$(sed -n '1p' "$failcount" 2>/dev/null)
    saved_count=$(sed -n '2p' "$failcount" 2>/dev/null)
    [[ "$saved_hash" == "$hash" ]] && cur_fails="${saved_count:-0}"
  fi
  printf '%s\n%s\n' "$hash" "$(( cur_fails + 1 ))" > "$failcount"
  echo "review-staged: FAIL ($(( cur_fails + 1 )) consecutive on this hash) — fix findings, restage, rerun. report: $report"
  exit 2
fi
