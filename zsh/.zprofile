# --- Homebrew ---
# Check standard installation paths and source shellenv if found
for _brew_prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
    if [[ -x "$_brew_prefix/bin/brew" ]]; then
        eval "$("$_brew_prefix/bin/brew" shellenv)"
        break
    fi
done
unset _brew_prefix

# --- Machine-local login configuration ---
[[ -f ~/.zprofile.local ]] && source ~/.zprofile.local
