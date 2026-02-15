# Prevent Ubuntu's /etc/zsh/zshrc from calling compinit before Zim's completion module
skip_global_compinit=1

# fzf is installed to ~/.fzf/bin by the install script (--bin mode)
# Must be on PATH before Zim's fzf module loads
path=(~/.fzf/bin $path)
