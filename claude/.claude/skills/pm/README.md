# `/pm` — project manager (global Claude Code skill)

Keeps a **ClickUp board** and **Confluence docs** in lock-step with whatever
repo you're in. **Project-agnostic:** the workspace, board/list, and Confluence
space are *discovered at runtime and confirmed with you* — nothing is
hard-coded. Routine MCP work runs on a Haiku subagent so bulky JSON never bloats
the session.

## Install

User-scope skill — lives at `~/.claude/skills/pm/`. From dotfiles, symlink it:

```bash
ln -s "$DOTFILES/claude/skills/pm" ~/.claude/skills/pm
```

No build step (it's a prompt + reference docs). Invoke with `/pm <action>` in
Claude Code (CLI or desktop app).

## Prerequisites (MCP servers)

| Server                | Needed for            | Setup                                   |
| --------------------- | --------------------- | --------------------------------------- |
| **ClickUp** (req'd)   | every board action    | `claude mcp add --scope user --transport http clickup https://mcp.clickup.com/mcp` → `/mcp` OAuth |
| **Atlassian**         | `publish-doc` / `-all`| add + authenticate via `/mcp`           |

Verify with `claude mcp list`. OAuth tokens may not be shared between CLI and
desktop — re-run `/mcp` per surface. See `references/mcp-setup.md`.

## Actions

```
/pm status              # reconcile the board vs repo reality; report drift
/pm fill <list>         # backfill subtasks in a board list from the repo's task docs
/pm publish-doc <name>  # publish/update one repo doc as a Confluence page
/pm publish-all         # publish the whole doc set, in dependency order
/pm plan <topic>        # short ranked recommendation for a decision
```

All board/doc actions: **reads are free; every create/update is confirmed
first**, scoped to the **authenticated user's** own tasks, and never destructive
on completed work. Targets are discovered and confirmed per project.

## Files

```
pm/
  SKILL.md                     # actions, safety rules, model policy, workflow
  README.md                    # this file
  references/
    mcp-setup.md               # first-run MCP auth checklist
    clickup.md                 # ClickUp MCP setup + board discovery
    confluence.md              # Confluence setup + space/folder discovery
    phase-map.md               # method for mapping a board ↔ repo work ↔ docs
```

## Notes

- Model policy: routine ClickUp/Confluence reads + writes run on a Haiku
  subagent; orchestration/confirmation stays on the session model.
```
