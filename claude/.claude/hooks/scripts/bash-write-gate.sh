#!/usr/bin/env bash
# bash-write-gate.sh — PreToolUse(Bash) gate.
#
# Permission tiers:
#   reads + read-only git           -> allow (no prompt)
#   local git writes (add, commit)  -> allow (no prompt)
#   create NEW file                 -> allow (no prompt)
#   overwrite/modify EXISTING file  -> ask
#   git pull --ff-only              -> allow (no prompt)
#   LOCAL merge/rebase              -> allow (default) or deny (.claude-merge-off)
#   remote git writes (push), gh    -> ask (default) or deny (.claude-remote-off)
#   REMOTE merge/rebase, gh pr merge-> deny, always. No marker changes it.
#   force-push, push main, tags    -> deny (always)
#   reset --hard, clean -f, rm -rf  -> deny (always)
#
# Two per-repo opt-OUT markers, both files in the repo root. They tighten a
# repo below the default; their absence is the permissive default:
#   .claude-remote-off  push/gh            ask   -> deny
#   .claude-merge-off   LOCAL merge/rebase allow -> deny
# Neither affects a merge or rebase whose target is a remote ref, and nothing
# permits `gh pr merge`. Those are human-only, permanently.
# Flip both with `claude-gate`.
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

repo_root=$(git -C "$gitdir" rev-parse --show-toplevel 2>/dev/null || true)
remote_off=0; merge_off=0
[[ -n "$repo_root" && -f "$repo_root/.claude-remote-off" ]] && remote_off=1
[[ -n "$repo_root" && -f "$repo_root/.claude-merge-off"  ]] && merge_off=1
cur=$(git -C "$gitdir" branch --show-current 2>/dev/null || true)

remote_gate(){
  if [[ "$remote_off" == 1 ]]; then
    emit deny "$1 blocked — this repo is opted out (.claude-remote-off). Re-enable with: claude-gate remote on"
  else
    emit ask "$1 — needs approval."
  fi
}

# ── simplicity guard ──

is_simple=1
echo "$cmd" | grep -Eq '&&|\|\||[;|]|\$\(|`|>\(|<\(' && is_simple=0
[[ "$cmd" == *$'\n'* ]] && is_simple=0

first=$(echo "$cmd" | sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*//' | awk '{print $1}')

# ── merge / rebase ──
#
# `(merge|rebase)([[:space:]]|$)` rather than \b: \b matches before the hyphen
# in merge-base and rebase-related plumbing, which are read-only.
if echo "$cmd" | grep -Eq '\bgit\b([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+(merge|rebase)([[:space:]]|$)'; then
  op=$(echo "$cmd" | grep -oE '(merge|rebase)([[:space:]]|$)' | head -1 | tr -d '[:space:]')
  args=$(echo "$cmd" | sed -E "s/.*[[:space:]]${op}([[:space:]]|\$)//")

  # --abort/--continue/etc. steer an in-flight operation; they resolve local
  # state and never reach a remote, so they sit in the local tier.
  ctl=0
  echo "$args" | grep -Eq -- '--(abort|quit|continue|skip|edit-todo|show-current-patch)\b' && ctl=1

  remotes=$(git -C "$gitdir" remote 2>/dev/null | paste -sd'|' -)
  [[ -z "$remotes" ]] && remotes='origin|upstream'
  is_remote=0
  if [[ "$ctl" == 0 ]]; then
    echo "$args" | grep -Eq "(^|[[:space:]=])($remotes)/"           && is_remote=1
    echo "$args" | grep -Eq '(^|[[:space:]=])(FETCH_HEAD|refs/remotes/)' && is_remote=1
    echo "$args" | grep -Eq '(https?://|git@|ssh://|git://)'        && is_remote=1
    # Bare `git rebase` rebases onto @{upstream} — a remote-tracking ref.
    if [[ "$op" == rebase ]] && ! echo "$args" | tr ' ' '\n' | grep -qE '^[^-][^[:space:]]*'; then
      is_remote=1
    fi
  fi

  if [[ "$is_remote" == 1 && "$op" == merge ]]; then
    emit deny "Remote merge is denied permanently — no marker file enables it.
If YOU run this yourself: git replays the remote-tracking ref's commits into ${cur:-your current branch} and writes a merge commit (or fast-forwards). Nothing is sent to the server, but your local history changes and the next push carries those commits; conflicts can land in your working tree. Undo with 'git merge --abort' mid-conflict, or 'git reset --hard ORIG_HEAD' once it has committed."
  fi
  if [[ "$is_remote" == 1 && "$op" == rebase ]]; then
    emit deny "Remote rebase is denied permanently — no marker file enables it.
If YOU run this yourself: git rewrites your local commits on top of the remote ref, giving each replayed commit a NEW sha. ${cur:-Your branch} then diverges from its pushed copy, so the next push is rejected unless forced. Undo with 'git rebase --abort' mid-flight, or 'git reset --hard ORIG_HEAD' after it finishes."
  fi

  [[ "$merge_off" == 1 ]] &&
    emit deny "Local git $op blocked — this repo is opted out (.claude-merge-off). Re-enable with: claude-gate merge on"
  # A compound command can hide anything after the merge, so it still asks.
  [[ "$is_simple" == 1 ]] && emit allow "Local git $op — target is not a remote ref."
  emit ask "Local git $op inside a compound command — check what else the line does."
fi

# ── branch switch with a dirty tree ──
#
# Uncommitted changes follow you across a switch and land on the branch you
# arrive at, quietly mixing unrelated work together. A worktree gives the new
# branch its own checkout and leaves the dirty one untouched.
if echo "$cmd" | grep -Eq '\bgit\b([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+(switch|checkout)([[:space:]]|$)'; then
  sw=$(echo "$cmd" | grep -oE '(switch|checkout)([[:space:]]|$)' | head -1 | tr -d '[:space:]')
  swargs=$(echo "$cmd" | sed -E "s/.*[[:space:]]${sw}([[:space:]]|\$)//")
  target=$(echo "$swargs" | tr ' ' '\n' | grep -vE '^-|^$' | head -1)

  # `git checkout -- <path>` and `git checkout <path>` restore files and change
  # no branch, so they are none of this gate's business. git switch takes no
  # paths, so only checkout needs the distinction.
  restore=0
  if [[ "$sw" == checkout ]]; then
    echo "$swargs" | grep -Eq '(^|[[:space:]])--([[:space:]]|$)' && restore=1
    [[ -n "$target" && -e "$gitdir/$target" ]] \
      && ! git -C "$gitdir" show-ref --verify --quiet "refs/heads/$target" && restore=1
  fi

  if [[ "$restore" == 0 && -n "$repo_root" && -n "$target" && "$target" != "$cur" ]]; then
    dirty=$(git -C "$gitdir" status --porcelain --untracked-files=no 2>/dev/null | wc -l | tr -d ' ')
    if [[ "${dirty:-0}" -gt 0 ]]; then
      emit ask "$dirty uncommitted file(s) will follow this switch onto '$target' and become part of that branch's work.
If they belong to ${cur:-the branch you are on}, leave them here and give the new work its own checkout:
  git worktree add ../$(basename "$repo_root")-${target//\//-} -b $target
Approve only if the uncommitted changes are meant to move."
    fi
  fi
fi

# ── DENY backstop (always, no opt-in) ──

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
  case "$cur" in
    main|master|"") emit deny "push from main/master (or an undetermined branch) is human-only." ;;
  esac
  remote_gate "Remote write (push)"
fi

if echo "$cmd" | grep -Eq '\bgit\b([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+commit\b'; then
  case "$cur" in
    main|master) emit deny "commit on $cur is blocked — create a feature branch first: git switch -c <type>/<kebab-name>." ;;
  esac
fi

# `git pull` is fetch + integrate. The integrate half is a merge or rebase
# against a remote ref, so only --ff-only survives: it can advance a branch
# pointer or fail, never write a merge commit and never rewrite a sha. That
# makes it a local write on top of an already-allowed fetch, so it is allowed.
if echo "$cmd" | grep -Eq '\bgit\b([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+pull\b'; then
  echo "$cmd" | grep -Eq -- '[[:space:]](--rebase|-r)([[:space:]]|=|$)' \
    && emit deny "git pull --rebase is a remote rebase — denied permanently.
If YOU run this yourself: git fetches, then replays your local commits on top of the remote branch with new shas, so ${cur:-your branch} diverges from its pushed copy and the next push needs --force. Use 'git fetch' and inspect first if you only want to see what changed."
  echo "$cmd" | grep -Eq -- '[[:space:]]--ff-only([[:space:]]|$)' \
    || emit deny "plain git pull merges a remote ref into ${cur:-your branch} — denied permanently.
If YOU run this yourself: git fetches, then merges the remote branch into yours, writing a merge commit whenever the two have diverged. Use 'git pull --ff-only', which is allowed, to refuse anything that is not a clean fast-forward."
  [[ "$is_simple" == 1 ]] && emit allow "git pull --ff-only writes only locally — it fast-forwards or fails."
  remote_gate "Remote write (pull --ff-only, compound command)"
fi

echo "$cmd" | grep -Eq '\bgh\b.*\bpr\b.*\bmerge\b' && emit deny "gh pr merge is denied permanently — no marker file enables it.
If YOU run this yourself: GitHub merges the PR head into its base branch ON THE SERVER, immediately, and with --delete-branch also deletes the head branch. There is no local undo — reversing it needs a revert PR."
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
