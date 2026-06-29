# ClickUp (official MCP) — setup + conventions

## One-time setup (user does this; OAuth is interactive)

Official first-party MCP, public beta, OAuth only.

```bash
# register the server globally (Claude Code) — user scope, available in every project
claude mcp add --scope user --transport http clickup https://mcp.clickup.com/mcp
```

Then in Claude Code run `/mcp`, pick **clickup**, and complete the OAuth login
in the browser. After auth, the ClickUp tools appear as `mcp__clickup__*`
(deferred — load with ToolSearch `select:mcp__clickup__…` before calling).

If the tools are not present, **stop** and print the two steps above. Never
fall back to guessing IDs.

Docs: https://developer.clickup.com/docs/connect-an-ai-assistant-to-clickups-mcp-server

## Discover, don't guess

Tool names and the workspace/space/folder/list/task IDs are **not** hard-coded
here — they differ per workspace and the beta tool surface changes. At runtime:

1. `ToolSearch` query `clickup` to load the MCP tool schemas.
2. List all workspaces the authenticated user has access to.
3. Identify which workspace + space/folder + list the **current repo/project**
   maps to — match on project name, team name, or any recognisable signal in
   the hierarchy.
4. Confirm the resolved workspace + list with the user before any reads or
   writes against them.

Cache the resolved IDs in your working notes for the session; do not write them
into this file (they're environment state, not skill config).

## Board discovery procedure

1. Call `clickup_get_workspace_hierarchy` (or equivalent list-workspaces tool)
   to enumerate available workspaces.
2. Walk spaces → folders → lists to find the board that matches this project.
   Use the current repo name, directory name, or any project identifier the
   user has mentioned as search signals.
3. Present the candidate workspace + list to the user in one line and wait for
   confirmation before proceeding.
4. Once confirmed, list the top-level tasks and their statuses to understand
   the board's current shape.

If no clear match is found, ask the user to name the workspace and list
directly rather than guessing.

## Write conventions

- **Subtask, not comment**, for each build task — keep the description field as
  the canonical summary (template in `references/phase-map.md`).
- Use ClickUp's **existing statuses only** — discover them from the board at
  runtime; don't create new ones without asking.
- Markdown is supported in descriptions — use it, with links out to the repo
  task doc and the Confluence page. **Not every team member has repo access**,
  so always pair a repo link with the Confluence link once the doc is published.
- Don't set assignees, dates, or priorities unless the user specifies them
  (exception: always assign **the authenticated user** to any task/subtask this
  skill creates or edits — resolve the id via
  `clickup_resolve_assignees(["me"])` at runtime).
- Idempotent: before creating a subtask, check it doesn't already exist
  (match on title); update in place if it does.
- Confirm the full subtask list with the user **before** the first write of a
  bulk fill — then write them in one Sonnet pass.
