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
# Optional: CLAUDE_REVIEW_MODEL=<model|alias> to override the reviewing model.
set -euo pipefail

repo="${1:?usage: review-staged.sh <repo-root>}"
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

out=$(cd "$repo" && claude -p "$prompt" \
  ${CLAUDE_REVIEW_MODEL:+--model "$CLAUDE_REVIEW_MODEL"} \
  --allowedTools "Read" "Grep" "Glob" "Bash(git diff:*)" "Bash(git log:*)" "Bash(git show:*)" "Bash(git status:*)")

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
