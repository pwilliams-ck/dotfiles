# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# direnv - quiet prompt on cd
export DIRENV_LOG_FORMAT=""

# custom scripts
export PATH="$HOME/.local/bin/:$PATH"

# go bin
export GOBIN="$HOME/go/bin"
export PATH="$PATH:$GOBIN"

# rust
export PATH="$HOME/.cargo/bin:$PATH"

# npm
export PATH="$HOME/.npm-global/bin:$PATH"

# claude
# claude() {
#   command claude --append-system-prompt-file "$HOME/.claude/extra-system-prompt.txt" "$@"
# }

# Project env comes from per-repo .envrc via direnv, not from here — keeps
# secrets scoped to the project instead of every shell.

COMPLETION_WAITING_DOTS="true"
HIST_STAMPS="yyyy-mm-dd"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Add wisely, as too many plugins slow down shell startup.
# git      → ~150 aliases (gst, gd, gco, gcm, glol, grbi, gwip…)
# fzf      → ctrl-r history / ctrl-t files / alt-c cd widgets
# docker, kubectl, golang, direnv → completions (+ k, kgp, gob, got aliases)
plugins=(git fzf docker kubectl golang direnv zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh

# Aliases and env live in $ZSH_CUSTOM (~/dotfiles/omz/), auto-sourced by the line above.

# Keybindings must come after oh-my-zsh — its key-bindings lib clobbers earlier ones.
# tmux-seshs hotkey --> ctrl+f
bindkey -s ^f "tmux-seshs.sh\n"

#pk10
source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# zsh-syntax-highlighting
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

# direnv
eval "$(direnv hook zsh)"
