---
name: cycle
description: Incremental plan-and-execute loop for medium-to-small repos. Seeds a lightweight TODO/ index, then iterates — detail the next 1-2 tasks just-in-time, execute, checkpoint the index, adjust, repeat. --spawn fans out independent tasks concurrently in git worktrees (auto-sized from the task graph, default cap 3). Unlike /blueprint, planning is rolling — no big upfront research phase. e.g. /cycle "add user preferences API", /cycle (continue next), /cycle 03 (specific task), /cycle --adjust (replan only), /cycle --spawn (concurrent fan-out in worktrees).
---

## Help

If `$ARGUMENTS` is exactly `--help`, `help`, or `-h`, print the block below
verbatim and **stop — do not execute the skill**.

```
/cycle — rolling plan-and-execute loop with a lightweight TODO/ index

  Incremental plan-and-execute loop for medium-to-small repos. Seeds a
  lightweight TODO/ index, then iterates — detail the next 1-2 tasks
  just-in-time, execute, checkpoint the index, adjust, repeat.
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

All repo rules — `CLAUDE.md`, git policy — apply. This skill sequences them;
it never relaxes them.

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
| Implementation worker | `model: "opus"` | Execute one sub-task: implement + test. |
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

For each sub-task:

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
spawns sessions, then **supervises**: reviews each worker's work as it reports
in, and sends rework back down. It does **not** execute tasks during a spawn.

1. **Size the batch.** Ready tasks (`[ ]`, deps `[x]`) that are mutually
   independent — no explicit dep *and* no file-list overlap (tasks touching the
   same files go in separate batches). Batch = `min(independent_ready, cap)`;
   cap = N or 3; prefer fewer for `~L`, more for `~S`. Report the pick
   (`Spawning 3: tasks 02,04,05; deferred 03,06 (deps/overlap)`) and get one OK.
2. **Detail the batch.** Phase 1 for each task; commit `TODO/` (approval-gated)
   so worktrees branch from a state that includes the task files.
3. **Create worktrees** from current HEAD, one per task, and verify each:
   `git worktree add ../$(basename "$PWD")-taskNN-<slug> -b <type>/<slug>`
4. **Spawn sessions** — all workers go in **one new tmux window, one pane
   each**, so the user can watch and answer every prompt without switching
   windows. Requires `$TMUX`; if unset, stop and say so. Use the exact model id
   this session runs on. Seed prompt per worker:
   > Read TODO/taskNN-<slug>.md — execute all sub-tasks (approval-gated
   > commits). When done: push, offer gh pr create, write HANDOFF.md with what
   > landed and any surprises. Then report to the supervisor — write
   > `TODO/reports/taskNN.md` in the MAIN worktree at `<main-path>` (branch,
   > commits, files touched, verify commands + their output, surprises, PR
   > number if opened), and only once it is fully written and closed:
   > `touch <main-path>/TODO/reports/taskNN.done`. If the supervisor sends
   > rework, address it and re-report the same way (overwrite both files).
   > Context budget: 15% nudge, never exceed 20%.

   First worker creates the window, the rest split it:

   ```bash
   git_allow="--allowedTools 'Bash(git add:*)' --allowedTools 'Bash(git commit:*)'"
   win=$(tmux new-window -P -F '#{window_id}' -n cycle -c <worktree-1> \
     "claude --model <model-id> $git_allow '<seed 1>'")
   tmux split-window -t "$win" -c <worktree-2> "claude --model <model-id> $git_allow '<seed 2>'"
   tmux split-window -t "$win" -c <worktree-3> "claude --model <model-id> $git_allow '<seed 3>'"
   ```

   **Layout — pick from the window's actual width, don't hardcode:**

   ```bash
   w=$(tmux display-message -t "$win" -p '#{window_width}')
   [ "$w" -ge $((80 * N)) ] \
     && tmux select-layout -t "$win" even-horizontal \
     || tmux select-layout -t "$win" even-vertical
   ```

   Each worker needs ~80 cols to be readable. Wide enough (external 27" ≈ 255
   cols) → `even-horizontal`, N equal side-by-side columns. Narrower (14" laptop
   ≈ 151 cols) → `even-vertical`, N equal full-width rows stacked top to bottom.
   Both layouts are equally spaced by construction.

   - Escape single quotes in each seed prompt (`'` → `'\''`) before embedding.
   - Title each pane so the user can tell them apart:
     `tmux select-pane -t <pane> -T taskNN-<slug>`.
   - Confirm with `tmux list-panes -t "$win" -F '#{pane_id} #{pane_title}
     #{pane_current_path}'` — N panes, right worktrees, all alive (a failed
     `claude` launch closes its pane immediately). Keep the
     **task → pane_id → worktree → branch** mapping; supervision needs it.
     Report it to the user; remind them of `prefix + z` to zoom a pane and
     `prefix + E` to re-equalize.
5. **Write the interim handoff** — before arming supervision, refresh
   main-worktree `HANDOFF.md`: in-flight tasks (ids, branches, worktree paths,
   pane ids), unstarted tasks, and `Run /cycle --adjust to reconcile after the
   batch lands.` This is the safety net if the head dies mid-batch.
6. **Arm supervision** — `mkdir -p TODO/reports`, then one persistent `Monitor`
   that emits a line per finished worker *and* per worker that dies without
   reporting (silence must not look like success):

   ```bash
   cd <main-worktree>; seen=""
   while true; do
     for f in TODO/reports/*.done; do
       [ -e "$f" ] || continue
       t=$(basename "$f" .done)
       case " $seen " in *" $t "*) continue ;; esac
       seen="$seen $t"; echo "REPORT $t"
     done
     live=$(tmux list-panes -t "$win" -F '#{pane_title}' 2>/dev/null)
     for t in <taskNN list>; do
       case " $seen " in *" $t "*) continue ;; esac
       case "$live" in *"$t"*) continue ;; esac
       seen="$seen $t"; echo "PANE GONE $t — died without reporting"
     done
     [ $(echo $seen | wc -w) -ge N ] && { echo "BATCH COMPLETE"; break; }
     sleep 20
   done
   ```

   Then tell the user supervision is live and **stay resident** — do not
   `/clear` and do not stop; each event re-invokes the head.

**On each `REPORT taskNN`** (auto-review):

1. Read `TODO/reports/taskNN.md`, then delegate the diff read to a
   `feature-dev:code-reviewer` agent (`run_in_background: false`) pointed at the
   worktree with `git diff <base>...<branch>` and the task file as the spec —
   **the diff must land in the reviewer's context, not the head's**, or three
   reviews will blow the 15% budget.
2. Re-run the task's verify commands in that worktree; trust the output over the
   report's claims.
3. Verdict, reported to the user either way:
   - **Pass** → tick `[x]` in `TODO/README.md` with the PR number.
   - **Rework** → send it to the worker, which still holds full context:
     `tmux send-keys -t <pane_id> '<specific rework instructions>' Enter`
     (escape quotes; one send per pane, never interleave). Mark `[~]` and wait
     for the re-report. If the pane is gone, take the task over in the head only
     if budget allows — otherwise leave `[~]` with the reason.

**On `PANE GONE`** — inspect the worktree (`git log`, `git status`, its
`HANDOFF.md`); record what landed, mark `[~]` with a concrete next step.

**On `BATCH COMPLETE`** — final checkpoint: reconcile `TODO/README.md`, offer
`git worktree remove` for passed tasks (approval-gated), then adjust and either
spawn the next batch or hand off.

Supervision is **post-commit**: worker commits are approval-gated to the user in
their own pane, so the head reviews what already landed and drives rework — it
never gates a worker's commit. `TODO/reports/` is scratch; don't commit it.

**Reconvene** (if the head *did* die, next `/cycle` or `--adjust`): read
`TODO/reports/`, check each worktree (branch pushed? PR open? HANDOFF.md?), mark
completed tasks `[x]` with PR numbers, `git worktree remove` completed ones
(approval-gated), adjust, and continue or spawn the next batch.

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
