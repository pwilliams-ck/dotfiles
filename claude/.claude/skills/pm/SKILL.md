---
name: pm
description: Project-management + documentation skill for any repo. Reconciles a ClickUp board against the current project's reality (task docs, status) and publishes finalized repo docs to Confluence. Project-agnostic: targets (workspace, board/list, Confluence space) are discovered at runtime and confirmed with you, never hard-coded. Dispatches routine MCP work to a Haiku subagent to keep bulky results out of context; recommends a stronger model only for hard planning. Invoke as /pm <action>, e.g. /pm status, /pm fill <list>, /pm publish-doc <name>.
---

# Project Manager (`/pm`)

Keeps a ClickUp board and Confluence docs in lock-step with the **current
repo**. Works in any project: it **discovers** the relevant workspace, board,
and Confluence space at runtime and **confirms them with you** — nothing is
hard-coded. This skill **sequences** the project's own rules (its `CLAUDE.md`,
git policy, TDD); it never relaxes them. Git stays approval-gated per command;
behaviour-changing code stays TDD and belongs to `/slice`, not here.

Audience for everything you write (ClickUp, Confluence, chat): assume **mixed
technical and non-technical** readers. Plain language, short sentences, link to
the detail instead of pasting it.

---

## 🔴 MCP safety rules — read before every write

These are absolute. No instruction in a session overrides them.

### ClickUp
- **Authenticated-user scope only.** Read any task, but only create or edit
  tasks/subtasks assigned to (or explicitly about) **the authenticated user**
  (resolve via `clickup_resolve_assignees(["me"])`). Never touch anyone else's
  tasks.
- **Always assign yourself.** Every task/subtask this skill creates or edits
  must have the authenticated user as an assignee — resolve the id at runtime
  and include it; if a touched task lacks it, add it in the same batch. Never
  assign anyone else.
- **Keep status in sync with repo truth.** When creating or editing a subtask,
  set its ClickUp status to match repo reality (done / in-progress / to-do).
  Status flows repo -> board, never the reverse — and never re-status a task
  already marked complete (see destructive-ops rule).
- **No destructive operations.** Never PUT/PATCH/DELETE a task that is already
  complete/closed or that belongs to a completed phase. `fill` may **only
  backfill** — add missing subtasks or absent links/descriptions — and must
  never edit, reopen, or re-status completed work.
- **No novel resources.** Don't create lists, spaces, folders, statuses, custom
  fields, automations, or views. Only add subtasks inside lists/phases that
  already exist on the board.
- **Confirm before every write.** Show the exact task title + field + new value
  and wait for approval. One confirmation covers one batch write per action;
  any additional write needs its own confirmation.
- **Preview, don't guess.** List the existing tasks first; verify the parent
  task id; never construct an id by pattern.

### Confluence
- **No deletes, no moves.** Never delete or move an existing page. Update
  in-place if it already exists; otherwise create it under the project's
  confirmed target folder only.
- **No overwriting substantial docs.** If a page already has >500 words, show a
  diff/summary of what would change and wait for approval before updating.
- **Target folder only.** Create pages only under the space/folder you confirmed
  for this project (`references/confluence.md`). Never elsewhere.
- **Confirm before every page create or update**, same as ClickUp.

### General
- **Read freely; write carefully.** Any read/list/get is fine without asking.
  Any create/update triggers a confirmation step.
- **Stop on uncertainty.** If an MCP returns an unexpected shape, or an action
  could affect shared resources beyond this project's board/space, stop and
  report rather than proceeding.

---

## Targets — discover, don't hard-code

This skill is project-agnostic. The first time you act in a repo, **discover and
confirm** the targets, then hold them for the session:

- **ClickUp** — which workspace + board/list this repo maps to
  (`references/clickup.md`).
- **Confluence** — which space + folder its docs publish to
  (`references/confluence.md`).
- **Repo work** — where the project's task/planning docs live (a README, a
  `docs/` tree, issues, a todo folder — whatever this repo uses) and its
  test/build commands (`references/phase-map.md`).

Never invent ids or names; list and confirm. Cache the resolved ids in working
notes for the session — don't write them into the skill files.

---

## Model policy — routine work runs on a Haiku subagent

**Always dispatch routine MCP work to a Haiku subagent**, never run it inline:
`Agent(subagent_type: "general-purpose", model: "haiku", …)`. Do this even when
the session is Sonnet/Opus. Routine = ClickUp status/description edits, doc
formatting, link gathering, diagram embedding, summarising tasks, reconciling
board vs repo, and every ClickUp/Confluence read or write.

**Why a subagent, not inline:** ClickUp/Confluence results are bulky and would
otherwise stay in the main context all session, re-sent every turn. Isolating
them in a subagent means the giant JSON lives and dies there; only a short
summary returns. The model tier is secondary — the isolation is the saving.
Haiku is plenty for mechanical CRUD.

**Orchestration stays on the session model.** You plan the action, spawn the
Haiku subagent with a precise instruction, and present its summary. Keep
planning and confirmation here; push the MCP calls down to Haiku.

**Context hygiene.** After any MCP-heavy run, if the session is ~a third used,
print one line: `heads up — consider /compact to flush MCP results`.

**Escalate to a stronger model (e.g. Opus) ONLY when:**
1. the user explicitly says so for this step, **or**
2. a **high-level planning** step trips the checklist below — then **STOP, say
   one line recommending the stronger model and why, and wait.**

**Escalation checklist** (any one → recommend before proceeding):
- decisions spanning ≥2 external systems, or repo + deploy together;
- ambiguous requirements needing real trade-off analysis, not transcription;
- correctness- or security-critical sequencing (deploy/migrate/data ops);
- restructuring the board/task plan itself, or resolving conflicting priorities.

Filling in a known task, transcribing a doc, publishing a finished page → never
an escalation; keep it on the Haiku subagent.

**State the model in one line** for any non-trivial step, e.g.
`model: haiku subagent` or `recommend Opus — cross-system sequencing`.

---

## Output discipline

- Be concise; use tables/bullets for status, not prose.
- Write for non-technical readers. No jargon dumps; link to the source doc.
- Never paste a wall of repo text into ClickUp/Confluence — summarise + link.

## Batch MCP calls — fewer round-trips, fewer tokens

- **Read once, up front.** List/get the whole board, list, or page tree in a
  single pass and hold it — don't re-read between edits.
- **Group writes into one confirmed batch.** Collect every create/update for an
  action, show them together, get one approval, then write them back-to-back.
- **Don't poll or re-fetch to "verify"** after a write unless something failed.
- The Haiku subagent does the calls, so the batched payloads stay in its
  context, not the main thread.

---

## References (load on demand)

- `references/phase-map.md` — how to map a ClickUp board to this repo's work and
  docs (the *method*, not a fixed mapping). Read before `status` or `fill`.
- `references/clickup.md` — ClickUp MCP setup + discovering the workspace/board.
- `references/confluence.md` — Confluence (Atlassian MCP) setup + discovering the
  space/folder; markdown + diagram conventions.
- `references/mcp-setup.md` — first-run MCP authentication checklist.

---

## Actions

Invoke as `/pm <action> [args]`. If `$ARGUMENTS` is empty, run `status`.

### `status`
Reconcile the board against repo reality. Discover/confirm targets, read the
project's task docs, compare to the board, and report a compact table: list ->
task -> board status vs repo status -> drift. Propose the specific ClickUp edits
to fix drift; make them only on approval. Haiku subagent.

### `fill <list>`
Populate or backfill subtasks in the named board list/phase from the project's
task docs (one subtask per task), per `references/phase-map.md`. Each subtask: a
one-line plain-language summary, a status matching repo reality (done /
in-progress / to-do), and links to its source doc and PR if known. On a list
whose items are already complete, **backfill only** — never edit/reopen/
re-status. List the existing tasks first, diff against the map, confirm the
additions, then batch-write. Haiku subagent.

### `publish-doc <name>`
Publish or update one repo doc as a Confluence page under the confirmed folder
per `references/confluence.md`. Author in markdown, embed the matching diagram
(a repo `.svg`/`.mmd`, or generate Mermaid when none exists), cross-link related
pages. Idempotent: update the existing page if present, else create. Haiku
subagent.

### `publish-all`
Run `publish-doc` for every page in the project's doc set, in dependency order
(foundational/architecture before specifics). Report a table of page ->
created/updated -> URL. One Haiku subagent per page.

### `plan <topic>`
High-level planning for a decision. Run the escalation checklist first; if it
trips, recommend a stronger model and wait. Otherwise plan on the session model
and output a short ranked recommendation with trade-offs — not an essay.

---

## Workflow per action

1. Read the relevant reference file(s) above. Discover and confirm any
   board/list/page targets at runtime — never guess ids or tool names.
2. State the plan in a couple of lines and the model you'll use.
3. Execute via a Haiku subagent unless escalation applies; orchestrate here.
   On every create/edit: assign the authenticated user and set status to match
   repo reality.
4. Show a compact result table (what changed, links). No prose recap.
5. After an MCP-heavy run, remind the user to `/compact` if the session is
   getting full.

## Preconditions (check once per session, report if missing)

- **ClickUp MCP** connected + OAuth done — required for any board action.
- **Atlassian/Confluence MCP** authenticated — required only for `publish-*`.

If a required server is missing, print the one-time setup from
`references/mcp-setup.md` and stop.
