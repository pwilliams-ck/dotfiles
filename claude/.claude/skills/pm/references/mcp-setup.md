# MCP Setup — First-Run Checklist

The `/pm` skill depends on up to two MCP servers. Set each up once; tokens persist across sessions on the same surface.

---

## Servers

### ClickUp MCP — REQUIRED for any board action

Add and authenticate:

```
claude mcp add --scope user --transport http clickup https://mcp.clickup.com/mcp
```

Then run `/mcp` in Claude Code and complete the OAuth browser login.

Tools appear as `mcp__clickup__*` — they are deferred and must be loaded via `ToolSearch` before use.

### Atlassian / Confluence MCP — needed only for `publish-doc` / `publish-all`

Add the Atlassian MCP server (consult the Atlassian developer docs for the current add command), then run `/mcp` and complete the OAuth browser login. Confirm the server shows **Connected** before running any publish action.

---

## Verifying the setup

```
claude mcp list
```

Each required server should show **Connected**. If a server shows unauthenticated or missing, re-run `/mcp` to re-authenticate — OAuth tokens are not shared between the CLI and the desktop app, so each surface needs its own login.

---

## If a required server is missing

The skill prints the relevant step above and stops. Fix the connection, then retry the action.
