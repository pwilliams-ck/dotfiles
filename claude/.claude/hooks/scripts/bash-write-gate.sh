#!/usr/bin/env bash
# bash-write-gate.sh — PreToolUse(Bash) gate.
#
# Permission tiers:
#   reads + read-only git           -> allow (no prompt)
#   local git writes                -> allow (no prompt)
#   create NEW file                 -> allow (no prompt)
#   overwrite/modify EXISTING file  -> ask
#   remote git writes (push/pull)   -> deny (default) or ask (repo opted in)
#   gh CLI                          -> deny (default) or ask (repo opted in)
#   merge/rebase                    -> deny (always, no opt-in)
#   force-push, push main, tags    -> deny (always, no opt-in)
#   reset --hard, clean -f, rm -rf  -> deny (always)
#
# Repos opt in to remote writes by placing a .claude-remote-ok file in the
# repo root. This downgrades push/pull/gh from deny to ask.
#
# Only emits `allow` for a single, simple statement (no &&, ||, ;, |, command
# substitution, process substitution, or newline) so a compound command
# containing anything risky can never be auto-approved — it falls through to
# the static ask/deny rules in settings.json.
set -e
trap 'echo "bash-write-gate crashed at line $LINENO — command blocked, check the script" >&2; exit 2' ERR
input=$(cat)
cmd=$(echo "$input"  | jq -r '.tool_input.command // ""')
cwd=$(echo "$input"  | jq -r '.cwd // ""'); [[ -z "$cwd" ]] && cwd="$(pwd)"
[[ -z "$cmd" ]] && exit 0
emit(){ jq -n --arg d "$1" --arg r "$2" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'; exit 0; }

# Resolve the git directory for branch checks — `cd <repo> && git commit`
# must check the target repo's branch, not the session cwd.
gitdir="$cwd"
cd_arg=$(echo "$cmd" | sed -nE 's/^[[:space:]]*cd[[:space:]]+([^;&|]+)(&&|;).*/\1/p' \
         | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//; s/^["'\'']//; s/["'\'']$//')
if [[ -n "$cd_arg" ]]; then
  cd_arg="${cd_arg/#\~/$HOME}"
  [[ "$cd_arg" != /* ]] && cd_arg="$cwd/$cd_arg"
  gitdir="$cd_arg"
fi
c_arg=$(echo "$cmd" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+([^[:space:]]+).*/\1/p')
if [[ -n "$c_arg" ]]; then
  c_arg="${c_arg/#\~/$HOME}"
  [[ "$c_arg" != /* ]] && c_arg="$gitdir/$c_arg"
  gitdir="$c_arg"
fi

# Opt-in marker: .claude-remote-ok in the repo root downgrades remote
# writes from deny to ask.
repo_root=$(git -C "$gitdir" rev-parse --show-toplevel 2>/dev/null || true)
remote_ok=0
[[ -n "$repo_root" && -f "$repo_root/.claude-remote-ok" ]] && remote_ok=1

remote_gate(){
  if [[ "$remote_ok" == 1 ]]; then
    emit ask "$1 — repo opted in, needs approval."
  else
    emit deny "$1 blocked — add .claude-remote-ok to repo root to enable."
  fi
}

# ── DENY backstop (always, no opt-in) ──

echo "$cmd" | grep -Eq '\bgit\b([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+(merge|rebase)\b' \
  && emit deny "git merge/rebase is never auto-run — do it yourself."

if echo "$cmd" | grep -Eq '\bgit\b([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+push\b'; then
  echo "$cmd" | grep -Eq '(--force-with-lease|--force|[[:space:]]-[a-zA-Z]*f)\b' \
    && emit deny "force-push is never auto-run — do it yourself."
  echo "$cmd" | grep -Eq '[[:space:]]\+[^[:space:]]' \
    && emit deny "force-push (+refspec) is never auto-run — do it yourself."
  echo "$cmd" | grep -Eq '(--tags|--follow-tags)\b' \
    && emit deny "pushing tags is the prod deploy trigger — human-only."
  echo "$cmd" | grep -Eq -- '--no-verify\b' \
    && emit deny "push --no-verify bypasses the pre-push hook — human-only."
  echo "$cmd" | grep -Eq '(^|[[:space:]]|:|/|\+)(main|master)([[:space:]]|:|$)' \
    && emit deny "pushing main/master is human-only (merge deploys dev)."
  cur=$(git -C "$gitdir" branch --show-current 2>/dev/null || true)
  case "$cur" in
    main|master|"") emit deny "push from main/master (or an undetermined branch) is human-only." ;;
  esac
  remote_gate "Remote write (push)"
fi

if echo "$cmd" | grep -Eq '\bgit\b([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+commit\b'; then
  cur=$(git -C "$gitdir" branch --show-current 2>/dev/null || true)
  case "$cur" in
    main|master) emit deny "commit on $cur is blocked — create a feature branch first: git switch -c <type>/<kebab-name>." ;;
  esac
fi

if echo "$cmd" | grep -Eq '\bgit\b([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+pull\b'; then
  remote_gate "Remote write (pull)"
fi

echo "$cmd" | grep -Eq '\bgh\b.*\bpr\b.*\bmerge\b'            && emit deny "gh pr merge not allowed — merge manually."
echo "$cmd" | grep -Eq '\bgit\b([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+tag\b' \
  && ! echo "$cmd" | grep -Eq '\btag\b[[:space:]]+(-l|--list|-n|$)' \
  && emit deny "creating tags is the prod deploy trigger — human-only."
echo "$cmd" | grep -Eq '\bgit\b.*\breset\b.*--hard'          && emit deny "git reset --hard discards work — run it yourself."
echo "$cmd" | grep -Eq '\bgit\b.*\bclean\b.*-[a-zA-Z]*f'     && emit deny "git clean -f deletes untracked files — run it yourself."
echo "$cmd" | grep -Eq '\brm\b[^|;&]*-[a-zA-Z]*(rf|fr)'      && emit deny "rm -rf is not allowed."
echo "$cmd" | grep -Eq '\bshred\b'                           && emit deny "shred irreversibly destroys files — run it yourself."

# ── REMOTE backstop (gh in compound commands) ──

if echo "$cmd" | grep -Eq '\bgh\b'; then
  remote_gate "gh CLI command"
fi

# ── simplicity guard ──

is_simple=1
echo "$cmd" | grep -Eq '&&|\|\||[;|]|\$\(|`|>\(|<\(' && is_simple=0
[[ "$cmd" == *$'\n'* ]] && is_simple=0

first=$(echo "$cmd" | sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*//' | awk '{print $1}')

# ── git classification ──

if [[ "$first" == "git" ]]; then
  sub=$(echo "$cmd" | sed -E 's/^[[:space:]]*git[[:space:]]+//' \
        | sed -E 's/^((-C[[:space:]]+[^[:space:]]+|-c[[:space:]]+[^[:space:]]+|--git-dir=[^[:space:]]+|--work-tree=[^[:space:]]+|--no-pager|--paginate|-p)[[:space:]]+)*//' \
        | awk '{print $1}')
  case "$sub" in
    status|log|diff|show|reflog|shortlog|whatchanged|blame|describe|rev-parse|rev-list|\
    merge-base|name-rev|symbolic-ref|var|cat-file|ls-files|ls-tree|ls-remote|for-each-ref|count-objects|grep|fetch)
      [[ "$is_simple" == 1 ]] && emit allow "Read-only git command." ;;
    add|commit|switch|checkout|restore|reset|cherry-pick|revert|rm|mv|am|apply|submodule|worktree|clean)
      [[ "$is_simple" == 1 ]] && emit allow "Local git write command." ;;
    branch)
      if echo "$cmd" | grep -Eq '\-(d|D|m|M|-delete|-force)\b'; then
        [[ "$is_simple" == 1 ]] && emit allow "Local git branch write."
      else
        [[ "$is_simple" == 1 ]] && emit allow "git branch listing."
      fi ;;
    tag)     [[ "$is_simple" == 1 ]] && emit allow "git tag listing." ;;
    config)
      if echo "$cmd" | grep -Eq 'config[[:space:]].*(--get|--list|-l|(^| )get( |$))'; then
        [[ "$is_simple" == 1 ]] && emit allow "git config (read)."
      else
        [[ "$is_simple" == 1 ]] && emit allow "Local git config write."
      fi ;;
    remote)
      if echo "$cmd" | grep -Eq 'remote([[:space:]]+(-v|show|get-url[^;&|]*))?[[:space:]]*$'; then
        [[ "$is_simple" == 1 ]] && emit allow "git remote (read)."
      else
        [[ "$is_simple" == 1 ]] && emit allow "Local git remote config."
      fi ;;
    stash)
      if echo "$cmd" | grep -Eq 'stash[[:space:]]+(list|show)'; then
        [[ "$is_simple" == 1 ]] && emit allow "git stash (read)."
      else
        [[ "$is_simple" == 1 ]] && emit allow "Local git write command."
      fi ;;
  esac
  exit 0
fi

# touch / mkdir are pure create
if [[ "$first" == "touch" || "$first" == "mkdir" ]] && [[ "$is_simple" == 1 ]]; then
  emit allow "Creating files/directories."
fi

# redirect / tee — split create (allow) vs overwrite-existing (ask)
targets=""
echo "$cmd" | grep -Eq '>[^&]|^>|>$' && targets+=$'\n'$(echo "$cmd" | grep -oE '[0-9&]?>>?[[:space:]]*[^[:space:]&|;<>]+' | sed -E 's/^[0-9&]?>>?[[:space:]]*//')
[[ "$first" == "tee" ]] && targets+=$'\n'$(echo "$cmd" | sed -E 's/^[[:space:]]*tee[[:space:]]+//' | tr ' ' '\n' | grep -vE '^-')

if [[ -n "$(echo "$targets" | tr -d '[:space:]')" ]]; then
  any_exist=0; any_new=0
  while IFS= read -r t; do
    [[ -z "$t" ]] && continue
    case "$t" in /tmp/*|/private/tmp/*|/var/tmp/*|/var/folders/*|/dev/*) continue;; esac
    e="${t/#\~/$HOME}"; [[ "$e" != /* ]] && e="$cwd/$e"
    if [[ -e "$e" ]]; then any_exist=1; else any_new=1; fi
  done <<< "$targets"
  if [[ "$any_exist" == 1 ]]; then
    emit ask "Redirect/tee targets an existing file — would overwrite/modify it. Approve only if intended."
  fi
  base=$(basename "$first" 2>/dev/null || echo "$first")
  if [[ "$any_new" == 1 && "$is_simple" == 1 ]] && ! echo "$base" | grep -Eq '^(rm|rmdir|mv|cp|chmod|chown|chgrp|ln|truncate|sed|dd|shred|git|gh)$'; then
    emit allow "Creating a new file (target does not exist)."
  fi
fi

exit 0
