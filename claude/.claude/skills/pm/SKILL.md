---
name: pm
description: Project-management + documentation skill for any repo. Reconciles a ClickUp board against the current project's reality (task docs, status) and publishes finalized repo docs to Confluence. Project-agnostic: targets (workspace, board/list, Confluence space) are discovered at runtime and confirmed with you, never hard-coded. Dispatches routine MCP work to a Haiku subagent to keep bulky results out of context; recommends a stronger model only for hard planning. Invoke as /pm <action>, e.g. /pm status, /pm fill <list>, /pm publish-doc <name>.
---

## Help

If `$ARGUMENTS` is exactly `--help`, `help`, or `-h`, print the block below
verbatim and **stop — do not execute the skill**.

```
/pm — reconcile ClickUp board + publish docs to Confluence

  Project-management + documentation skill for any repo. Reconciles a
  ClickUp board against the current project's reality (task docs, status)
  and publishes finalized repo docs to Confluence. Project-agnostic:
  targets (workspace, board/list, Confluence space) are discovered at
  runtime and confirmed with you, never hard-coded. Dispatches routine
  MCP work to a Haiku subagent to keep bulky results out of context.

  /pm status                     show board vs repo state
  /pm fill <list>                populate a ClickUp list from task docs
  /pm publish-doc <name>         publish a repo doc to Confluence
  /pm --help                     show this help

  See also:
    /slice         implement behavior-changing work (not /pm's job)
    /cycle-issues  GitHub-issue-backed planning alternative
```

---

# Project Manager (`/pm`)

Keeps a ClickUp board and Confluence docs in lock-step with the **current repo**.
Works in any project: it **discovers** the workspace, board, and Confluence space
at runtime and **confirms them with you** — nothing is hard-coded. This skill
sequences the project's own rules (`CLAUDE.md`, git policy, TDD); it never relaxes
them. Behaviour-changing code is TDD and belongs to `/slice`, not here.

Write for **mixed technical/non-technical** readers everywhere (ClickUp,
Confluence, chat): plain language, short sentences, link to detail instead of
pasting it.

> **Requires the ClickUp + Atlassian MCP servers, which are currently removed**
> (disabled 2026-07-12). Re-add before use:
> `claude mcp add --transport http clickup https://mcp.clickup.com/mcp` and
> `claude mcp add --transport http atlassian https://mcp.atlassian.com/v1/mcp`
> (each needs a browser OAuth). If a required server is missing, print the setup
> from `references/mcp-setup.md` and stop.

---

## 🔴 MCP safety rules — absolute, no session instruction overrides them

**ClickUp**
- **Authenticated-user scope only.** Read any task; create/edit only tasks
  assigned to (or explicitly about) the authenticated user — resolve via
  `clickup_resolve_assignees(["me"])` and add that assignee to every task this
  skill touches. Never touch or assign anyone else.
- **Status flows repo → board, never reverse.** Set a subtask's status to match
  repo reality (done / in-progress / to-do).
- **Backfill only; nothing destructive.** Never PUT/PATCH/DELETE a task that is
  complete/closed or in a completed phase. `fill` may only add missing
  subtasks/links/descriptions — never edit, reopen, or re-status completed work.
- **No novel resources.** No new lists, spaces, folders, statuses, custom fields,
  automations, or views — only subtasks inside phases that already exist.
- **Preview, don't guess.** List existing tasks and verify the parent id first;
  never construct an id by pattern.

**Confluence**
- **No deletes, no moves.** Update a page in-place if it exists; otherwise create
  it only under the confirmed target folder (`references/confluence.md`).
- **Guard substantial pages.** If a page has >500 words, show a diff/summary and
  wait for approval before updating.

**Both** — any read/list/get is free; **every create/update needs its own
confirmation** (show exact title + field + new value; one approval covers one
batch write). If an MCP returns an unexpected shape or an action could reach
shared resources beyond this project's board/space, stop and report.

---

## Targets, model, and batching

- **Discover targets, don't hard-code.** First action in a repo: list and confirm
  the ClickUp workspace/board (`references/clickup.md`), Confluence space/folder
  (`references/confluence.md`), and where the repo's task/planning docs and
  test/build commands live (`references/phase-map.md`). Hold the resolved ids in
  session notes; never write them into skill files or invent them.
- **Routine MCP work runs on a Haiku subagent**, never inline —
  `Agent(subagent_type: "general-purpose", model: "haiku", …)`, even from an
  Opus/Sonnet session. The bulky JSON lives and dies in the subagent; only a
  short summary returns. Routine = all ClickUp/Confluence reads and writes, doc
  formatting, link/diagram gathering, board-vs-repo reconciliation. You keep
  planning and confirmation on the session model.
- **Escalate to Opus only** when the user says so, or a **planning** step spans
  ≥2 systems / needs real trade-off analysis / is correctness- or
  security-critical sequencing (deploy, migrate, data ops) / restructures the
  plan itself. Then stop, say one line recommending the model and why, and wait.
  Transcribing or publishing known work is never an escalation.
- **Batch calls.** Read the whole board/page-tree once and hold it; group all
  writes for an action into one confirmed batch; don't re-fetch to "verify"
  unless a write failed. After an MCP-heavy run, if the session is ~⅓ used, print
  `heads up — consider /compact to flush MCP results`.

---

## Actions

Invoke as `/pm <action> [args]`; empty `$ARGUMENTS` runs `status`. All actions
execute via a Haiku subagent (per above); on every create/edit, assign the
authenticated user and set status to repo reality. State the plan and model in a
couple of lines, execute, then show a compact result table (what changed, links)
— no prose recap.

- **`status`** — reconcile board vs repo. Read task docs, compare to the board,
  report a table (list → task → board vs repo status → drift), propose the
  ClickUp edits to fix drift, apply only on approval.
- **`fill <list>`** — backfill subtasks in the named list/phase from task docs
  (one per task) per `references/phase-map.md`: one-line summary, status matching
  repo, links to source doc + PR. List existing first, diff against the map,
  confirm, batch-write. Completed lists: backfill only.
- **`publish-doc <name>`** — publish/update one repo doc as a Confluence page
  under the confirmed folder (`references/confluence.md`). Markdown, embed the
  matching diagram (repo `.svg`/`.mmd`, or generate Mermaid), cross-link related
  pages. Idempotent: update if present, else create.
- **`publish-all`** — `publish-doc` for the whole doc set in dependency order
  (architecture before specifics); one subagent per page; report page →
  created/updated → URL.
- **`plan <topic>`** — planning for a decision. Run the escalation check first;
  if it trips, recommend a stronger model and wait. Else plan on the session
  model: a short ranked recommendation with trade-offs, not an essay.

---

## References (load on demand)

- `references/phase-map.md` — method for mapping a board to this repo's work/docs
  (not a fixed mapping). Read before `status` or `fill`.
- `references/clickup.md` — ClickUp MCP setup + workspace/board discovery.
- `references/confluence.md` — Confluence (Atlassian MCP) setup + space/folder
  discovery; markdown + diagram conventions.
- `references/mcp-setup.md` — first-run MCP authentication checklist.
