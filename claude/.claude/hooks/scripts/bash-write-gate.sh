#!/usr/bin/env bash
# bash-write-gate.sh — PreToolUse(Bash) gate. Supersedes redirect-gate.sh.
#   reads + read-only git           -> allow (no prompt)
#   create NEW file                 -> allow (no prompt)
#   overwrite/modify EXISTING file  -> ask
#   writing git (commit/add/pull/…) -> defer to static `git *` ask
#   feature-branch push             -> defer to static `git *` ask
#   merge/rebase, force-push, push of main/master, tag push, tag create,
#     gh pr merge, reset --hard, clean -f, rm -rf, dd, shred -> deny
#
# Only emits `allow` for a single, simple statement (no &&, ||, ;, |, command
# substitution, process substitution, or newline) so a compound command
# containing anything risky can never be auto-approved — it falls through to
# the static ask/deny rules in settings.json.
set -e
input=$(cat)
cmd=$(echo "$input"  | jq -r '.tool_input.command // ""')
cwd=$(echo "$input"  | jq -r '.cwd // ""'); [[ -z "$cwd" ]] && cwd="$(pwd)"
[[ -z "$cmd" ]] && exit 0
emit(){ jq -n --arg d "$1" --arg r "$2" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'; exit 0; }

# `git -C <path>` targets that repo, not the shell cwd — resolve branch checks
# against it. (No \b in the sed — macOS sed -E lacks it.)
gitdir="$cwd"
c_arg=$(echo "$cmd" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+([^[:space:]]+).*/\1/p')
[[ -n "$c_arg" ]] && gitdir="${c_arg/#\~/$HOME}"

# 1) DENY backstop — robust to `git -C x push`, double-spacing, etc.
# merge / rebase are never run by the agent.
echo "$cmd" | grep -Eq '\bgit\b([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+(merge|rebase)\b' \
  && emit deny "git merge/rebase is never auto-run — do it yourself."

# git push: feature-branch pushes are allowed (they still prompt via the
# static `git *` ask rule). But force-push, pushing tags, and pushing
# main/master are denied outright — a merge to main deploys dev and a version
# tag deploys prod, so both are human-only. When the target branch cannot be
# determined, fail safe and deny.
if echo "$cmd" | grep -Eq '\bgit\b([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+push\b'; then
  echo "$cmd" | grep -Eq '(--force-with-lease|--force|[[:space:]]-[a-zA-Z]*f)\b' \
    && emit deny "force-push is never auto-run — do it yourself."
  echo "$cmd" | grep -Eq '(--tags|--follow-tags)\b' \
    && emit deny "pushing tags is the prod deploy trigger — human-only."
  echo "$cmd" | grep -Eq '(^|[[:space:]]|:|/)(main|master)([[:space:]]|:|$)' \
    && emit deny "pushing main/master is human-only (merge deploys dev)."
  # No explicit branch ref -> current branch is the target. Deny on
  # main/master, or when the branch is undeterminable (detached/error).
  cur=$(git -C "$gitdir" branch --show-current 2>/dev/null || true)
  case "$cur" in
    main|master|"") emit deny "push from main/master (or an undetermined branch) is human-only." ;;
  esac
  # otherwise: feature-branch push -> fall through to the static `git *` ask.
fi

# git commit while on main/master is denied — feature branch first. When the
# branch is undeterminable (not a repo, detached, cd elsewhere in a compound
# command) fall through to the static `git commit` ask instead of denying.
if echo "$cmd" | grep -Eq '\bgit\b([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+commit\b'; then
  cur=$(git -C "$gitdir" branch --show-current 2>/dev/null || true)
  case "$cur" in
    main|master) emit deny "commit on $cur is blocked — create a feature branch first: git switch -c <type>/<kebab-name>." ;;
  esac
fi

echo "$cmd" | grep -Eq '\bgh\b.*\bpr\b.*\bmerge\b'            && emit deny "gh pr merge not allowed — merge manually."
# git tag creation (anything other than -l/--list/-n listing) is the prod
# deploy trigger — human-only.
echo "$cmd" | grep -Eq '\bgit\b([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+tag\b' \
  && ! echo "$cmd" | grep -Eq '\btag\b[[:space:]]+(-l|--list|-n|$)' \
  && emit deny "creating tags is the prod deploy trigger — human-only."
echo "$cmd" | grep -Eq '\bgit\b.*\breset\b.*--hard'          && emit deny "git reset --hard discards work — run it yourself."
echo "$cmd" | grep -Eq '\bgit\b.*\bclean\b.*-[a-zA-Z]*f'     && emit deny "git clean -f deletes untracked files — run it yourself."
echo "$cmd" | grep -Eq '\brm\b[^|;&]*-[a-zA-Z]*(rf|fr)'      && emit deny "rm -rf is not allowed."
echo "$cmd" | grep -Eq '\bshred\b'                           && emit deny "shred irreversibly destroys files — run it yourself."

# ASK backstop: write git anywhere in the command. The static settings.json
# ask rules are PREFIX matches, so `git -C x commit`, `VAR=1 git add`, and
# `cd x && git commit` all slip past them to the broad Bash allow. Catch the
# write subcommand positionally (after `git [opts]`) and force the prompt.
# Runs after every deny backstop so denies keep winning; stash list/show
# stays read-only (allowed below).
if echo "$cmd" | grep -Eq '\bgit\b([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+(add|commit|switch|checkout|restore|pull|reset|cherry-pick|revert|rm|mv|am|apply|submodule|worktree|stash)\b' \
   && ! echo "$cmd" | grep -Eq '\bstash[[:space:]]+(list|show)\b'; then
  emit ask "Write git command — needs per-command approval."
fi

# simplicity guard: only auto-ALLOW single simple statements
is_simple=1
echo "$cmd" | grep -Eq '&&|\|\||[;|]|\$\(|`|>\(|<\(' && is_simple=0
[[ "$cmd" == *$'\n'* ]] && is_simple=0

first=$(echo "$cmd" | sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*//' | awk '{print $1}')

# 2) git classification (read-only -> allow; everything else -> defer to static `git *` ask)
if [[ "$first" == "git" ]]; then
  sub=$(echo "$cmd" | sed -E 's/^[[:space:]]*git[[:space:]]+//' \
        | sed -E 's/^((-C[[:space:]]+[^[:space:]]+|-c[[:space:]]+[^[:space:]]+|--git-dir=[^[:space:]]+|--work-tree=[^[:space:]]+|--no-pager|--paginate|-p)[[:space:]]+)*//' \
        | awk '{print $1}')
  case "$sub" in
    status|log|diff|show|reflog|shortlog|whatchanged|blame|describe|rev-parse|rev-list|\
    merge-base|name-rev|symbolic-ref|var|cat-file|ls-files|ls-tree|ls-remote|for-each-ref|count-objects|grep|fetch)
      [[ "$is_simple" == 1 ]] && emit allow "Read-only git command." ;;
    branch)  echo "$cmd" | grep -Eq '\-(d|D|m|M|-delete|-force)\b' || { [[ "$is_simple" == 1 ]] && emit allow "git branch listing."; } ;;
    tag)     echo "$cmd" | grep -Eq 'tag[[:space:]]+(-l|--list|-n|$)' && [[ "$is_simple" == 1 ]] && emit allow "git tag listing." ;;
    remote)  echo "$cmd" | grep -Eq 'remote([[:space:]]+(-v|show))?[[:space:]]*$' && [[ "$is_simple" == 1 ]] && emit allow "git remote (read)." ;;
    config)  echo "$cmd" | grep -Eq 'config[[:space:]].*(--get|--list|-l|(^| )get( |$))' && [[ "$is_simple" == 1 ]] && emit allow "git config (read)." ;;
    stash)   echo "$cmd" | grep -Eq 'stash[[:space:]]+(list|show)' && [[ "$is_simple" == 1 ]] && emit allow "git stash (read)." ;;
  esac
  exit 0   # all other git (add/commit/switch/checkout/restore/pull/tag-create/…) -> static `git *` ask
fi

# touch / mkdir are pure create
if [[ "$first" == "touch" || "$first" == "mkdir" ]] && [[ "$is_simple" == 1 ]]; then
  emit allow "Creating files/directories."
fi

# 3) redirect / tee — split create (allow) vs overwrite-existing (ask)
targets=""
echo "$cmd" | grep -Eq '>[^&]|^>|>$' && targets+=$'\n'$(echo "$cmd" | grep -oE '[0-9&]?>>?[[:space:]]*[^[:space:]&|;<>]+' | sed -E 's/^[0-9&]?>>?[[:space:]]*//')
[[ "$first" == "tee" ]] && targets+=$'\n'$(echo "$cmd" | sed -E 's/^[[:space:]]*tee[[:space:]]+//' | tr ' ' '\n' | grep -vE '^-')

if [[ -n "$(echo "$targets" | tr -d '[:space:]')" ]]; then
  any_exist=0; any_new=0
  while IFS= read -r t; do
    [[ -z "$t" ]] && continue
    # tmp dirs and device files (/dev/null, /dev/stderr, …) are not real
    # user files — writing to them is benign, ignore.
    case "$t" in /tmp/*|/private/tmp/*|/var/tmp/*|/var/folders/*|/dev/*) continue;; esac
    e="${t/#\~/$HOME}"; [[ "$e" != /* ]] && e="$cwd/$e"
    if [[ -e "$e" ]]; then any_exist=1; else any_new=1; fi
  done <<< "$targets"
  if [[ "$any_exist" == 1 ]]; then
    emit ask "Redirect/tee targets an existing file — would overwrite/modify it. Approve only if intended."
  fi
  # Only auto-allow when a redirect genuinely creates a new file; a command
  # whose only redirect is stderr-suppression (2>/dev/null) has no new target
  # here and falls through to defer.
  base=$(basename "$first" 2>/dev/null || echo "$first")
  if [[ "$any_new" == 1 && "$is_simple" == 1 ]] && ! echo "$base" | grep -Eq '^(rm|rmdir|mv|cp|chmod|chown|chgrp|ln|truncate|sed|dd|shred|git|gh)$'; then
    emit allow "Creating a new file (target does not exist)."
  fi
fi

exit 0   # everything else -> defer to static rules / existing behavior
