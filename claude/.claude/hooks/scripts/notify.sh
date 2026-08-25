#!/bin/sh
PATH="/opt/homebrew/bin:$PATH"
dir=${PWD##*/}
msg=$dir
pane=""
if [ -n "$TMUX" ]; then
  win=$(tmux display-message -p -t "$TMUX_PANE" '#I:#W' 2>/dev/null)
  [ -n "$win" ] && msg="$dir ($win)"
  pane=$TMUX_PANE
fi

app="$HOME/Applications/ClaudeNotify.app"
src="$HOME/.claude/hooks/scripts/claude-notify.applescript"
if [ ! -d "$app" ]; then
  mkdir -p "$HOME/Applications"
  # osacompile stamps the placeholder bundle id "aplt", which macOS refuses to
  # register for notification permission — replace it before first launch
  osacompile -o "$app" "$src" &&
    plutil -replace CFBundleIdentifier -string "io.cloudkey.pwilliams.claudenotify" "$app/Contents/Info.plist" &&
    plutil -replace CFBundleName -string "ClaudeNotify" "$app/Contents/Info.plist" &&
    plutil -replace LSUIElement -bool true "$app/Contents/Info.plist" &&
    codesign --force --sign - "$app" || {
    rm -rf "$app"
    osascript -e "display notification \"$msg\" with title \"Claude Code — waiting\""
    exit 0
  }
fi

mkdir -p "$HOME/.cache"
printf 'pending\n%s\n%s\n' "$pane" "$msg" > "$HOME/.cache/claude-notify-click"
open -g "$app"
