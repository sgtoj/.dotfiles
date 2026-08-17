# profiler start (enable via ZSH_PROFILE=1)
if [[ -n $ZSH_PROFILE ]]; then
  zmodload zsh/zprof             # start profiler early
fi

# modules (order matters)
ZSH_CONFIG_DIR="${HOME}/.config/zsh"
for module in env plugins completions history aliases tools keybinds prompt; do
  [[ -f "${ZSH_CONFIG_DIR}/${module}.zsh" ]] && source "${ZSH_CONFIG_DIR}/${module}.zsh"
done

# machine-local overrides (not tracked in dotfiles)
[[ -f "${ZSH_CONFIG_DIR}/local.zsh" ]] && source "${ZSH_CONFIG_DIR}/local.zsh"

# profiler end (enable via ZSH_PROFILE=1)
if [[ -n $ZSH_PROFILE ]]; then
  # dump stats to a file then print a one-liner summary
  zprof >${XDG_CACHE_HOME:-$HOME/.cache}/zsh_profile.txt
  printf '%s\n' 'zsh profile written to ~/.cache/zsh_profile.txt'
fi
