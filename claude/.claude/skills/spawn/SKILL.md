---
name: spawn
description: Open a new interactive Claude Code session in a new tmux window (like prefix+c) of the current tmux session, running the same model as the caller. Seeds it with a handoff pickup (task file's Handoff section, or HANDOFF.md) and a 15%/20% context-budget rule; optional argument appends the task, e.g. /spawn, /spawn "continue task 07c2".
---

## Help

If `$ARGUMENTS` is exactly `--help`, `help`, or `-h`, print the block below
verbatim and **stop — do not execute the skill**.

```
/spawn — open a new Claude Code session in a new tmux window (same model)

  Open a new interactive Claude Code session in a new tmux window (like
  prefix+c) of the current tmux session, running the same model as the
  caller. Seeds it with a handoff pickup (if present) and a 15%/20%
  context-budget rule; optional argument appends the task.

  /spawn                         new session, picks up the existing handoff
  /spawn "continue task 07c2"    new session seeded with a task
  /spawn --help                  show this help

  See also:
    /handoff       write the handoff before spawning
    /cycle --spawn fan out concurrent tasks in worktrees
```

---

# Spawn a sibling Claude Code session

Open a fresh interactive `claude` in a **new window of the current tmux
session**, on the **same model** as this session, then confirm the window
exists. Do not guess the model — use the exact model id this session runs on
(it is stated in your system prompt, e.g. `claude-fable-5`).

## 1. Preconditions

- `[ -n "$TMUX" ]` — if unset, stop and tell the user this only works inside tmux.
- Capture the session name: `session=$(tmux display-message -p '#S')`.

## 2. Build the seed prompt

The new session always starts with an initial prompt composed of, in order:

1. **Handoff pickup** — resolve where the handoff lives, in this order:
   - `TODO/README.md` exists → `Read TODO/README.md, follow its Resume pointer
     to the task file, and continue from that file's Handoff section.`
   - else `HANDOFF.md` exists in `$PWD` (`[ -f HANDOFF.md ]`) →
     `Read HANDOFF.md first and continue from it.`
   - else omit this line.
2. **Context budget** — always include, verbatim:

   > Context budget: if any single prompt run reaches 15% of the context
   > window, run /handoff so a fresh session can take over. NEVER exceed 20%
   > total: treat 15% as the signal to gauge remaining work and wind down —
   > finish or checkpoint the current sub-task and leave a concrete next step
   > in the handoff. Never leave a task or sub-task hanging with no plan there.

3. **`$ARGUMENTS`** — if non-empty, appended last as the actual task.

## 3. Create the window

One command; `-P -F` prints the new window's target for verification:

```bash
tmux new-window -P -F '#{session_name}:#{window_index}' -n cc -c "$PWD" \
  "claude --model <model-id> '<seed prompt>'"
```

- Like `prefix + c`, this switches focus to the new window — that is expected;
  do not add `-d`.
- The seed prompt is single-quoted inside the command string; escape any
  single quotes in it (`'` → `'\''`) first.

## 4. Confirm

Verify the printed target is in the **same session** and still alive (a failed
`claude` launch closes its window immediately):

```bash
tmux list-windows -t "$session" -F '#{session_name}:#{window_index} #{window_name}'
```

- The target from step 2 must appear in this list. If it does not, report the
  failure — re-run the launch command in the current pane's shell context to
  surface the error, don't silently retry.
- Report to the user: window target (e.g. `dotfiles:3`), window name, and the
  model launched.
