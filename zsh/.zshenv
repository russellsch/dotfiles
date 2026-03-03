# Prevent Ubuntu's /etc/zsh/zshrc from calling compinit before Zim's completion module
skip_global_compinit=1

# ~/.local/bin houses user-local installs (uv, and starship/lsd/direnv in rootless mode)
# ~/.cargo/bin is where the uv installer (cargo-dist) may place the uv binary
# $CARGO_HOME/bin handles containers that set CARGO_HOME to non-standard locations (e.g. /opt)
# ~/.fzf/bin is where the fzf install script puts the binary (--bin mode)
# All must be on PATH before Zim's fzf module and .zshrc's starship/direnv init
path=(~/.local/bin ~/.cargo/bin ~/.fzf/bin $path)
[[ -n "$CARGO_HOME" && "$CARGO_HOME" != ~/.cargo ]] && path=($CARGO_HOME/bin $path)
