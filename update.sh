#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error when substituting.

# --- OS Detection (same pattern as install.sh) ---
unameOut="$(uname -s)"
case "$unameOut" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=MacOS;;
    *)          machine="UNKNOWN:$unameOut";;
esac

if [ "$machine" = "Linux" ]; then
    unameOut="$(uname -v)"
    case "$unameOut" in
        *Ubuntu*)    machine=Ubuntu;;
        *)           machine="UNKNOWN:$unameOut";;
    esac
fi

if [[ "$machine" == UNKNOWN:* ]]; then
    read -r -p "Unknown installation ($machine); Assume [U]buntu [M]acOS or [A]rch? " response
    case "$response" in
        [uU])  machine=Ubuntu;;
        [mM])  machine=MacOS;;
        [aA])  machine=Arch;;
        *)     printf '\e[31;1m%s\e[0m\n' "Unsupported environment: '$machine'" 1>&2; exit 1;;
    esac
fi

export MACHINE=$machine

# --- Self-elevate to root if needed (not on macOS — Homebrew refuses root) ---
if [ "$(id -u)" -ne 0 ] && [ "$MACHINE" != "MacOS" ]; then
    printf '\e[34m%s\e[0m\n' "Root privileges required. Re-running with sudo..." 1>&2
    exec sudo --preserve-env=MACHINE "$0" "$@"
fi

# --- Derive target user and home (same as install.sh) ---
if [ -n "${SUDO_USER:-}" ]; then
    TARGET_USER="$SUDO_USER"
    if command -v getent &>/dev/null; then
        TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
    else
        TARGET_HOME="$(dscl . -read /Users/"$TARGET_USER" NFSHomeDirectory | awk '{print $2}')"
    fi
else
    TARGET_USER="${USER:-root}"
    TARGET_HOME="${HOME:-/root}"
fi
export TARGET_USER TARGET_HOME

# --- Helpers ---
run_as_user() {
    if [ "$(id -u)" = "$(id -u "$TARGET_USER" 2>/dev/null)" ]; then
        "$@"
    else
        sudo -Hu "$TARGET_USER" "$@"
    fi
}

run_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

printf '\n\e[34;1m%s\e[0m\n\n' "=== Dotfiles Update ($MACHINE) ===" 1>&2

# --- Update system packages ---
printf '\e[34m%s\e[0m\n' "Updating system packages (zsh, lsd, direnv)..." 1>&2
if [ "$MACHINE" = "Ubuntu" ]; then
    apt-get update
    apt-get upgrade -y zsh lsd direnv
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
run_as_user git -C "$TARGET_HOME/.fzf" pull
run_as_user "$TARGET_HOME/.fzf/install" --bin

# --- Update uv + thefuck ---
printf '\e[34m%s\e[0m\n' "Updating uv..." 1>&2
run_as_user bash -c 'export PATH="$HOME/.local/bin:$PATH" && uv self update'

printf '\e[34m%s\e[0m\n' "Updating thefuck..." 1>&2
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
