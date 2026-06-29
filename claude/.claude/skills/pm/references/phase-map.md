# Phase map — method for mapping a ClickUp board to repo work

Read before `status` and `fill`. This file describes **how** to discover and
map a board to the current project; it contains no fixed names, phases, or paths.

---

## Step 1 — Discover the board's structure

Run `clickup_get_workspace_hierarchy` (or the equivalent list/folder read) to
enumerate every **list** and **status** the board actually has. Do not assume
any particular phase names. Confirm with the user which list is the active one
for this project before proceeding.

---

## Step 2 — Map each list/phase to repo work

For each list on the board, identify what kind of work it tracks by reading the
project's planning docs — whatever the repo uses: a `README`, a `docs/` tree, a
`todo/` folder, GitHub issues, a flat spec file, etc. Ask the user to point you
there if it is not obvious from the repo layout.

Build a working map of the form:

| Board list/phase | Typical meaning | Where tracked in this repo |
| ---------------- | --------------- | -------------------------- |
| (discovered)     | (inferred)      | (confirmed with user)      |

Do not write this table into any file — hold it in working notes for the session.

---

## Step 3 — Status flows repo → board, never the reverse

The repo (its task docs, PRs, README, or whatever the project uses as its
source of truth) is authoritative for build status. When reconciling:

1. Read the repo's task docs to determine the true state of each piece of work
   (done / in progress / to do).
2. Compare that to the board's current status for the matching subtask.
3. Propose edits to bring the board into alignment — never update the repo to
   match the board.

**Never re-status a task the board already marks complete.**

---

## Step 4 — Subtask shape

Each subtask on the board should have:

- **Title:** a one-line plain-language summary (non-engineers can read it).
- **Status:** matching repo reality — done / in-progress / to-do.
- **Description (template):**

  > **What:** one sentence a non-engineer understands.
  > **Status:** done / in progress / to do.
  > **Detail:** [source doc](link) · [PR #NN](link if known) · [Confluence](link if published).

Fill in only what is known; omit fields that are genuinely absent rather than
guessing.

---

## Step 5 — Link board items to Confluence pages

When a Confluence page exists for a task or phase, add its URL to the subtask
description. When publishing a new page (via `publish-doc`), update the
matching subtask description with the page link in the same action — confirm
both writes together in one batch.

---

## Rules

- **Never invent dates.** Pull due/start dates from ClickUp; set them only if
  the user provides them.
- **Backfill only on completed lists.** If a list/phase is already marked done,
  only add missing subtasks or absent links — never edit, reopen, or re-status
  existing complete items.
- **No novel board resources.** Don't create lists, spaces, folders, statuses,
  or custom fields. Only add subtasks inside lists/phases that already exist.
- **Confirm before every write.** Show exact title + field + new value and wait
  for approval. One confirmation covers one batch write per action.
- **Merges, tags, and production deploys are always human-only.** The skill may
  update a ClickUp card to reflect that a deploy is pending, but never triggers
  the deploy itself.
