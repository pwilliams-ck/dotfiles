# Parker's Dotfiles

Personal macOS config, deployed with [GNU Stow](https://www.gnu.org/software/stow/).
Each top-level dir (`nvim/`, `tmux/`, `scripts/`, `markdownlint/`, `claude/`, `codex/`) is a Stow package; `stow <pkg>` symlinks it into `$HOME`. The deployed files are symlinks back into the repo, so editing here edits the live config.

## Table of Contents

- [New machine setup](#new-machine-setup)
- [Terminal](#terminal)
  - [IDE](#ide)
  - [Shell](#shell)
- [Karabiner-Elements](#karabiner-elements)
- [Raycast](#raycast)

## New machine setup

```bash
# 1. Prerequisites (jq is required by the claude hooks + statusline)
brew install stow jq

# 2. Clone (examples assume ~/dotfiles; Stow makes symlinks relative to wherever you clone)
git clone https://github.com/pwilliams-ck/dotfiles ~/dotfiles
cd ~/dotfiles

# 3. Deploy packages
stow nvim tmux scripts markdownlint codex
```

`stow -D <pkg>` un-deploys (removes the symlinks).

### Claude Code

The CLI is **not** in this repo — install it separately. And unlike nvim/tmux,
Claude Code keeps its runtime state (`projects/`, `sessions/`, `history.jsonl`,
caches) **inside** `~/.claude`, so it must already exist as a real directory
before stowing — otherwise Stow symlinks the whole `~/.claude` into the repo and
Claude writes session state into git.

```bash
curl -fsSL https://claude.ai/install.sh | bash   # or: brew install --cask claude-code
claude                                            # log in; creates ~/.claude as a real dir
# quit Claude, then:
cd ~/dotfiles && stow claude
```

Not carried by the repo — set up separately on each machine:

- **Plugins** flagged in `settings.json` (`feature-dev`, `gopls-lsp`) — install via the plugin marketplace.
- **MCP servers** (e.g. clickup) and their auth — machine-local (`~/.claude.json`); reconfigure.
- `~/.claude/settings.local.json` and `hooks/logs/` — machine-local, intentionally untracked.
- The hook scripts were vendored from the archived `review-hooks` repo; edit them under `claude/.claude/hooks/scripts/`.

### Codex

The Codex CLI is **not** in this repo — install it separately. Codex keeps runtime state (`sessions/`, `history.jsonl`, sqlite DBs, caches, memories, plugin caches, auth, and temporary files) inside `~/.codex`, so it must already exist as a real directory before stowing — otherwise Stow symlinks the whole `~/.codex` into the repo and Codex writes state into git.

```bash
codex                       # log in; creates ~/.codex as a real dir
# quit Codex, then:
cd ~/dotfiles && stow codex
```

Stowed:

- `config.toml` — model, TUI, trusted projects, marketplace, plugin, and feature settings.
- `AGENTS.md` — global Codex instructions.
- `rules/default.rules` — approved command prefix rules.

Not carried by the repo — keep machine-local:

- `auth.json`, `installation_id`, sqlite DBs, logs, sessions, history, caches, plugin caches, memories, worktrees, shell snapshots, temporary files, and automation reports.

## Terminal

- [iTerm2](https://iterm2.com/documentation.html) - MacOS Terminal Emulator
- [tmux](https://github.com/tmux/tmux/wiki) - Terminal multiplexer

### IDE

- [LazyVim](https://lazyvim.org) - Custom LazyVim config

### Shell

- [zsh](https://www.zsh.org/) - Shell
- [oh-my-zsh](https://ohmyz.sh/) - `zsh` management, themes, plugins, etc.

## Karabiner-Elements

[Karabiner-Elements](https://karabiner-elements.pqrs.org/) - MacOS keymapping.

- Swap `left ctrl` & `caps lock`.
- `left ctrl` + `h`, `j`, `k`, `l` --> `left`, `up`, `down`, `right` arrow keys.
- `left ctrl` + `[` --> `esc`

## Raycast

[Raycast](https://raycast.com) - Improved Spotlight search & much more.
