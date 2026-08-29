# Next-command routing

Shared by `/handoff`, `/cycle`, `/cycle-issues`, `/slice`, `/spawn`, `/delib`. When a skill finishes a unit of work and knows what remains, it names **exactly one** command to run next — the cheapest variant that fits the remaining work. Not a menu; a recommendation.

## 1. Read the state (cheap checks only)

| Signal | How to read it |
|---|---|
| Backing store | `TODO/README.md` heading — `# Cycle:` → cycle-managed; a `## Adjustments log` confirms it. A `TODO/` from some other source is still cycle-managed: `/cycle --adjust` adopts it. |
| Issue-backed | No `TODO/`, but a pinned tracker issue (`gh issue list --label tracker --state open`). |
| Ready tasks | Rows marked `[ ]` whose deps are all `[x]`. `[~]` is in-flight, not ready. |
| Independence | Two ready tasks are independent only if neither declares the other as a dep **and** their declared `Owns` globs are disjoint. A task with no `Owns` line counts as not independent. |
| Size | The `Est` column (`~S` ≤100, `~M` 100-300, `~L` 300+ lines). |
| Blockers | Any task file or handoff with **BLOCKED**, or an open architecture question. |
| Prior guidance | This project's memory (`MEMORY.md` and the files it indexes) and the repo's `CLAUDE.md` / `AGENTS.md`. A recorded preference or a "do X next" note **overrides the table below** — say so in the reason. |

Never spend a subagent or a wide grep on this. If the signals are not already in context, three `Read`s and one `gh` call is the whole budget; when a signal is unreadable, treat it as absent.

## 2. Route

Take the first row that matches.

| State | Recommend |
|---|---|
| Next step is an unresolved architecture or dependency decision | `/delib "<the question>"` |
| Issue-backed, ≥2 independent ready issues | `/cycle-issues --spawn [N]` |
| Issue-backed | `/cycle-issues NN` |
| Cycle-managed, plan drifted from what the session learned | `/cycle --adjust` |
| Cycle-managed, ≥2 independent ready tasks, all `~S`/`~M` | `/cycle --spawn [N]` |
| Cycle-managed, one ready task | `/cycle NN` |
| Cycle-managed, next task not yet detailed | `/cycle` |
| No plan store, remaining work is one PR | `/slice "<task>"` |
| No plan store, several PRs | `/cycle "<goal>"` |
| No plan store, real unknowns blocking decomposition | `/delib "<the question>"`, then `/cycle` |

### Sizing `--spawn`

`N = min(independent ready tasks, 4)`. Drop to 2 when any task in the batch is `~L`, and don't spawn at all for a single ready task — a worktree plus a supervising head costs more than doing it inline. Spawn needs `$TMUX`; without it, recommend the sequential variant instead.

### Prefer the cheaper variant

`/cycle NN` over `/cycle` when the task id is known — it skips re-reading the index to pick. Naming the id is free and saves the next session a planning round.

## 3. Emit it

One fenced block, last thing before the skill stops:

```
Next: /clear, then /cycle --spawn 4
Why: tasks 02, 04, 05 are independent and ~S.
```

Rules: one command, one reason line of ≤15 words, no alternatives. Omit `/clear` only when the next command is meant to run in the current session with its context intact. If two routes are genuinely tied, pick the cheaper one and name the runner-up in the same reason line — never as a second block.
