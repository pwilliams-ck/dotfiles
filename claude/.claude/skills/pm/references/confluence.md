# Confluence (Atlassian MCP) — space, page tree, conventions

Confluence is the **canonical reader-facing home** for finalized docs —
written for people who do **not** have a GitHub account. Repo docs are the
source; Confluence pages are the published, cross-linked, diagram-rich version.

## Setup (user authenticates once)

The Atlassian MCP is already present (`mcp__claude_ai_Atlassian__*`, deferred).
Authenticate once: run `mcp__claude_ai_Atlassian__authenticate`, complete the
browser flow, then `mcp__claude_ai_Atlassian__complete_authentication`. Load
the read/write page tools via `ToolSearch` query `atlassian confluence page`.

If unauthenticated, **stop** and tell the user to run the auth tool.

## Target location — discover and confirm

Do **not** hard-code any space key, folder name, or page id.

On the first `publish-*` action in a session, **discover and confirm**:

1. List available Confluence spaces via the MCP; present them to the user.
2. Ask: "Which space should docs for this project publish to?"
3. Within the confirmed space, list top-level folders/pages; ask which folder
   (or parent page) the project's docs live under (or should be created under).
4. Cache the confirmed space key and parent page id in working notes for the
   session — do **not** write them back into this file.

All subsequent `publish-doc` / `publish-all` calls in the session use the
confirmed space + folder without asking again.

## Page tree — derive from the project, not from a fixed list

There is no universal page tree. For each project, infer the right set of
pages from:

- The docs the repo actually contains (check `docs/`, `README.md`, or any
  task/spec tree the repo uses).
- What the user confirms is worth publishing (durable design and reference
  docs; not working notes or ephemeral task files).

`publish-doc <name>` maps `<name>` to a repo doc the user identifies (or that
you propose from the repo's doc set). `publish-all` publishes every confirmed
durable doc in dependency order — foundational/architecture before specifics —
and reports a table of page → created/updated → URL.

## Authoring conventions

- **Author in Markdown.** Pass markdown to the MCP page-create/update tool;
  let Atlassian convert to storage format. Verify headings/tables/code render;
  fix only what breaks.
- **Plenty of links.** Cross-link sibling pages and link back to the repo doc
  for engineers. Plain-language intro paragraph at the top of every page for
  non-technical readers.
- **Diagrams:**
  - Prefer the repo's existing `.svg` files — upload as page attachments and
    embed.
  - If the repo has `.mmd` Mermaid sources, render/update them with the Mermaid
    MCP (`mcp__plugin_claude-mermaid_mermaid__mermaid_save` /
    `mcp__claude_ai_Mermaid_Chart__validate_and_render_mermaid_diagram`) when a
    diagram is stale or missing, then attach.
  - When a doc has no diagram and would benefit, generate a small Mermaid
    diagram, render to SVG/PNG, attach + embed. Keep diagrams simple.
- **Idempotent:** search the space for the page title first; update in place if
  it exists, else create under the confirmed parent folder. Report the page URL.
- **Don't dump the whole repo doc.** Summarise for the reader, link to detail.
  Keep code blocks short; long listings stay in the repo.

## What NOT to publish

Internal/ephemeral docs stay in the repo: handoff notes, bug logs, numbered
task/iteration files (link to GitHub or summarise in an overview page instead).
Publish the durable design and reference docs, not the working notes.
