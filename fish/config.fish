set fish_greeting "There's no place like ~/"

set -g fish_user_paths /opt/homebrew/bin $fish_user_paths
set -g fish_user_paths "~/.local/share/nvim/site/pack/packer/start/packer.nvim" $fish_user_paths
set -g fish_user_paths "~/Development/downloads/nand2tetris/tools" $fish_user_paths

set -gx EXA_COLORS "uf:6:gf:6"

set -gx TERM xterm-256color

# theme
set -g theme_color_scheme terminal-dark
set -g fish_prompt_pwd_dir_length 1
set -g theme_display_user yes
set -g theme_hide_hostname no
set -g theme_hostname always

# aliases
alias ls "ls -p -G"
alias la "ls -A"
alias ll "exa -l"
alias lla "ll -A"
alias c clear
alias g git
alias ssha "eval (ssh-agent -c) && ssh-add ~/.ssh/id_ed25519"
command -qv nvim && alias vim nvim

set -gx EDITOR nvim

set -gx PATH bin $PATH
set -gx PATH ~/bin $PATH
set -gx PATH ~/.local/bin $PATH

# NodeJS
set -gx PATH node_modules/.bin $PATH

# Go
set -g GOPATH $HOME/go
set -gx PATH $GOPATH/bin $PATH

# NVM
function __check_rvm --on-variable PWD --description 'Do nvm stuff'
    status --is-command-substitution; and return

    if test -f .nvmrc; and test -r .nvmrc
        nvm use
    else
    end
end


set LOCAL_CONFIG (dirname (status --current-filename))/config-local.fish
if test -f $LOCAL_CONFIG
    source $LOCAL_CONFIG
end

if status is-interactive
    # Commands to run in interactive sessions can go here
end
