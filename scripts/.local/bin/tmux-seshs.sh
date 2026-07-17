#!/usr/bin/env bash

if [[ $# -eq 1 ]]; then
    selected=$1
else
    result=$(find \
        /Users/ \
        ~ \
        ~/.claude/ \
        ~/.claude/plans/ \
        ~/Developments \
        ~/Developments/tutorials/ \
        ~/Developments/progrums/ \
        ~/Developments/progrums/godot/ \
        ~/Developments/work/ \
        ~/Developments/work/ck/ \
        ~/Developments/work/ck/programmin/ \
        -mindepth 1 -maxdepth 1 -type d | fzf --print-query)
    status=$?
    query=$(head -1 <<<"$result")
    match=$(tail -n +2 <<<"$result")

    if [[ $status -eq 130 ]]; then
        exit 0 # Esc / Ctrl-C aborts
    elif [[ -z $query ]]; then
        selected=$HOME # Enter on an empty prompt
    else
        selected=$match
    fi
fi

if [[ -z $selected ]]; then
    exit 0
fi

selected_name=$(basename "$selected" | tr . _)
tmux_running=$(pgrep tmux)

if [[ -z $TMUX ]] && [[ -z $tmux_running ]]; then
    tmux new-session -s "$selected_name" -c "$selected"
    exit 0
fi

if ! tmux has-session -t="$selected_name" 2>/dev/null; then
    tmux new-session -ds "$selected_name" -c "$selected"
fi

tmux switch-client -t "$selected_name"
