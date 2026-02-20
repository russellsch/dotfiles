#!/bin/bash

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

# Feature flags — sensible defaults, all overridable
DOTFILES_SKIP_FONTS="${DOTFILES_SKIP_FONTS:-$DOTFILES_CONTAINER}"
DOTFILES_SKIP_CHSH="${DOTFILES_SKIP_CHSH:-false}"
export DOTFILES_SKIP_FONTS DOTFILES_SKIP_CHSH

# Confirm the user and home directory
printf '\e[34m%s\e[0m\n' "Installing for user $TARGET_USER with home directory $TARGET_HOME" 1>&2
if [ "$DOTFILES_INTERACTIVE" = "true" ]; then
    read -r -p "Is this correct? " response
    case "$response" in
        [yY])       ;;
        *)    exit 1;;
    esac
fi

printf '\e[34m%s\e[0m\n' "Installing on $MACHINE" 1>&2

printf '\e[34m%s\e[0m\n' "Setting script permissions..." 1>&2
chmod +x ./*/install.sh

printf '\e[34m%s\e[0m\n' "Installing universal dependencies..." 1>&2
if [ "$MACHINE" = "Ubuntu" ]; then
    apt-get update
    apt-get install curl git -y
elif [ "$MACHINE" = "MacOS" ]; then
    if ! command -v brew &>/dev/null; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/null
    fi
    brew install curl git
elif [ "$MACHINE" = "Arch" ]; then
    pacman -Sy --noconfirm
    pacman -S curl git --noconfirm
fi

printf '\e[34m%s\e[0m\n' "Installing Dependency: uv ..." 1>&2
if [ -z "${UV_SKIP_INSTALL:-}" ] && ! run_as_user uv --version &>/dev/null; then
    run_as_user sh -c 'curl --proto "=https" --tlsv1.2 -LsSf https://github.com/astral-sh/uv/releases/download/0.10.2/uv-installer.sh | sh'
fi

# Setup zsh
(cd zsh || exit 1; ./install.sh)

# Setup vscode
# TODO


if [ "$DOTFILES_INTERACTIVE" = "true" ]; then
    if ! run_as_user git config user.name &>/dev/null || ! run_as_user git config user.email &>/dev/null; then
        printf '\e[34m%s\e[0m\n' "Setting global git user..." 1>&2
        read -r -p "Git user name: " git_name
        read -r -p "Git email: " git_email
        run_as_user git config --global user.name "$git_name"
        run_as_user git config --global user.email "$git_email"
    fi
fi

exit 0
