# --- fzf Catppuccin Macchiato theme ---
export FZF_DEFAULT_OPTS=" \
  --color=bg+:#363a4f,bg:#24273a,spinner:#f4dbd6,hl:#ed8796 \
  --color=fg:#cad3f5,header:#ed8796,info:#c6a0f6,pointer:#f4dbd6 \
  --color=marker:#f4dbd6,fg+:#cad3f5,prompt:#c6a0f6,hl+:#ed8796 \
  --color=border:#494d64"

# --- Autosuggestions tuning (must be set BEFORE zim init) ---
# magic-enter rebinds ^M to 'buffer-empty', so we must clear on that widget too
ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(accept-line buffer-empty)

# --- zimfw bootstrap ---
ZIM_HOME=~/.zim
[[ -f ${ZIM_HOME}/init.zsh ]] || source ${ZIM_HOME}/zimfw.zsh init -q
source ${ZIM_HOME}/init.zsh

# --- Sane options (replaces zsh-saneopt) ---
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS HIST_SAVE_NO_DUPS HIST_REDUCE_BLANKS SHARE_HISTORY
setopt INTERACTIVE_COMMENTS EXTENDED_GLOB
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history

# When in tty swap to different starship config so different fonts can be used
if [[ "$TERM" == "linux" ]]; then
  export STARSHIP_CONFIG="$HOME/.config/starship-tty.toml"
fi

# --- direnv (must hook before starship so DIRENV_FILE is set for first prompt) ---
eval "$(direnv hook zsh)"

# --- Prompt ---
eval "$(starship init zsh)"

# --- PATH ---
path+=("$HOME/.local/bin")  # Used for uv

# --- Git aliases ---
alias Gw='git worktree'
alias Gpo='git push origin'

# Other aliases
if [[ "$TERM" == "linux" ]]; then
  alias ls='lsd --icon never'
  alias ll='lsd --icon never -l'
  alias la='lsd --icon never -a'
  alias lsa='lsd --icon never -lah'
else
  alias ls='lsd'
  alias ll='lsd -l'
  alias la='lsd -a'
  alias lsa='lsd -lah'
fi

# Zim alias finder (shanwker1223/zim-alias-finder)
zstyle ':zim:plugins:alias-finder' autoload yes


# --- thefuck (lazy loaded) ---
fuck() {
    unfunction fuck
    eval "$(thefuck --alias)"
    fuck "$@"
}

# --- Key bindings ---
[[ "$TERM_PROGRAM" == "ghostty" ]] && export TERM=xterm-256color
WORDCHARS=${WORDCHARS/\/}         # Treat / as a word boundary
# Key binding fixes for alt+ arrow keys
bindkey '\e[1;3C' forward-word    # Alt+Right
bindkey '\e[1;3D' backward-word   # Alt+Left

# Double-Escape to clear the current input line
zmodload zsh/datetime  # provides EPOCHREALTIME
_double_escape_threshold=200  # milliseconds
_last_escape_time=0
double-escape-clear-line() {
  local now=$((EPOCHREALTIME * 1000))
  local elapsed=$(( now - _last_escape_time ))
  if (( elapsed <= _double_escape_threshold )); then
    zle kill-whole-line
    _last_escape_time=0
  else
    _last_escape_time=$now
  fi
}
zle -N double-escape-clear-line
bindkey '\e\e' double-escape-clear-line

# --- Source bash profile ---
[[ -f ~/.bash_profile ]] && source ~/.bash_profile

. "$HOME/.local/bin/env"
