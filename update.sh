#!/bin/bash

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

printf '\n\e[34;1m%s\e[0m\n\n' "=== Dotfiles Update ($MACHINE) ===" 1>&2

# --- Update system packages ---
printf '\e[34m%s\e[0m\n' "Updating system packages (zsh, lsd, direnv)..." 1>&2
if [ "$MACHINE" = "Ubuntu" ]; then
    apt-get update
    apt-get install --only-upgrade -y zsh lsd direnv
elif [ "$MACHINE" = "MacOS" ]; then
    brew upgrade zsh lsd direnv starship
elif [ "$MACHINE" = "Arch" ]; then
    pacman -Syu --noconfirm zsh lsd direnv
fi

# --- Update starship binary ---
if [ "$MACHINE" != "MacOS" ]; then
    printf '\e[34m%s\e[0m\n' "Updating starship..." 1>&2
    curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

# --- Update fzf ---
printf '\e[34m%s\e[0m\n' "Updating fzf..." 1>&2
if [ -d "$TARGET_HOME/.fzf" ]; then
    run_as_user git -C "$TARGET_HOME/.fzf" pull
else
    run_as_user git clone --depth 1 https://github.com/junegunn/fzf.git "$TARGET_HOME/.fzf"
fi
run_as_user "$TARGET_HOME/.fzf/install" --bin

# --- Update uv + thefuck ---
printf '\e[34m%s\e[0m\n' "Updating uv..." 1>&2
# shellcheck disable=SC2016
run_as_user bash -c 'export PATH="$HOME/.local/bin:$PATH" && uv self update'

printf '\e[34m%s\e[0m\n' "Updating thefuck..." 1>&2
# shellcheck disable=SC2016
run_as_user bash -c 'export PATH="$HOME/.local/bin:$PATH" && uv tool upgrade thefuck'

# --- Zimfw update/install/compile ---
printf '\e[34m%s\e[0m\n' "Updating zimfw modules..." 1>&2
run_as_user zsh -c "export ZIM_HOME=$TARGET_HOME/.zim; source \$ZIM_HOME/zimfw.zsh update"
run_as_user zsh -c "export ZIM_HOME=$TARGET_HOME/.zim; source \$ZIM_HOME/zimfw.zsh install"
run_as_user zsh -c "export ZIM_HOME=$TARGET_HOME/.zim; source \$ZIM_HOME/zimfw.zsh compile"

# --- Verify starship config symlinks ---
printf '\e[34m%s\e[0m\n' "Verifying starship config symlinks..." 1>&2
ok=true
for cfg in starship.toml starship-tty.toml; do
    link="$TARGET_HOME/.config/$cfg"
    target="$DOTFILES_DIR/zsh/$cfg"
    if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
        printf '  ✓ %s → %s\n' "$link" "$target" 1>&2
    else
        printf '  \e[33m✗ %s is not linked to %s\e[0m\n' "$link" "$target" 1>&2
        ok=false
    fi
done

printf '\e[34m%s\e[0m\n' "Starship version:" 1>&2
run_as_user starship --version 1>&2

# --- Done ---
if [ "$ok" = true ]; then
    printf '\n\e[32;1m%s\e[0m\n' "Update complete! Open a new shell to pick up any changes." 1>&2
else
    printf '\n\e[33;1m%s\e[0m\n' "Update complete, but some symlinks need attention. Re-run install.sh to fix." 1>&2
fi
