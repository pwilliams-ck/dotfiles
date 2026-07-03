#!/usr/bin/env bash
# review-staged.sh <repo-root> — adversarial fresh-context review of a repo's
# STAGED diff via headless `claude -p`: a separate process that adopts the full
# harness (global + repo CLAUDE.md, hooks, permissions), billed to the CLI's
# logged-in subscription — no API dollars, but it shares the sub's usage limits.
#
# On VERDICT: PASS it writes the sentinel review-gate.sh checks, so the
# authoring session never writes its own approval. The full report is kept at
# ~/.claude/hooks/state/review-<repo-key>.md (one per repo, overwritten).
# Fail-closed: a missing/garbled verdict counts as FAIL.
#
# Reviewer model: by default the reviewer uses the SAME model as the authoring
# session (a peer audit in fresh context). Pass --bump to review one capability
# tier ABOVE the author instead (ladder: haiku < sonnet < opus < fable, capped
# at fable), or --model <name> to pin an explicit model. The author's model is
# read from its session transcript; if it can't be determined the reviewer
# inherits the CLI default. CLAUDE_REVIEW_MODEL=<model|alias> sets a default too.
set -euo pipefail

# ---- pure tier helper (unit-tested; ladder: haiku < sonnet < opus < fable) ----
auto_reviewer() {  # author model -> one tier above (capped at fable; "" if unknown)
  case "$1" in
    *haiku*)  echo sonnet ;;
    *sonnet*) echo opus ;;
    *opus*)   echo fable ;;
    *fable*)  echo fable ;;
    *)        echo "" ;;
  esac
}
# Tests source this file for the helper above and stop here.
[[ -n "${REVIEW_STAGED_LIB_ONLY:-}" ]] && return 0

repo=""
cli_model=""   # --model <m>: explicit reviewer model (highest precedence)
bump=""        # --bump: review one tier above the author instead of same tier
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)   cli_model="${2:?--model needs a value}"; shift 2 ;;
    --model=*) cli_model="${1#--model=}"; shift ;;
    --bump)    bump=1; shift ;;
    --)        shift; break ;;
    -*)        echo "review-staged: unknown flag $1" >&2; exit 1 ;;
    *)         [[ -z "$repo" ]] || { echo "review-staged: unexpected arg $1" >&2; exit 1; }
               repo="$1"; shift ;;
  esac
done
[[ -n "$repo" ]] || { echo "usage: review-staged.sh <repo-root> [--model <model>] [--bump]" >&2; exit 1; }
repo=$(git -C "$repo" rev-parse --show-toplevel)
hash=$(git -C "$repo" diff --staged | shasum -a 256 | awk '{print $1}')
empty=$(printf '' | shasum -a 256 | awk '{print $1}')
[[ "$hash" == "$empty" ]] && { echo "review-staged: nothing staged in $repo" >&2; exit 1; }

key=$(printf '%s' "$repo" | shasum -a 256 | awk '{print $1}')
state="$HOME/.claude/hooks/state"; mkdir -p "$state"
report="$state/review-$key.md"
sentinel="$state/review-ok-$key"
rm -f "$sentinel"   # a new review run invalidates any prior approval

prompt='You are an independent, adversarial code reviewer with zero attachment
to the change under review. The author is a capable model whose known failure
mode is filling spec silence with plausible happy-path defaults — hunt there.

Review ONLY the STAGED diff of this repo (git diff --staged). Rules:
1. Read enough surrounding code (the full functions/files touched) to judge
   each hunk in context — never a hunk in isolation.
2. Read this repo'\''s CLAUDE.md and any invariants/design docs it points to.
   A diff violating a documented invariant is an automatic FAIL.
3. Priority order: security, data integrity, reliability; then readability;
   then performance. For each candidate finding, construct a concrete failing
   input or state — concurrency (races, double-execution, idempotency),
   unhappy paths (error/timeout/partial failure), boundary values, injection,
   authz/tenancy scoping.
4. Missing tests for changed app/lib behavior is a FAIL.
5. Never guess; list anything you could not verify under Unverified.

Output exactly this shape:
## Findings
file:line — defect — concrete failure scenario (most severe first; "none" if none)
## Unverified
(plain statements, or "none")
VERDICT: PASS
(or VERDICT: FAIL — the verdict is the last line, nothing after it)'

# Detect the authoring session's model from its transcript (best-effort).
caller_model=""
if [[ -n "${CLAUDE_CODE_SESSION_ID:-}" ]] && command -v jq >/dev/null 2>&1; then
  tp=$(find "$HOME/.claude/projects" -name "${CLAUDE_CODE_SESSION_ID}.jsonl" 2>/dev/null | head -1)
  [[ -n "$tp" ]] && caller_model=$(jq -r 'select(.type=="assistant") | .message.model // empty' "$tp" 2>/dev/null | tail -1)
fi

# Pick the reviewer model. Precedence: --model <name> > --bump (one tier above
# the author, capped at fable) > CLAUDE_REVIEW_MODEL env > same model as the
# author (default). Empty (author unknown) -> inherit the CLI default. No
# interactive prompt: this runs non-interactively (Claude's Bash tool, the `!`
# prefix, cron) with no answerable tty, so any read would just hang.
if [[ -n "$cli_model" ]]; then
  review_model="$cli_model"
elif [[ -n "$bump" ]]; then
  review_model=$(auto_reviewer "$caller_model")
elif [[ -n "${CLAUDE_REVIEW_MODEL:-}" ]]; then
  review_model="$CLAUDE_REVIEW_MODEL"
else
  review_model="$caller_model"
fi
echo "review-staged: author='${caller_model:-?}' reviewer='${review_model:-<inherited default>}'" >&2

# fable is only guaranteed to subs through 2026-07-07; when it's unavailable the
# CLI falls back to opus rather than erroring out (which under set -e would kill
# the review and block commits).
review_fallback=""
[[ "$review_model" == "fable" ]] && review_fallback="opus"

run_review() {
  # </dev/null: the prompt is passed as an arg, so claude needs no stdin. Left
  # open (as under Claude's Bash tool, where fd0 is a non-EOF pipe) the child
  # can block on a stdin read forever — a silent hang with zero output.
  cd "$repo" && claude -p "$prompt" \
    ${review_model:+--model "$review_model"} \
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
        else empty end' >&2
  cstat=${PIPESTATUS[0]}
  set -e
  [[ $cstat -eq 0 ]] || { echo "review-staged: claude exited $cstat" >&2; exit "$cstat"; }
  out=$(jq -r 'select(.type=="result") | .result // empty' "$stream")
else
  out=$(run_review)
fi

{ echo "# Staged-diff review — $repo"
  echo "- reviewed: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "- staged sha256: $hash"
  echo
  echo "$out"
} > "$report"

echo "$out"
echo
verdict=$(echo "$out" | grep -E '^VERDICT: (PASS|FAIL)[[:space:]]*$' | tail -1 || true)
if [[ "$verdict" == "VERDICT: PASS" ]]; then
  printf '%s\n' "$hash" > "$sentinel"
  echo "review-staged: PASS — sentinel written; report: $report"
else
  echo "review-staged: FAIL (or no parseable verdict) — fix findings, restage, rerun. report: $report"
  exit 2
fi
