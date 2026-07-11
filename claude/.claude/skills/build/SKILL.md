---
name: build
description: Execute a /blueprint plan — work through TODO/ task by task with tiered coordination. The head model orchestrates, reviews, and owns git; implementation workers (opus, or sonnet for fully specified sub-tasks) do the TDD edits. One task = one PR (~300 lines), one sub-task = one atomic commit; checkboxes updated as commits land; TODO/ edits proposed to the user before applying. e.g. /build, /build 03, /build 03.2.
---

## Help

If `$ARGUMENTS` is exactly `--help`, `help`, or `-h`, print the block below
verbatim and **stop — do not execute the skill**.

```
/build — execute a /blueprint plan task by task (TDD, one PR per task)

  Execute a /blueprint plan — work through TODO/ task by task with tiered
  coordination. The head model orchestrates, reviews, and owns git;
  implementation workers (opus, or sonnet for fully specified sub-tasks)
  do the TDD edits. One task = one PR (~300 lines), one sub-task = one
  atomic commit; checkboxes updated as commits land; TODO/ edits proposed
  to the user before applying.

  /build                         next ready task
  /build 03                      specific task
  /build 03.2                    resume at a sub-task
  /build --help                  show this help

  See also:
    /blueprint     create the TODO/ plan this executes
    /delib         pause for a mid-task architecture decision
    /slice         implement a one-off task without a plan
    /handoff       capture state when stopping mid-plan
```

---

# Build (`/build`)

Execute the plan in `TODO/`. The **head model** (this session) sequences,
prompts workers, reviews their output, and runs every git command
(approval-gated, repo policy wins). **Workers** implement. All of the repo's
rules — `CLAUDE.md`, git policy, TDD — apply; this skill sequences them, it
never relaxes them.

## Syntax

```
/build [task-id[.sub-task]]
```

- **(none)** — next task in `TODO/README.md` order whose deps are `[x]`.
- **`03`** — that task. **`03.2`** — resume at that sub-task.

## Phase 0 — Orient (head)

1. Read `HANDOFF.md` (if present), `TODO/README.md`, and the task file.
2. Verify deps are done and the task's refs still hold — spot-grep the
   verified names; a stale plan gets amended (below), not silently followed.
3. Re-check repo state: `git branch --show-current`, `git status --short`.
   Propose the task's branch (`git switch -c <type>/<kebab>`, approval-gated).
   Never work on the default branch.

## Model tiers

| Role | Model | Job |
|------|-------|-----|
| Head | session model | Orchestrate, review diffs/test output, own git, update TODO/. |
| Implementation worker | `model: "opus"` (default) | Execute one sub-task TDD: red → green → refactor. |
| — well-specified sub-task | `model: "sonnet"` | Allowed only when the task file fully specifies names, files, and test — say why when downgrading. |
| Lookups | `model: "haiku"` / default | Greps, doc re-checks. |

Every `Agent()` call passes `model:` explicitly. **Never spawn Fable
subagents.** Sub-tasks within a task run **sequentially** in the main worktree
(each commit builds on the last). Only fully independent *tasks* may run in
parallel, each with `isolation: "worktree"` — and only when the user asks.

## Per sub-task loop

For each unchecked sub-task, in order:

1. **Prompt the worker** with a self-contained brief: the sub-task line, the
   task file's Refs, the README's shared-refs rows it needs, the repo's test
   command (with bug-surfacing flags), and the contract:
   > Write the failing test first; run it and show the failure-for-the-right-
   > reason. Implement the minimum to pass; show green. Refactor green. Touch
   > only the listed files. Return: what changed (per file, one line), the
   > real test command + output, and anything that contradicted the brief.
2. **Review** the worker's report and diff (`git diff`). Contradictions with
   the plan stop the loop → amend flow below. Rework goes back to the same
   worker via `SendMessage` — don't respawn fresh.
3. **Verify** yourself: run the full check (test + lint) and show it green.
4. **Commit** (approval-gated): re-verify branch + cwd, propose the atomic
   commit per the repo's convention. In stage-only repos (e.g. CloudKey
   core): stage, never commit.
5. **Tick the box** in `TODO/taskNN-*.md` and fold that edit into the same
   commit. Progress lives in the plan, not in chat.

## Amending TODO/

When reality diverges — wrong name, missing dep, task too big, new info:

- Propose the edit in ≤3 lines (`taskNN: <what changes and why>`), wait for
  the user's OK, then apply to the task file and README.
- A task trending past ~300 changed lines gets a split proposal **before**
  it grows, not a bigger PR.
- Never silently deviate from the plan while leaving TODO/ stale.

## Finish a task

1. Run the task's **Verify** block and the full check; show green.
2. Final commit bundles remaining doc/TODO updates (README status → `[x]`).
   Never a standalone doc-only commit.
3. Offer push + `gh pr create` per the repo's git policy — exact commands,
   wait for approval, never merge. PR body notes size if >300 lines and why.
4. Invoke the **`handoff`** skill (`merged` if the PR merged this session).
   Recommend `/clear` before the next `/build` — task files are written for
   zero context on purpose.

Do not roll into the next task in the same run unless the user asks.

## Context budget

- Working budget is **15% context used** (the `ctx-handoff-nudge` Stop hook
  fires there — treat it as authoritative).
- From ~10%, gauge runway: don't start a sub-task you can't land (worker run
  + review + commit) inside 15%.
- At 15%: land the current atomic unit if it's within reach, tick its box,
  then invoke **`handoff`**. HANDOFF.md must pin the exact state: branch,
  task/sub-task position, staged vs uncommitted files, last test result.
- **Never exceed 20% in one run.** If landing the unit would cross it, stop
  where you are, record the precise resume point (`/build NN.M`) in
  HANDOFF.md, and end the turn. A hanging sub-task with a good handoff beats
  a finished one with none.

## When NOT to use

- No `TODO/` exists — run `/blueprint` first (or `/slice` for one-off tasks).
- Mid-task architecture doubts — pause and run `/delib`, feed the decision
  back via the amend flow.
