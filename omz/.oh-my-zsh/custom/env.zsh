# Environment — auto-sourced by oh-my-zsh ($ZSH_CUSTOM/*.zsh), after plugins load.

# Editor
export EDITOR=nvim
export VISUAL=nvim

# bat as the man pager (syntax-highlighted man pages)
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export MANROFFOPT="-c"

# fzf: fd for file lists, bat for previews
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS='--height=60% --layout=reverse --border --info=inline'
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --line-range :200 {}'"
export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
export FZF_ALT_C_OPTS="--preview 'eza -T --level=2 --colour=always {}'"
