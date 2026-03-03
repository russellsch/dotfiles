# Prevent Ubuntu's /etc/zsh/zshrc from calling compinit before Zim's completion module
skip_global_compinit=1

# ~/.local/bin houses user-local installs (uv, and starship/lsd/direnv in rootless mode)
# ~/.fzf/bin is where the fzf install script puts the binary (--bin mode)
# Both must be on PATH before Zim's fzf module and .zshrc's starship/direnv init
path=(~/.local/bin ~/.fzf/bin $path)
