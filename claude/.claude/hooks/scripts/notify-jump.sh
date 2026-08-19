#!/bin/sh
# Jump to the Claude pane that last asked for input (same as clicking the
# banner). Runs from Karabiner, so PATH and tmux client must be explicit.
PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"
pane=$(sed -n 2p "$HOME/.cache/claude-notify-click" 2>/dev/null)
if [ -n "$pane" ]; then
  for c in $(tmux list-clients -F '#{client_tty}'); do
    tmux switch-client -c "$c" -t "$pane"
  done
  tmux select-window -t "$pane"
  tmux select-pane -t "$pane"
fi
open -a iTerm
