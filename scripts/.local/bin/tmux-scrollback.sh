#!/usr/bin/env bash
# tmux copy mode has no line-number gutter, so hand the pane's scrollback to
# nvim, which has one. Piped instead of written to a temp file: pane history
# routinely holds tokens and keys, and shouldn't land on disk.
set -euo pipefail

pane=${1:?usage: tmux-scrollback.sh <pane-id>}

# -w/-h percentages are relative to the whole terminal, so size against the
# pane by hand and centre it there via tmux's popup_pane_* origin formats.
read -r width height < <(tmux display -p -t "$pane" -F '#{pane_width} #{pane_height}')
popup_width=$((width * 9 / 10))
popup_height=$((height * 9 / 10))

tmux display-popup -E -t "$pane" \
    -w "$popup_width" -h "$popup_height" \
    -x "#{e|+:#{popup_pane_left},$(((width - popup_width) / 2))}" \
    -y "#{e|+:#{popup_pane_top},$(((height - popup_height) / 2))}" \
    "tmux capture-pane -p -S - -t '$pane' | nvim -R -c 'setlocal relativenumber number' -c 'nnoremap q <Cmd>qa!<CR>' -c 'normal! G' -"
