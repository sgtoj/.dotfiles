# keybindings (vim) and cursor shape

export KEYTIMEOUT=30 # 100 units is 1s
bindkey -v
bindkey -M viins 'jk'  vi-cmd-mode
bindkey -M viins '^?'  backward-delete-char   # backspace (DEL)
bindkey -M viins '^H'  backward-delete-char   # backspace (Ctrl-H)
bindkey -M viins '^f'  autosuggest-accept
bindkey -M viins '^p'  history-search-backward
bindkey -M viins '^n'  history-search-forward
bindkey -M viins '^[w' kill-region

# fzf keybindings (ctrl-r history, ctrl-t files, alt-c cd) and completion
# sourced after `bindkey -v` so bindings land in the vi keymaps
if command -v fzf >/dev/null 2>&1 && fzf_init=$(fzf --zsh 2>/dev/null); then
  eval "$fzf_init"
fi
unset fzf_init

# cursor
function zle-keymap-select {
  case $KEYMAP in
    vicmd) echo -ne '\e[1 q' ;;  # block cursor
    viins) echo -ne '\e[5 q' ;;  # beam cursor
    main)  echo -ne '\e[5 q' ;;  # fallback
  esac
}
function zle-line-init {
  echo -ne '\e[5 q'  # start with beam
}
function zle-line-finish {
  echo -ne '\e[5 q'  # reset to beam on finish
}
zle -N zle-keymap-select
zle -N zle-line-init
zle -N zle-line-finish
unset zle_bracketed_paste # disable bracketed paste messiness
