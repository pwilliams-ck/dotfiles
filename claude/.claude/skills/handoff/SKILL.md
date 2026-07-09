---
name: handoff
description: End-of-session handoff — capture state to HANDOFF.md and print a paste-ready prompt for the next Claude session. Subcommands via argument: (none) = general handoff, "merged" = PR merged, prompt targets the next slice, "stash" = work stashed, prompt includes the stash. e.g. /handoff, /handoff merged, /handoff stash.
---

# Session Handoff

Produce two artifacts, in this order: an updated handoff file, then a
paste-ready prompt. The **file is the source of truth**; the prompt is a
pointer plus the first action. Assume the next session starts with zero
context.

## 1. Gather state (read-only)

- `git branch --show-current`, `git status --short`, `git stash list`.
- Current task: the project's `docs/todo/task*.md` (or wherever this repo
  tracks tasks) and any existing `HANDOFF.md`.
- Open PR, if any: `gh pr view --json number,url,state` (best effort).

## 2. Write the handoff file

Write/refresh the repo's `HANDOFF.md` (or the project's existing handoff
location if it has one). Contents, terse:

- What just landed: branch, key files, PR number if open.
- Exact repo state: branch to switch to, stash name if any, uncommitted files.
- Open decisions and gotchas discovered this session.
- Next step, concrete: task id + first action.

Do not commit it — leave that to the user or the next session's slice commit.

## 3. Print the paste-ready prompt

Emit a fenced code block the user can copy verbatim into a new session.
Format:

```
Read HANDOFF.md first. We are in <repo path> on branch <branch>.
<one sentence: state — e.g. "PR #N merged; main is current" / "work is stashed as <stash>">.
Next: <task id / concrete first action>. <one constraint that is session-specific and not derivable from HANDOFF.md or CLAUDE.md, if any>.
```

Rules: no restating global CLAUDE.md policy (git gates, TDD — the next
session loads it anyway); no narrative; ≤5 lines.

## Subcommands (`$ARGUMENTS`)

- **(none)** — general handoff as above.
- **`merged`** — assume the PR just merged. Verify with `gh pr view` if
  possible; note main needs a pull (don't run it). Prompt targets the *next*
  task from the todo docs: name it explicitly.
- **`stash`** — work is being stashed for a restart. Confirm the stash exists
  in `git stash list` and reference it by name in both file and prompt. If no
  stash exists yet, show the `git stash push -m "<slug>"` command for the user
  to approve — never assume it ran.

After printing the prompt, stop. Do not start the next task.
