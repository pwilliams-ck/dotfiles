---
name: cycle
description: Incremental plan-and-execute loop for medium-to-small repos. Seeds a lightweight TODO/ index, then iterates — detail the next 1-2 tasks just-in-time, execute (TDD), checkpoint the index, adjust, repeat. --spawn fans out independent tasks concurrently in git worktrees (auto-sized from the task graph, default cap 3). Unlike /blueprint, planning is rolling — no big upfront research phase. e.g. /cycle "add user preferences API", /cycle (continue next), /cycle 03 (specific task), /cycle --adjust (replan only), /cycle --spawn (concurrent fan-out in worktrees).
---

## Help

If `$ARGUMENTS` is exactly `--help`, `help`, or `-h`, print the block below
verbatim and **stop — do not execute the skill**.

```
/cycle — rolling plan-and-execute loop with a lightweight TODO/ index

  Incremental plan-and-execute loop for medium-to-small repos. Seeds a
  lightweight TODO/ index, then iterates — detail the next 1-2 tasks
  just-in-time, execute (TDD), checkpoint the index, adjust, repeat.
  --spawn fans out independent tasks concurrently in git worktrees
  (auto-sized from the task graph, default cap 3). Unlike /blueprint,
  planning is rolling — no big upfront research phase.

  /cycle "goal"                  seed a new cycle
  /cycle                         continue next ready task
  /cycle NN                      work on task NN
  /cycle --adjust                replan only, no execution
  /cycle --spawn [N]             fan out concurrent tasks in worktrees
  /cycle --help                  show this help

  See also:
    /cycle-issues  same workflow backed by GitHub issues
    /blueprint     heavier upfront planning alternative
    /handoff       invoked at end of session
```

---

# Cycle (`/cycle`)

Incremental plan-and-execute loop. The **head model** (this session) owns the
plan, sequences work, and runs git (approval-gated). Planning is **rolling** —
detail just enough to execute the next slice, learn, adjust, repeat. For
medium-to-small repos where a full `/blueprint` research phase is overkill.

All repo rules — `CLAUDE.md`, git policy, TDD — apply. This skill sequences
them; it never relaxes them.

## Syntax

```
/cycle ["goal"]   # seed a new TODO/ and start the first task (goal required first time)
/cycle            # continue: detail + execute the next ready task (reads HANDOFF.md + TODO/README.md)
/cycle NN         # jump to a specific task
/cycle --adjust   # replan only — reorder/resize/add/drop, no execution
/cycle --spawn [N]# fan out up to N independent tasks in worktrees (auto-sized if omitted, cap 3)
```

## Model tiers

| Role | Model | Job |
|------|-------|-----|
| Head | session model | Plan, sequence, review, own git and TODO/. |
| Implementation worker | `model: "opus"` | Execute one sub-task: red → green → refactor. |
| Lookups | default | Greps, quick doc checks. |

Every `Agent()` call passes `model:` explicitly. **Never spawn Fable subagents.**

## Phase 0 — Seed (first invocation with a goal)

Only when `TODO/` does not exist. (If it does and a goal was passed, stop and
ask: use `--adjust` to modify, or confirm overwrite.)

1. Read `CLAUDE.md` and docs it references; quick scan of repo structure.
   Lighter than `/blueprint` — no research workers unless a genuine unknown
   blocks decomposition.
2. State the goal in one sentence.
3. Decompose into a **rough ordered task list** — title + size (`~S` ≤100,
   `~M` 100-300, `~L` 300+ lines) per task — rough estimates, not caps. No
   sub-tasks yet (that's phase 1).
4. **Checkpoint:** show the list, get one OK.
5. Write `TODO/README.md` (index below) — no `taskNN-*.md` files yet. Offer a
   commit of `TODO/` per git policy. Fall through to phase 1.

### `TODO/README.md` format

A `# Cycle: <goal>` heading, a task table (`# | Slug | Est | Status | Notes`,
Notes carries deps), a **Refs** block (test command with bug-surfacing flags,
build/lint command, load-bearing files), and an append-only **Adjustments log**
(one line per change: what changed, why) — the record of why the plan drifted,
for the next session or a post-`/clear` you.

## Phase 1 — Detail (each iteration)

Flesh out the **next 1-2 ready tasks** (status `[ ]`, deps satisfied) into
`TODO/taskNN-<slug>.md` — same format as `/blueprint`:

```markdown
# taskNN: <slug>
**Goal:** <one sentence>  **Branch:** <type>/<kebab>  **Deps:** <ids or none>

## Sub-tasks
- [ ] 1. <behavior> — test: <what the failing test proves>; files: <list>

## Verify / done
<exact commands + observable acceptance criteria>
```

Grep the codebase to confirm names — never plan on assumed names. Detail only
what you're about to execute; the rest stays as titles in the index.

## Phase 2 — Execute

Follow the repo's TDD policy (red → green → refactor) for each sub-task, with:

- **Branch first** — if not on a feature branch, propose `git switch -c
  <type>/<kebab>` (approval-gated). Never work on the default branch.
- **Commit per sub-task** — re-verify branch + cwd, propose the atomic commit
  (approval-gated); tick the sub-task box in the same commit.

For larger sub-tasks, delegate to an implementation worker (`model: "opus"`)
with a self-contained brief; review the diff before committing; rework via
`SendMessage`, don't respawn.

## Phase 3 — Checkpoint

After a task completes (or when context budget requires):

1. Update `TODO/README.md`: mark `[x]` (or `[~]` if partial); **adjust the
   plan** from what you learned (reorder/resize/add/drop/split), append to the
   adjustments log; re-estimate remaining work.
2. Run the task's verify commands; show green.
3. Offer push + `gh pr create` per git policy (exact commands, wait, never merge).
4. **Decision point** — propose one, never silently roll on:
   - **Continue** — budget allows → back to phase 1.
   - **Handoff** — context heavy (>10%) or natural stop → invoke `handoff`,
     recommend `/clear` then `/cycle`.
   - **Spawn** — several independent tasks ready → suggest `/cycle --spawn`.

## `--adjust` flow

Skip phases 1-2: read `TODO/README.md`, task files, and `HANDOFF.md`; review
done / in-flight / remaining; propose plan changes (reorder/resize/add/drop/
split/merge), show the index diff, one OK, apply; append to the adjustments log.

## `--spawn` flow (concurrent fan-out)

The head stays in the main worktree — it plans the batch, creates worktrees,
spawns sessions, then gets out of the way. It does **not** execute tasks during
a spawn.

1. **Size the batch.** Ready tasks (`[ ]`, deps `[x]`) that are mutually
   independent — no explicit dep *and* no file-list overlap (tasks touching the
   same files go in separate batches). Batch = `min(independent_ready, cap)`;
   cap = N or 3; prefer fewer for `~L`, more for `~S`. Report the pick
   (`Spawning 3: tasks 02,04,05; deferred 03,06 (deps/overlap)`) and get one OK.
2. **Detail the batch.** Phase 1 for each task; commit `TODO/` (approval-gated)
   so worktrees branch from a state that includes the task files.
3. **Create worktrees** from current HEAD, one per task, and verify each:
   `git worktree add ../$(basename "$PWD")-taskNN-<slug> -b <type>/<slug>`
4. **Spawn sessions** — one `tmux new-window` per worktree using the `/spawn`
   skill's pattern (`-c <worktree-path>`, same model id), seeded with:
   > Read TODO/taskNN-<slug>.md — execute all sub-tasks (TDD, approval-gated
   > commits). When done: push, offer gh pr create, write HANDOFF.md with what
   > landed and any surprises. Context budget: 15% nudge, never exceed 20%.

   Confirm all windows are alive.
5. **Head handoff.** Refresh main-worktree `HANDOFF.md`: in-flight tasks (ids,
   branches, worktree paths, tmux targets), unstarted tasks, and
   `Run /cycle --adjust to reconcile after the batch lands.` Then stop.

**Reconvene** (next `/cycle` or `--adjust`): check each worktree (branch
pushed? PR open? HANDOFF.md?), mark completed tasks `[x]` with PR numbers, then
`git worktree remove` completed ones (approval-gated), adjust, and continue or
spawn the next batch.

## Context budget

Working budget is **15%** (`ctx-handoff-nudge` Stop hook is authoritative). From
~10%, don't start a sub-task you can't land inside 15%. At 15%, land the current
atomic unit if within reach, checkpoint (phase 3), invoke `handoff`. **Never
exceed 20%** — a checkpoint with a good handoff beats a finished task with none.

## When NOT to use

- Many unknowns needing deep upfront research → `/blueprint` then `/build`.
- Single-PR-sized work → `/slice`.
- Architecture decisions → `/delib` first, feed the result in.
- Already have a full `TODO/` from `/blueprint` → `/build`.
