---
name: cycle
description: Plan-and-execute loop for multi-task work in any repo. Seeds a lightweight TODO/ index, then iterates — detail the next 1-2 tasks just-in-time, execute, checkpoint the index, adjust, repeat. Planning is rolling: no big upfront research phase, so the plan is never further ahead of reality than the next task or two. Tasks declare the file globs they own; --spawn fans out tasks with disjoint ownership concurrently in git worktrees (auto-sized from the task graph, default cap 3). e.g. /cycle "add user preferences API", /cycle (continue next), /cycle 03 (specific task), /cycle --adjust (replan only), /cycle --spawn (concurrent fan-out in worktrees).
---

## Help

If `$ARGUMENTS` is exactly `--help`, `help`, or `-h`, print the block below
verbatim and **stop — do not execute the skill**.

```
/cycle — rolling plan-and-execute loop with a lightweight TODO/ index

  Plan-and-execute loop for multi-task work. Seeds a lightweight TODO/
  index, then iterates — detail the next 1-2 tasks just-in-time, execute,
  checkpoint the index, adjust, repeat. Planning is rolling, so the plan
  never runs further ahead of reality than a task or two. Tasks declare
  the file globs they own; --spawn fans out tasks with disjoint ownership
  concurrently in git worktrees (auto-sized, default cap 3).

  /cycle "goal"                  seed a new cycle
  /cycle                         continue next ready task
  /cycle NN                      work on task NN
  /cycle --adjust                replan only, no execution
  /cycle --spawn [N]             fan out concurrent tasks in worktrees
  /cycle --contest NN            one task, 3 agents: spec tests, two builds, winner by test count
  /cycle --help                  show this help

  See also:
    /cycle-issues  same workflow backed by GitHub issues
    /delib         settle an architecture question before planning
    /handoff       invoked at end of session
```

---

# Cycle (`/cycle`)

Plan-and-execute loop for multi-task work. The **head model** (this session) owns
the plan, sequences work, and runs git (approval-gated). Planning is **rolling** —
detail just enough to execute the next slice, learn, adjust, repeat. A plan
written far in advance of the work is a plan written before the facts; detailing
one task at a time keeps it answerable to what the last task taught.

All repo rules — `CLAUDE.md`, git policy — apply. This skill sequences them;
it never relaxes them.

## Syntax

```
/cycle ["goal"]   # seed a new TODO/ and start the first task (goal required first time)
/cycle            # continue: detail + execute the next ready task (reads TODO/README.md's Resume pointer + that task file's Handoff)
/cycle NN         # jump to a specific task
/cycle --adjust   # replan only — reorder/resize/add/drop, no execution
/cycle --spawn [N]# fan out up to N independent tasks in worktrees (auto-sized if omitted, cap 3)
/cycle --contest NN # competitive: spec agent writes tests, two workers implement task NN, winner by test count
```

## Model tiers

| Role | Model | Job |
|------|-------|-----|
| Head | session model | Plan, sequence, review, own git and TODO/. |
| Implementation worker | `claude-opus-4-6[1m]`, `--effort max` | Execute one sub-task in a tmux pane. |
| Lookups | default | Greps, quick doc checks via `Agent()`. |

Implementation workers run as `claude` CLI sessions in a split pane (see phase 2). Lookups use `Agent()` with default model. **Never spawn Fable subagents.**

## Phase 0 — Seed (first invocation with a goal)

Only when `TODO/` does not exist. (If it does and a goal was passed, stop and
ask: use `--adjust` to modify, or confirm overwrite.)

1. Read `CLAUDE.md` and docs it references; quick scan of repo structure. Keep
   this pass cheap — no research workers unless a genuine unknown blocks
   decomposition.
2. State the goal in one sentence.
3. Decompose into a **rough ordered task list** — per task: title, size (`~S`
   ≤100, `~M` 100-300, `~L` 300+ lines), and `Owns:` — the glob set that task
   is allowed to write. Rough estimates, not caps. No sub-tasks yet (that's
   phase 1).
4. **Seek seams.** Prefer a decomposition whose tasks own disjoint directories,
   even at the cost of one extra task — disjoint ownership is what makes
   `--spawn` safe, and discovering independence after the fact only ever finds
   unrelated scraps. Stop when the split stops being real: a task carved out
   for parallelism that then needs cross-task coordination (a shared signature,
   one migration, one task's output as another's input) is worse than one
   sequential task. Overlapping globs are legal — they just serialize.
5. **Checkpoint:** show the list, get one OK.
6. Write `TODO/README.md` (index below) — no `taskNN-*.md` files yet. Offer a
   commit of `TODO/` per git policy. Fall through to phase 1.

### `TODO/README.md` format

A `# Cycle: <goal>` heading, a `**Resume:**` line pointing at the task file
whose `## Handoff` holds live state (maintained by `/handoff`), a task table
(`# | Slug | Est | Owns | Status | Notes`, Owns carries the write-scope globs and
Notes carries deps), a **Refs** block (test command with bug-surfacing flags,
build/lint command, load-bearing files, links
to any `TODO/notes/*.md`), and an append-only **Adjustments log**
(one line per change: what changed, why) — the record of why the plan drifted,
for the next session or a post-`/clear` you.

## Phase 1 — Detail (each iteration)

Flesh out the **next 1-2 ready tasks** (status `[ ]`, deps satisfied) into
`TODO/taskNN-<slug>.md`, written for a **zero-context reader** — a fresh session
must be able to execute it without re-deriving the plan:

```markdown
# taskNN: <slug>
**Goal:** <one sentence>  **Branch:** <type>/<kebab>  **Deps:** <ids or none>
**Owns:** <write-scope globs>

## Sub-tasks
- [ ] 1. <behavior> — test: <what the failing test proves>; files: <list>

## Verify / done
<exact commands + observable acceptance criteria>

## Handoff

**Status:** NOT STARTED
```

The `## Handoff` stub is mandatory — `/handoff` replaces its body with live
state, and it is the first thing a zero-context session reads.

`Owns:` is the task's write scope: a file outside it is out of scope — record it
in the report or handoff, don't edit it. It is **advisory** — nothing enforces
it at write time, and the task file is the only copy, so a mid-batch replan
changes it for everyone reading. The review step asserts the diff against it.

Grep the codebase to confirm names — never plan on assumed names. Detail only
what you're about to execute; the rest stays as titles in the index.

## Phase 2 — Execute

For each sub-task:

- **Branch first** — if not on a feature branch, propose `git switch -c
  <type>/<kebab>` (approval-gated). Never work on the default branch.
- **Commit per sub-task** — re-verify branch + cwd, propose the atomic commit
  (approval-gated); tick the sub-task box in the same commit.

- **Amend on divergence** — a wrong name, a missing dep, a task twice its
  estimate: stop, propose the `TODO/` edit in ≤3 lines (`taskNN: <what changes
  and why>`), get one OK. Never deviate silently and leave `TODO/` stale.

For larger sub-tasks, spawn an implementation worker in a split pane — same mechanism as `--spawn` but for one task:

```bash
mkdir -p TODO/reports
pane=$(tmux split-window -P -F '#{pane_id}' -c "$PWD" \
  "claude --model 'claude-opus-4-6[1m]' --effort max")
```

Launch with **no positional prompt** and deliver the seed by tmux buffer, exactly as `--spawn` step 4 — a seed passed as a command argument is silently swallowed.

Brief the seed per `~/.claude/skills/implementer/SKILL.md` §5, scoped to the task's `Owns` globs. Instruct the worker to write `TODO/reports/taskNN.md` and `touch TODO/reports/taskNN.done` on completion. Monitor for `.done`, then review and rework per the `--spawn` flow's **On each `REPORT`** section. Rework goes via `tmux send-keys -t "$pane"`, not `SendMessage`.

## Phase 3 — Checkpoint

After a task completes (or when context budget requires):

1. Update `TODO/README.md`: mark `[x]` (or `[~]` if partial); **adjust the
   plan** from what you learned (reorder/resize/add/drop/split), append to the
   adjustments log; re-estimate remaining work.
2. Run the task's verify commands; show green. **Re-measure the test baseline
   here** — never copy the count out of the previous batch's handoff. Merged work
   adds tests, and a stale baseline seeded into workers sends them hunting
   regressions that are not theirs.
3. Offer push + `gh pr create` per git policy (exact commands, wait, never merge).
4. **Decision point** — route via `~/.claude/skills/shared/next-command.md`,
   then propose exactly one; never silently roll on:
   - **Continue** — budget allows and the routing names a single ready task →
     back to phase 1.
   - **Spawn** — the routing names `--spawn` and `$TMUX` is set → fan out.
   - **Handoff** — context heavy (>10%) or a natural stop → invoke `handoff`,
     which emits the `Next:` block for the fresh session.

## `--adjust` flow

Skip phases 1-2: read `TODO/README.md`, task files (their `## Handoff`
sections), and `ISSUES.md`; review
done / in-flight / remaining; propose plan changes (reorder/resize/add/drop/
split/merge), show the index diff, one OK, apply; append to the adjustments log.

## `--spawn` flow (concurrent fan-out)

The head stays in the main worktree — it plans the batch, creates worktrees,
spawns sessions, then **supervises**: reviews each worker's work as it reports
in, and sends rework back down. It does **not** execute tasks during a spawn.

1. **Size the batch.** Ready tasks (`[ ]`, deps `[x]`) that declare no dep on
   each other *and* whose `Owns` glob sets are pairwise disjoint. Compare the
   declared globs, not guesses about the diff: `src/api/**` and
   `src/api/auth/**` overlap, so those two tasks go in separate batches. A task
   with no `Owns` line is not batchable — give it one first.
   Batch = `min(disjoint_ready, cap)`; cap = N or 3; prefer fewer for `~L`,
   more for `~S`. Report the pick (`Spawning 3: tasks 02,04,05; deferred 03
   (dep on 02), 06 (Owns overlaps 04)`) and get one OK.
2. **Detail the batch.** Phase 1 for each task; commit `TODO/` (approval-gated)
   so worktrees branch from a state that includes the task files.
3. **Create worktrees** from current HEAD, one per task, and verify each:
   `git worktree add ../$(basename "$PWD")-taskNN-<slug> -b <type>/<slug>`
   A fresh worktree has **no dependencies** — no `node_modules`, no vendor dir.
   Run the project's install command in each one (`npm ci`, `go mod download`,
   `uv sync`, …) before spawning, or the worker's first action is a confusing
   test failure it has to diagnose before it can start.
4. **Spawn sessions** — all workers go in **one new tmux window, one pane
   each**, so the user can watch and answer every prompt without switching
   windows. Requires `$TMUX`; if unset, stop and say so. Use the exact model id
   this session runs on. Seed prompt per worker:
   > Read TODO/taskNN-<slug>.md — execute all sub-tasks (approval-gated
   > commits). When done: push, offer gh pr create, then run /handoff so the
   > task file's Handoff section carries what landed and any surprises. Then
   > report to the supervisor — write
   > `TODO/reports/taskNN.md` in the MAIN worktree at `<main-path>` (branch,
   > commits, files touched, verify commands + their output, surprises, PR
   > number if opened), and only once it is fully written and closed:
   > `touch <main-path>/TODO/reports/taskNN.done`. If the supervisor sends
   > rework, address it and re-report the same way (overwrite both files).
   > Context budget: 15% nudge, never exceed 20%.

   First worker creates the window, the rest split it. Launch `claude` with
   **no positional prompt** and no `--allowedTools` flags — local `git add` /
   `git commit` already run unprompted under the user's gates, and an
   unquoted flag string re-splits on whitespace and corrupts tmux's argument
   handling, which swallows the seed:

   ```bash
   m="claude --model <model-id> --effort max"
   win=$(tmux new-window -P -F '#{window_id}' -n cycle -c <worktree-1> "$m")
   p1=$(tmux list-panes -t "$win" -F '#{pane_id}')
   p2=$(tmux split-window -P -F '#{pane_id}' -t "$win" -c <worktree-2> "$m")
   p3=$(tmux split-window -P -F '#{pane_id}' -t "$win" -c <worktree-3> "$m")
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

   **Deliver each seed by tmux buffer**, once the pane's prompt is up — a file
   plus a buffer has no quoting surface at all:

   ```bash
   printf '%s' "$seed" > "$SP/seedNN.txt"          # single line, no embedded newlines
   tmux load-buffer -b sNN "$SP/seedNN.txt"
   tmux paste-buffer -b sNN -t "$pane"
   tmux delete-buffer -b sNN
   sleep 1 && tmux send-keys -t "$pane" Enter
   ```

   The seed must be **one line**: a multi-line paste submits at the first
   newline and strands the rest in an empty prompt. Join the prompt template
   into a single line before writing the file.

   - Title each pane so the user can tell them apart:
     `tmux select-pane -t <pane_id> -T taskNN-<slug>` — **for humans only.**
     Claude Code overwrites its own pane title to `✳ Claude Code` within
     seconds of launch, so no logic may ever key off `#{pane_title}`.
   - Confirm with `tmux list-panes -t "$win" -F '#{pane_id} #{pane_dead}
     #{pane_current_path}'` — N panes, right worktrees, `pane_dead` 0 (a failed
     `claude` launch closes its pane immediately). Keep the
     **task → pane_id → worktree → branch** mapping; supervision needs it.
     Report it to the user; remind them of `prefix + z` to zoom a pane and
     `prefix + E` to re-equalize.
5. **Write the interim handoff** — before arming supervision, refresh
   main-worktree `HANDOFF.md`: in-flight tasks (ids, branches, worktree paths,
   pane ids), unstarted tasks, and `Run /cycle --adjust to reconcile after the
   batch lands.` This is the safety net if the head dies mid-batch. Batch state
   is the one thing that stays in `HANDOFF.md` — it spans tasks; per-task state
   belongs in each task file's `## Handoff` (written by the worker).
6. **Arm supervision** — `mkdir -p TODO/reports`, then one persistent `Monitor`
   that emits a line per finished worker *and* per worker that dies without
   reporting (silence must not look like success):

   ```bash
   cd <main-worktree>; seen=""
   panes="<taskNN:pane_id pairs from the batch mapping>"   # e.g. task02:%12 task04:%13
   while true; do
     for f in TODO/reports/*.done; do
       [ -e "$f" ] || continue
       t=$(basename "$f" .done)
       case " $seen " in *" $t "*) continue ;; esac
       seen="$seen $t"; echo "REPORT $t"
     done
     # a tmux failure must not read as N dead workers — skip the sweep instead
     if live=$(tmux list-panes -t "$win" -F '#{pane_id} #{pane_dead}' 2>/dev/null); then
       for tp in $panes; do
         t=${tp%%:*}; id=${tp#*:}
         case " $seen " in *" $t "*) continue ;; esac
         case "$live" in *"$id 0"*) continue ;; esac
         seen="$seen $t"; echo "PANE GONE $t — died without reporting"
       done
     fi
     [ $(echo $seen | wc -w) -ge N ] && { echo "BATCH COMPLETE"; break; }
     sleep 20
   done
   ```

   Liveness keys off `#{pane_id}`, which nothing can overwrite. Never off
   `#{pane_title}` — Claude Code renames its own pane, the match misses every
   worker, and the first pass reports the whole batch dead ~20s after spawn.

   Then tell the user supervision is live and **stay resident** — do not
   `/clear` and do not stop; each event re-invokes the head.

**On each `REPORT taskNN`** (auto-review):

1. Read `TODO/reports/taskNN.md`, then delegate the diff read to a review agent
   (`run_in_background: false`) — the harness's code-review agent if one is
   listed in the available agent types, otherwise `general-purpose` briefed as a
   code reviewer in the prompt — pointed at the worktree with
   `git diff <base>...<branch>` and the task file as the spec —
   **the diff must land in the reviewer's context, not the head's**, or three
   reviews will blow the 15% budget.
2. Assert the write scope — `git diff --name-only <base>...<branch>` against the
   task's `Owns` globs. Any file outside them is a rework trigger even when the
   code is right: it voids the disjointness the batch was sized on and may have
   landed under a sibling worker's feet.
3. Re-run the task's verify commands in that worktree; trust the output over the
   report's claims.
4. Verdict, reported to the user either way:
   - **Pass** → tick `[x]` in `TODO/README.md` with the PR number.
   - **Rework** → send it to the worker, which still holds full context. Check
     the target first — the `pane_id` must be one from the batch mapping and
     `tmux display-message -p -t <pane_id> '#{pane_dead}'` must print `0`;
     anything else means treat the task as `PANE GONE`, don't send:
     `tmux send-keys -t <pane_id> '<specific rework instructions>' Enter`
     (escape quotes; one send per pane, never interleave). Mark `[~]`, then in
     this order: **`rm TODO/reports/taskNN.done` first**, then arm a fresh
     `Monitor` scoped to that one task (`$panes` = just its pair, N=1). The
     batch monitor already exited on `BATCH COMPLETE`, and the first report's
     `.done` still exists — arm before deleting and it fires `REPORT` instantly,
     on every pass, forever. If the pane is gone, take the task over in the
     head only if budget allows — otherwise leave `[~]` with the reason.

**On `PANE GONE`** — inspect the worktree (`git log`, `git status`, its
task file's `## Handoff`); record what landed, mark `[~]` with a concrete next step.

**On `BATCH COMPLETE`** — final checkpoint: reconcile `TODO/README.md`, offer
`git worktree remove` for passed tasks (approval-gated), then adjust and either
spawn the next batch or hand off.

Supervision is **post-commit**: worker commits are approval-gated to the user in
their own pane, so the head reviews what already landed and drives rework — it
never gates a worker's commit. `TODO/reports/` is scratch; don't commit it.

**Reconvene** (if the head *did* die, next `/cycle` or `--adjust`): read
`TODO/reports/`, check each worktree (branch pushed? PR open? task Handoff?), mark
completed tasks `[x]` with PR numbers, `git worktree remove` completed ones
(approval-gated), adjust, and continue or spawn the next batch.

## `--contest` flow (competitive selection)

One task, three agents. `--spawn` gives different tasks to different workers;
`--contest NN` gives the *same* task to two and picks the winner mechanically.
A spec agent writes acceptance tests first; A and B implement independently
against them; the head selects by test count. No agent judges its own work.

**When to recommend it:** the task is a genuine design fork (two plausible
architectures — seeing both built beats arguing about them), or it is
underspecified (the spec agent's test suite forces the acceptance criteria to
be pinned down before implementation). **Not** for well-specified `~S` tasks:
two Opus runs on a clear spec produce low-variance output — 2x tokens for a
coin flip.

1. **Preflight.** Exactly one task, required — no batch sizing, no
   substitution. If task NN is not `[ ]` or any dep is not `[x]`, exit with
   the blocker (`task 04 blocked: dep 02 is [~]`). Detail it (phase 1) if
   needed; commit `TODO/` (approval-gated). Requires `$TMUX`; if unset, stop.
2. **Spawn the spec agent — alone, first.** It runs in the main worktree on a
   tests-only branch; A and B do not exist until it has pushed.

   ```bash
   mkdir -p TODO/reports
   win=$(tmux new-window -P -F '#{window_id}' -n contest -c "$PWD" \
     "claude --model 'claude-opus-4-6[1m]' --effort max")
   spec_pane=$(tmux list-panes -t "$win" -F '#{pane_id}')
   tmux select-pane -t "$spec_pane" -T taskNN-spec   # readability only, never logic
   ```

   Deliver the spec seed by tmux buffer per `--spawn` step 4 — one line, no
   positional prompt argument, no `--allowedTools` flags.

   Spec seed prompt:
   > Read TODO/taskNN-<slug>.md. Create branch `test/<slug>-spec` from HEAD
   > (approval-gated). Write acceptance tests ONLY, verifying the task's
   > observable behavior — results, exit codes, side effects, never call
   > shapes. Do NOT implement the feature. Every test must fail (red) against
   > the current branch; a test that passes before implementation tests
   > nothing — delete and rewrite it. Run the suite and confirm all red. When
   > done: commit, push, write `TODO/reports/taskNN-spec.md` (branch, test
   > file paths, the exact command that runs them, the red-run output), and
   > only then `touch TODO/reports/taskNN-spec.done`. Context budget: 15%
   > nudge, never exceed 20%.
3. **Wait for the spec report** — the `--spawn` step 6 monitor with
   `$panes` = `taskNN-spec:$spec_pane`, N=1. On `REPORT`: re-run the reported
   test command (main worktree is on the spec branch) and confirm every test
   is red — a passing test goes back as rework via `tmux send-keys`, target
   checks per the `--spawn` rework rules. Then record
   `spec_head=$(git rev-parse test/<slug>-spec)`.
4. **Create both worktrees from `spec_head`** — not the default branch's
   HEAD — so A and B inherit the tests:

   ```bash
   git worktree add ../$(basename "$PWD")-taskNN-a -b <type>/<slug>-a "$spec_head"
   git worktree add ../$(basename "$PWD")-taskNN-b -b <type>/<slug>-b "$spec_head"
   ```

   Then run the project's install command in **both** worktrees — a fresh
   worktree has no `node_modules` or vendor dir, and neither worker can run the
   spec tests without one.

5. **Spawn A and B concurrently** — split the contest window, one pane each,
   titles `taskNN-a` / `taskNN-b`; layout, buffer seed delivery, pane mapping,
   and the interim handoff exactly as `--spawn` steps 4-5. Seed prompts are
   **identical** to each other and to the `--spawn` step 4 worker prompt
   (report files `taskNN-a.md` / `taskNN-b.md`), plus one line:
   > Run the existing tests in `<test paths from the spec report>` as part
   > of your verify step and include their output in your report.

   Neither prompt mentions the other worker, the spec agent, or a contest —
   a worker told it is competing optimizes for winning, not for the task.
6. **Supervise** — `--spawn` step 6 monitor with `$panes` =
   `taskNN-a:<pane_id> taskNN-b:<pane_id>`, N=2.
   On each `REPORT`, run the `--spawn` **On each `REPORT`** review unchanged
   (delegated diff read, `Owns` assertion, verify re-run). Selection starts
   only after both have reported. A `PANE GONE` forfeits that side — the
   survivor still has to pass selection step 1 before it wins.

**Selection** — a decision procedure, not a judgment call. Run in order; stop
at the first decisive step.

1. Run the spec agent's test command in each worktree. Take pass/fail counts
   from the runner's summary output, never from the workers' reports.
2. Counts differ → more passes wins.
3. Tied → run the project's lint/typecheck (Refs block) in both worktrees.
   One clean, one not → clean wins.
4. Still tied → two review agents (the harness's code-review agent if one is
   listed, otherwise `general-purpose` briefed as a code reviewer), one per
   diff (the diffs must land in the reviewers' context, not the head's), the
   task file as spec; ask each for a readability read and pick from the two
   reports. This is the only subjective step and it is the last resort.

**Report to the user:** winner; test counts (`A 7/9, B 9/9`); the specific
tests that differentiated them and what the loser got wrong; lint results if
step 3 decided it. Then, both approval-gated: offer the winning branch for
push + `gh pr create`, and offer `git worktree remove` of the losing worktree
(+ branch delete). Tick the task `[x]` in `TODO/README.md` naming the winning
branch.

## Context budget

Working budget is **15%** (`ctx-handoff-nudge` Stop hook is authoritative). From
~10%, don't start a sub-task you can't land inside 15%. At 15%, land the current
atomic unit if within reach, checkpoint (phase 3), invoke `handoff`. **Never
exceed 20%** — a checkpoint with a good handoff beats a finished task with none.

## When NOT to use

- Single-PR-sized work → `/slice`.
- Architecture decisions → `/delib` first, feed the result in.
- Tasks belong in GitHub issues rather than files → `/cycle-issues`.
