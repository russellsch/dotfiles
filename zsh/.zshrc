# --- zimfw bootstrap ---
ZIM_HOME=~/.zim
[[ -f ${ZIM_HOME}/init.zsh ]] || source ${ZIM_HOME}/zimfw.zsh init -q
source ${ZIM_HOME}/init.zsh

# --- Prompt ---
eval "$(starship init zsh)"

# --- Sane options (replaces zsh-saneopt) ---
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS HIST_SAVE_NO_DUPS HIST_REDUCE_BLANKS SHARE_HISTORY
setopt INTERACTIVE_COMMENTS EXTENDED_GLOB
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history

# --- direnv ---
eval "$(direnv hook zsh)"

# --- PATH ---
path+=("$HOME/.local/bin")  # Used for uv

# --- Git aliases ---
alias gw='git worktree'

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

# --- Source bash profile ---
[[ -f ~/.bash_profile ]] && source ~/.bash_profile

. "$HOME/.local/bin/env"
