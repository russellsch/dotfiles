# Hydra tab completion driven by HYDRA_COMPLETE env var (set via direnv)
# Usage: export HYDRA_COMPLETE="svml-train other-cli" in .envrc

autoload -Uz bashcompinit && bashcompinit

typeset -ga _hydra_complete_loaded=()

_hydra_complete_hook() {
    [[ -z "$HYDRA_COMPLETE" ]] && return
    local cmd
    for cmd in ${(s: :)HYDRA_COMPLETE}; do
        (( ${_hydra_complete_loaded[(Ie)$cmd]} )) && continue
        if command -v "$cmd" &>/dev/null; then
            eval "$($cmd -sc install=bash 2>/dev/null)" && _hydra_complete_loaded+=("$cmd")
        fi
    done
}

autoload -Uz add-zsh-hook && add-zsh-hook precmd _hydra_complete_hook
