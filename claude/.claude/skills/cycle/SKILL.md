---
name: cycle
description: Incremental plan-and-execute loop for medium-to-small repos. Seeds a lightweight TODO/ index, then iterates — detail the next 1-2 tasks just-in-time, execute (TDD), checkpoint the index, adjust, repeat. --spawn fans out independent tasks concurrently in git worktrees (auto-sized from the task graph, default cap 3). Unlike /blueprint, planning is rolling — no big upfront research phase. e.g. /cycle "add user preferences API", /cycle (continue next), /cycle 03 (specific task), /cycle --adjust (replan only), /cycle --spawn (concurrent fan-out in worktrees).
---

## Help

If `$ARGUMENTS` is exactly `--help`, `help`, or `-h`, print the block below
verbatim and **stop — do not execute the skill**.

```
/cycle — rolling plan-and-execute loop with a lightweight TODO/ index

  /cycle "goal"                  seed a new cycle
  /cycle                         continue next ready task
  /cycle NN                      work on task NN
  /cycle --adjust                replan only, no execution
  /cycle --spawn [N]             fan out concurrent tasks in worktrees
  /cycle --help                  show this help
```

---

# Cycle (`/cycle`)

Incremental plan-and-execute loop. The **head model** (this session) owns the
plan, sequences work, and runs git (approval-gated). Planning is **rolling** —
detail just enough to execute the next slice, learn from it, adjust the
roadmap, repeat. Designed for medium-to-small repos where a full `/blueprint`
research phase is overkill.

All repo rules — `CLAUDE.md`, git policy, TDD — apply. This skill sequences
them; it never relaxes them.

## Syntax

```
/cycle ["goal"]              # seed a new TODO/ and start the first task
/cycle                       # continue: detail + execute the next ready task
/cycle NN                    # work on a specific task
/cycle --adjust              # review and adjust the plan — no execution
/cycle --spawn [N]           # fan out up to N concurrent tasks in worktrees (auto-sized if omitted)
```

- **`"goal"`** — seeds a new cycle. Required on first invocation.
- **(none)** — pick up where the last session left off (reads `HANDOFF.md` and
  `TODO/README.md`).
- **`NN`** — jump to task NN.
- **`--adjust`** — replan only: review progress, reorder, resize, add/drop
  tasks, update the index. No implementation.
- **`--spawn [N]`** — concurrent fan-out: detail the next batch of independent
  tasks, create a git worktree + tmux window for each, and let them execute in
  parallel. `N` is a hard cap; if omitted, the head determines the right
  concurrency from the task graph (default cap 3).

## Model tiers

| Role | Model | Job |
|------|-------|-----|
| Head | session model | Plan, sequence, review, own git and TODO/. |
| Implementation worker | `model: "opus"` | Execute one sub-task: red → green → refactor. |
| Lookups | default | Greps, quick doc checks. |

Every `Agent()` call passes `model:` explicitly. **Never spawn Fable
subagents.**

## Phase 0 — Seed (first invocation with a goal)

Only runs when `TODO/` does not exist.

1. Read the repo's `CLAUDE.md` and any docs it references. Quick scan of the
   codebase structure (tree, key files). This is lighter than `/blueprint` —
   no parallel research workers unless a genuine unknown blocks decomposition.
2. State the goal in one sentence.
3. Decompose into a **rough ordered task list** — title + size estimate
   (`~S` ≤100 lines, `~M` ~100-300, `~L` ~300-500) per task. Don't flesh out
   sub-tasks yet — that happens just-in-time in phase 1.
4. **Checkpoint:** show the task list, get one OK.
5. Write `TODO/README.md` (the index — format below). No `taskNN-*.md` files
   yet. Offer a commit of `TODO/` per git policy.
6. Fall through to phase 1 for the first task.

**Guard:** if `TODO/` exists and a goal string was passed, stop and ask:

> `TODO/` already exists. Use `--adjust` to modify the plan, or confirm
> overwrite.

### `TODO/README.md` format

```markdown
# Cycle: <goal — one line>

## Tasks

| # | Slug | Est | Status | Notes |
|---|------|-----|--------|-------|
| 01 | <kebab> | ~M | [ ] | |
| 02 | <kebab> | ~S | [ ] | depends on 01 |
| ...

## Refs
- Test command: `<repo's test cmd with bug-surfacing flags>`
- Build/lint: `<cmd>`
- Key files: <list of load-bearing paths discovered during seed>

## Adjustments log
<!-- one line per change: date, what changed, why -->
```

The **adjustments log** is append-only — it's how the next session (or you
after `/clear`) understands why the plan drifted.

## Phase 1 — Detail (each iteration)

Flesh out the **next 1-2 ready tasks** (status `[ ]`, deps satisfied) into
`TODO/taskNN-<slug>.md`. Same format as `/blueprint` task files:

```markdown
# taskNN: <slug>

**Goal:** <one sentence>  **Branch:** <type>/<kebab>  **Deps:** <ids or none>

## Sub-tasks
- [ ] 1. <behavior> — test: <what the failing test proves>; files: <list>
- [ ] 2. ...

## Verify
<exact commands>

## Done when
<observable acceptance criteria>
```

Verify names by grepping the codebase — never plan on assumed names. Only
detail what you're about to execute; the rest stays as titles in the index.

## Phase 2 — Execute

For each sub-task, in order (same TDD loop as `/build`):

1. **Branch** — if not already on a feature branch, propose
   `git switch -c <type>/<kebab>` (approval-gated). Never work on the default
   branch.
2. **Red** — write the failing test; run it; show the failure for the right
   reason.
3. **Green** — minimum code to pass; run; show green.
4. **Refactor** — with tests green.
5. **Commit** — re-verify branch + cwd; propose the atomic commit
   (approval-gated). Tick the sub-task box in the task file; fold that edit
   into the same commit.

For larger sub-tasks, delegate to an implementation worker (`model: "opus"`)
with a self-contained brief. Review the diff before committing. Rework via
`SendMessage` — don't respawn.

## Phase 3 — Checkpoint

After completing a task (or when context budget requires it):

1. Update `TODO/README.md`:
   - Mark the task `[x]` (or `[~]` if partially done).
   - **Adjust the plan** — what did you learn? Reorder, resize, add, drop, or
     split remaining tasks. Append a line to the adjustments log.
   - Re-estimate remaining work.
2. Run the task's verify commands; show green.
3. Offer push + `gh pr create` per the repo's git policy (exact commands,
   wait for approval, never merge).
4. **Decision point** — propose one of:
   - **Continue** — context budget allows; fall through to phase 1 for the
     next task.
   - **Handoff** — context is getting heavy (>10%) or natural stopping point.
     Invoke the **`handoff`** skill. Recommend `/clear` then `/cycle` to
     resume.
   - **Spawn** — multiple independent tasks are ready. Suggest
     `/cycle --spawn` to fan them out concurrently in worktrees.

Do not silently roll into the next task — always checkpoint and propose
the next action.

## `--adjust` flow

Skip phases 1-2. Instead:

1. Read `TODO/README.md`, all existing task files, and `HANDOFF.md`.
2. Review progress: what's done, what's in flight, what's remaining.
3. Propose changes to the plan — reorder, resize, add, drop, split, merge.
   Show the diff to the index. One OK, then apply.
4. Append to the adjustments log.

## `--spawn` flow (concurrent fan-out)

The head session stays in the main worktree, plans the batch, creates
worktrees, and spawns sessions. Each spawned session is self-contained: it
executes its task, pushes its branch, offers a PR, and writes a per-worktree
`HANDOFF.md`.

### Step 1 — Size the batch

Analyze `TODO/README.md` to determine concurrency:

1. **Identify ready tasks** — status `[ ]`, all deps `[x]`.
2. **Filter for independence** — two tasks are independent if:
   - No explicit dep between them.
   - Their file lists (from the task index or quick grep) don't overlap.
   Tasks that touch the same files go in separate batches, even without
   explicit deps.
3. **Pick batch size** — `min(independent_ready_count, cap)`.
   - Cap = N if the user passed `--spawn N`, else **3**.
   - Size heuristic: for `~L` tasks, prefer fewer (2); for `~S`, allow more.
4. **Report the decision** before acting:
   `Spawning K sessions: tasks 02, 04, 05. Tasks 03, 06 deferred (deps / file overlap).`
   Wait for one OK.

### Step 2 — Detail the batch

Run phase 1 for each task in the batch — write all `TODO/taskNN-*.md` files.
Offer a commit of `TODO/` (approval-gated) so the worktrees branch from a
state that includes the task files.

### Step 3 — Create worktrees

For each task in the batch:

```bash
git worktree add ../$(basename "$PWD")-taskNN-<slug> -b <type>/<slug>
```

This branches from the current HEAD (which includes the committed TODO/).
Verify each worktree was created.

### Step 4 — Spawn sessions

For each task, invoke one `tmux new-window` (same pattern as the **`spawn`**
skill) pointed at the worktree directory:

```bash
tmux new-window -P -F '#{session_name}:#{window_index}' \
  -n "t<NN>" -c "<worktree-path>" \
  "claude --model <model-id> '<seed-prompt>'"
```

**Seed prompt** for each spawned session:

```
Read TODO/taskNN-<slug>.md — execute all sub-tasks (TDD, approval-gated
commits). When done: push the branch, offer gh pr create, then write
HANDOFF.md with what landed and any surprises. Context budget: 15% nudge,
never exceed 20%.
```

Confirm all windows are alive (same verification as `/spawn`).

### Step 5 — Head handoff

After all sessions are launched, the head writes/refreshes `HANDOFF.md` in
the **main worktree** noting:

- Which tasks are in flight (task ids, branches, worktree paths, tmux targets).
- Which tasks remain unstarted.
- How to reconvene: `Run /cycle --adjust to reconcile after the batch lands.`

Then stop. The head does not execute tasks itself during a `--spawn` — it
plans, spawns, and gets out of the way.

### Reconvene (next `/cycle` or `/cycle --adjust`)

When the user returns after a spawn batch:

1. Check each worktree's state: branch pushed? PR open? `HANDOFF.md` present?
2. For completed tasks, update `TODO/README.md` → `[x]`, note PR numbers.
3. Clean up worktrees: `git worktree remove <path>` for completed ones
   (approval-gated).
4. Adjust the plan based on what was learned, then continue — either
   interactively or with another `--spawn` for the next independent batch.

## Context budget

- Working budget is **15% context used** (`ctx-handoff-nudge` Stop hook is
  authoritative).
- From ~10%, gauge runway: don't start a sub-task you can't land inside 15%.
- At 15%: land the current atomic unit if within reach, checkpoint (phase 3),
  then invoke **`handoff`**. HANDOFF.md must pin: branch, task/sub-task
  position, what was learned, plan adjustments made.
- **Never exceed 20%.** A checkpoint with a good handoff beats a finished
  task with none.

## When NOT to use

- Large project with many unknowns requiring deep upfront research —
  `/blueprint` then `/build`.
- Single-PR-sized work — `/slice`.
- Architecture decisions — `/delib` first, feed the result into `/cycle`.
- Already have a full `TODO/` from `/blueprint` — use `/build`.
