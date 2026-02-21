# Hydra tab completion driven by HYDRA_COMPLETE env var (set via direnv)
# Usage: export HYDRA_COMPLETE="svml-train other-cli" in .envrc

autoload -Uz bashcompinit && bashcompinit

typeset -ga _hydra_complete_loaded=()

# Source the f-sy-h chroma for Hydra override grammar highlighting
source "${0:A:h}/chroma-hydra-override.ch"
typeset -ga _hydra_chroma_registered=()

_hydra_complete_hook() {
    [[ -z "$HYDRA_COMPLETE" ]] && return
    local cmd
    for cmd in ${(s: :)HYDRA_COMPLETE}; do
        # Tab completion (existing logic)
        if ! (( ${_hydra_complete_loaded[(Ie)$cmd]} )); then
            if command -v "$cmd" &>/dev/null; then
                eval "$($cmd -sc install=bash 2>/dev/null)" && _hydra_complete_loaded+=("$cmd")
            fi
        fi

        # Syntax highlighting chroma registration (requires f-sy-h)
        if (( ${+FAST_HIGHLIGHT} )) && ! (( ${_hydra_chroma_registered[(Ie)$cmd]} )); then
            FAST_HIGHLIGHT[chroma-$cmd]=chroma/-hydra-override
            _hydra_chroma_registered+=("$cmd")
        fi
    done
}

autoload -Uz add-zsh-hook && add-zsh-hook precmd _hydra_complete_hook
