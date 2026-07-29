# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Personal macOS dotfiles. There is no build and no application code — these are configuration files deployed into `$HOME` via GNU Stow. No tests in this repo.

## Git

This repo grants push and PR access, but **approval-gated**: always show the exact command and wait for my confirmation before running it.

- You may `git push` a feature branch and open a PR with `gh pr create` — only after I confirm the exact command.
- Never push to `main`, never merge, never tag. PRs are opened, never merged.

## Architecture: Stow package layout

Each top-level directory (`nvim/`, `tmux/`, `zsh/`, `scripts/`, `markdownlint/`, `claude/`, `codex/`) is a **GNU Stow package** whose internal path mirrors where it lands under `$HOME`. For example `nvim/.config/nvim/init.lua` is deployed to `~/.config/nvim/init.lua`.

Deploy by symlinking a package into `$HOME` from the repo root:

```bash
stow nvim         # symlinks nvim/.config/nvim       -> ~/.config/nvim
stow tmux         # symlinks tmux/.config/tmux       -> ~/.config/tmux
stow zsh          # symlinks zsh/.zshrc, .p10k.zsh, .zprofile -> ~/
stow scripts      # symlinks scripts/.local/bin/*    -> ~/.local/bin/
stow markdownlint # symlinks markdownlint/.markdownlint.json -> ~/.markdownlint.json
stow claude       # symlinks claude/.claude/*        -> ~/.claude/
stow codex        # symlinks codex/.codex/*         -> ~/.codex/
stow -D nvim      # un-deploy (remove symlinks)
```

The deployed files in `$HOME` are symlinks back into this repo, so editing a file here edits the live config. (The README's `git clone … ~/.config/` instruction is outdated — Stow is the actual mechanism.)

## Neovim (`nvim/.config/nvim/`)

Built on **LazyVim**; `lua/config/lazy.lua` is the entry point. Config in `lua/config/` layers on top of LazyVim defaults rather than replacing them; specs in `lua/plugins/*.lua` are **merged** with LazyVim's. To extend a list option (e.g. `ensure_installed`), use the `opts = function(_, opts)` form and `vim.list_extend`; see `lsp.lua` and `proto.lua` for the pattern.

Notable: custom keymaps use `s`-prefixed window commands and `t`-prefixed Telescope pickers (`editor.lua`, `keymaps.lua`); `pwilliams/discipline.lua` rate-limits repeated `hjkl`. Prettier only runs in repos that have their own Prettier config (`vim.g.lazyvim_prettier_needs_config = true` in `options.lua`).

`lazy-lock.json` is gitignored — the plugin lockfile is intentionally not tracked.

`selene` and `luacheck` are available for linting Lua, but only inside Neovim — they're installed via Mason, not on PATH.

## Scripts (`scripts/.local/bin/`)

Custom shell tools deployed to `~/.local/bin`:

- `reqd` — **moved to its own repo** at `~/Developments/work/ck/programmin/reqd`; what's here is an untracked, gitignored symlink keeping it on PATH.
- `cht.sh` — **vendored third-party** cheat.sh shell client (has its own `update`/`version` self-management). Don't hand-edit; treat as upstream.

The `claude` file (untracked) is **not** part of these dotfiles. It's a symlink the Claude Code installer wrote to `~/.local/bin/claude` (pointing at `~/.local/share/claude/versions/<ver>`); because `~/.local/bin` is a folded Stow symlink to this directory, that write landed inside the repo. It's machine- and version-specific — don't commit it (gitignore it, or unfold the dir so `~/.local/bin` holds per-file symlinks).

## Claude Code (`claude/.claude/`)

Global Claude Code config. `~/.claude/` is a real directory full of machine state, so Stow **folds**: only the items below become symlinks; everything else there (`projects/`, `sessions/`, `history.jsonl`, caches, `plugins/`, `settings.local.json`, and `hooks/logs/` + `hooks/.rename-plans-since`) stays real and untracked.

Stowed:

- `AGENTS.md` — global cross-project instructions; `settings.json` — permissions, hooks wiring, status line, plugins; `keybindings.json`; `statusline-command.sh`; `extra-system-prompt.txt`.
- `commands/` — custom slash commands. `skills/` — `pm` and `slice`.
- `hooks/scripts/` — `bash-write-gate.sh` (PreToolUse(Bash) gate), `rename-plans.sh` (Stop hook), and their `common.sh` lib. **Vendored** from the now-archived `review-hooks` repo and wired via the `hooks` block in `settings.json`; edit here = live. The dormant scripts and `patterns/` from that repo were intentionally left behind.

`settings.local.json` is machine-local and deliberately **not** stowed.

## Codex (`codex/.codex/`)

Global Codex CLI config. `~/.codex/` is a real directory full of machine state, so Stow **folds**: only the items below become symlinks; everything else there (`auth.json`, `installation_id`, sqlite DBs, logs, `sessions/`, `history.jsonl`, caches, plugin caches, memories, worktrees, shell snapshots, temporary files, and automation reports) stays real and untracked.

Stowed:

- `config.toml` — model, TUI, trusted projects, marketplace, plugin, and feature settings.
- `AGENTS.md` — global Codex instructions.
- `rules/default.rules` — approved command prefix rules.
