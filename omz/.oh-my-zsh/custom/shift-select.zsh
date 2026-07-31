# Shift+motion selects text on the command line, the way it does in a GUI editor.
#
# zsh has no selection primitive. REGION_ACTIVE + MARK is the mechanism vi visual
# mode uses, so these widgets set it and let zle draw the highlight itself
# (styled by zle_highlight's `region`, standout by default).
#
# The key sequences below are what iTerm2 emits for the Karabiner Tab nav layer;
# see karabiner/.config/karabiner/assets/complex_modifications/vim-nav-layers.json.

shift-select::select-and() {
  # Anchor on the first shifted motion; later ones extend the same region.
  if (( REGION_ACTIVE == 0 )); then
    MARK=$CURSOR
    REGION_ACTIVE=1
  fi
  zle "$1"
}

shift-select::kill-region-or() {
  if (( REGION_ACTIVE )); then
    zle kill-region
    REGION_ACTIVE=0
  else
    zle "$1"
  fi
}

# A widget takes no arguments when zle invokes it from a binding, so each
# binding needs its own wrapper around the motion it drives.
() {
  local widget motion
  for widget motion in \
    backward-char       backward-char \
    forward-char        forward-char \
    backward-word       backward-word \
    forward-word        forward-word \
    beginning-of-line   beginning-of-line \
    end-of-line         end-of-line
  do
    eval "shift-select::select-${widget}() { shift-select::select-and ${motion} }"
    zle -N "shift-select::select-${widget}"
  done

  for widget motion in \
    backward-delete-char backward-delete-char \
    delete-char          delete-char
  do
    eval "shift-select::kill-or-${widget}() { shift-select::kill-region-or ${motion} }"
    zle -N "shift-select::kill-or-${widget}"
  done
}

# Any widget that isn't one of ours drops the region, so an unshifted motion or a
# stray keypress can't leave a stale highlight or a MARK pointing into text that
# has since been edited.
shift-select::drop-stale-region() {
  [[ $LASTWIDGET == shift-select::* ]] || REGION_ACTIVE=0
}
zle -N shift-select::drop-stale-region
autoload -Uz add-zle-hook-widget
add-zle-hook-widget line-pre-redraw shift-select::drop-stale-region

# shift+arrow
bindkey -M emacs '^[[1;2D' shift-select::select-backward-char
bindkey -M emacs '^[[1;2C' shift-select::select-forward-char

# shift+word-jump. 1;4 is right-option+shift (what the nav layer sends, since
# iTerm2's left option is set to Esc+); 1;6 and ^[^[ cover ctrl+shift and a
# left-option+shift pressed directly.
bindkey -M emacs '^[[1;4D' shift-select::select-backward-word
bindkey -M emacs '^[[1;4C' shift-select::select-forward-word
bindkey -M emacs '^[[1;6D' shift-select::select-backward-word
bindkey -M emacs '^[[1;6C' shift-select::select-forward-word
bindkey -M emacs '^[^[[1;2D' shift-select::select-backward-word
bindkey -M emacs '^[^[[1;2C' shift-select::select-forward-word

# oh-my-zsh binds only the application-mode home/end (terminfo khome/kend, ^[OH
# and ^[OF), so an unmodified Home lands on undefined-key whenever the terminal
# is not in application cursor mode. Bind every form a terminal may send.
bindkey -M emacs '^[[H' beginning-of-line
bindkey -M emacs '^[[F' end-of-line
bindkey -M emacs '^[[1~' beginning-of-line
bindkey -M emacs '^[[7~' beginning-of-line
bindkey -M emacs '^[[4~' end-of-line
bindkey -M emacs '^[[8~' end-of-line

# shift+home / shift+end
bindkey -M emacs '^[[1;2H' shift-select::select-beginning-of-line
bindkey -M emacs '^[[1;2F' shift-select::select-end-of-line
bindkey -M emacs '^[[1;2~' shift-select::select-beginning-of-line
bindkey -M emacs '^[[4;2~' shift-select::select-end-of-line

# Deleting with a selection kills it, as in a GUI editor.
bindkey -M emacs '^?' shift-select::kill-or-backward-delete-char
bindkey -M emacs '^[[3~' shift-select::kill-or-delete-char
