#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error when substituting.

# --- Environment detection ---
DOTFILES_CONTAINER="${DOTFILES_CONTAINER:-false}"
[ -f /.dockerenv ] && DOTFILES_CONTAINER=true
[ "${CODESPACES:-}" = "true" ] && DOTFILES_CONTAINER=true
[ "${REMOTE_CONTAINERS:-}" = "true" ] && DOTFILES_CONTAINER=true
[ -n "${container:-}" ] && DOTFILES_CONTAINER=true  # systemd-nspawn, podman

DOTFILES_INTERACTIVE="${DOTFILES_INTERACTIVE:-true}"
[ ! -t 0 ] && DOTFILES_INTERACTIVE=false

# Feature flags — sensible defaults, all overridable
DOTFILES_SKIP_FONTS="${DOTFILES_SKIP_FONTS:-$DOTFILES_CONTAINER}"
DOTFILES_SKIP_CHSH="${DOTFILES_SKIP_CHSH:-false}"

export DOTFILES_CONTAINER DOTFILES_INTERACTIVE DOTFILES_SKIP_FONTS DOTFILES_SKIP_CHSH

# Self-elevate to root if needed (not on macOS — Homebrew refuses root)
if [ "$(id -u)" -ne 0 ] && [ "$(uname -s)" != "Darwin" ]; then
    printf '\e[34m%s\e[0m\n' "Root privileges required. Re-running with sudo..." 1>&2
    exec sudo --preserve-env=DOTFILES_CONTAINER,DOTFILES_INTERACTIVE,DOTFILES_SKIP_FONTS,DOTFILES_SKIP_CHSH "$0" "$@"
fi

# Derive target user and home (never rely on $HOME under sudo)
if [ -n "${SUDO_USER:-}" ]; then
    TARGET_USER="$SUDO_USER"
    if command -v getent &>/dev/null; then
        TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
    else
        TARGET_HOME="$(dscl . -read /Users/"$TARGET_USER" NFSHomeDirectory | awk '{print $2}')"
    fi
else
    # Running as root without sudo (e.g. containers), or as normal user (macOS)
    TARGET_USER="${USER:-root}"
    TARGET_HOME="${HOME:-/root}"
fi
export TARGET_USER TARGET_HOME

# Helper: run a command as TARGET_USER (skips sudo when already that user)
run_as_user() {
    if [ "$(id -u)" = "$(id -u "$TARGET_USER" 2>/dev/null)" ]; then
        "$@"
    else
        sudo -Hu "$TARGET_USER" "$@"
    fi
}
export -f run_as_user

# Helper: run a command as root (uses sudo only when not already root)
run_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}
export -f run_as_root

# Confirm the user and home directory
printf '\e[34m%s\e[0m\n' "Installing for user $TARGET_USER with home directory $TARGET_HOME" 1>&2
if [ "$DOTFILES_INTERACTIVE" = "true" ]; then
    read -r -p "Is this correct? " response
    case "$response" in
        [yY])       ;;
        *)    exit 1;;
    esac
fi

# Get system type
unameOut="$(uname -s)"
case "$unameOut" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=MacOS;;
    *)          machine="UNKNOWN:$unameOut";;
esac

# If this is an unknown distro, ask user to override using Ubuntu or MacOS config
if [ "$machine" = "UNKNOWN:$unameOut" ]; then
    if [ "$DOTFILES_INTERACTIVE" = "true" ]; then
        read -r -p "Unknown installation ($machine); Assume [U]buntu [M]acOS or [A]rch? " response
        case "$response" in
            [uU])  machine=Ubuntu;;
            [mM])  machine=MacOS;;
            [aA])  machine=Arch;;
            *)                  ;;
        esac
    else
        printf '\e[33m%s\e[0m\n' "Unknown distro ($machine), defaulting to Ubuntu" 1>&2
        machine=Ubuntu
    fi
fi

# If this is a Linux system, check for Ubuntu vs unknown
if [ "$machine" = "Linux" ]; then
    unameOut="$(uname -v)"
    case "$unameOut" in
        *Ubuntu*)    machine=Ubuntu;;
        *)           machine="UNKNOWN:$unameOut";;
    esac
fi

# If this is an unknown distro, ask user to override using Ubuntu or MacOS config
if [ "$machine" = "UNKNOWN:$unameOut" ]; then
    if [ "$DOTFILES_INTERACTIVE" = "true" ]; then
        read -r -p "Unknown installation ($machine); Assume [U]buntu [M]acOS or [A]rch? " response
        case "$response" in
            [uU])  machine=Ubuntu;;
            [mM])  machine=MacOS;;
            [aA])  machine=Arch;;
            *)                  ;;
        esac
    else
        printf '\e[33m%s\e[0m\n' "Unknown distro ($machine), defaulting to Ubuntu" 1>&2
        machine=Ubuntu
    fi
fi


# If nothing matched, ask user to optionally override
export MACHINE=$machine

if [ "$MACHINE" = "Ubuntu" ] || [ "$MACHINE" = "MacOS" ] || [ "$MACHINE" = "Arch" ]; then
    printf '\e[34m%s\e[0m\n' "Installing on $MACHINE" 1>&2
else
    printf '\e[31;1m%s\e[0m\n' "Unsupported environment: '$MACHINE'" 1>&2
    exit 1
fi

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
(cd zsh ; ./install.sh)

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
