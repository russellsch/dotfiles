# shellcheck shell=bash
set -euo pipefail

# --- Resolve repo root ---
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR

# --- Environment detection ---
DOTFILES_CONTAINER="${DOTFILES_CONTAINER:-false}"
[ -f /.dockerenv ] && DOTFILES_CONTAINER=true
[ "${CODESPACES:-}" = "true" ] && DOTFILES_CONTAINER=true
[ "${REMOTE_CONTAINERS:-}" = "true" ] && DOTFILES_CONTAINER=true
[ -n "${container:-}" ] && DOTFILES_CONTAINER=true  # systemd-nspawn, podman

DOTFILES_INTERACTIVE="${DOTFILES_INTERACTIVE:-true}"
[ ! -t 0 ] && DOTFILES_INTERACTIVE=false

export DOTFILES_CONTAINER DOTFILES_INTERACTIVE

# --- OS detection (skip if already set, e.g. preserved through sudo) ---
if [ -z "${MACHINE:-}" ]; then
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

    # If this is a Linux system, detect the distro
    if [ "$machine" = "Linux" ]; then
        if [ -f /etc/os-release ]; then
            # shellcheck disable=SC1091
            . /etc/os-release
            case "${ID:-} ${ID_LIKE:-}" in
                *ubuntu*) machine=Ubuntu;;
                *arch*)   machine=Arch;;
                *)        unameOut="$(uname -v)"; machine="UNKNOWN:$unameOut";;
            esac
        else
            unameOut="$(uname -v)"
            case "$unameOut" in
                *Ubuntu*)    machine=Ubuntu;;
                *)           machine="UNKNOWN:$unameOut";;
            esac
        fi
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

    export MACHINE=$machine
fi

if [ "$MACHINE" = "Ubuntu" ] || [ "$MACHINE" = "MacOS" ] || [ "$MACHINE" = "Arch" ]; then
    :
else
    printf '\e[31;1m%s\e[0m\n' "Unsupported environment: '$MACHINE'" 1>&2
    exit 1
fi

# --- Detect whether root privileges are available ---
if [ "$(id -u)" -eq 0 ]; then
    CAN_ROOT=true
elif command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
    CAN_ROOT=true
else
    CAN_ROOT=false
fi
export CAN_ROOT

# --- Self-elevate to root if needed (not on macOS — Homebrew refuses root) ---
if [ "$(id -u)" -ne 0 ] && [ "$MACHINE" != "MacOS" ]; then
    if [ "$CAN_ROOT" = "true" ]; then
        printf '\e[34m%s\e[0m\n' "Root privileges required. Re-running with sudo..." 1>&2
        exec sudo --preserve-env=DOTFILES_CONTAINER,DOTFILES_INTERACTIVE,DOTFILES_SKIP_FONTS,DOTFILES_SKIP_CHSH,MACHINE "$0" "$@"
    else
        printf '\e[33m%s\e[0m\n' "No root privileges available — running in rootless mode (system packages must be pre-installed)" 1>&2
    fi
fi

# --- Derive target user and home (never rely on $HOME under sudo) ---
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

# --- Ensure user-local bin dirs are on PATH ---
# The uv installer (cargo-dist) may use ~/.cargo/bin; other tools use ~/.local/bin.
# Adding both here ensures tools are findable in child processes (e.g. zsh/install.sh)
# without relying on profile files that non-interactive shells don't source.
case ":$PATH:" in
    *":$TARGET_HOME/.local/bin:"*) ;;
    *) export PATH="$TARGET_HOME/.local/bin:$PATH" ;;
esac
case ":$PATH:" in
    *":$TARGET_HOME/.cargo/bin:"*) ;;
    *) export PATH="$TARGET_HOME/.cargo/bin:$PATH" ;;
esac

# --- Pinned dependency versions ---
STARSHIP_VERSION="v1.24.2"
FZF_VERSION="v0.68.0"
NERD_FONTS_VERSION="v3.4.0"
LSD_VERSION="v1.2.0"
CATPPUCCIN_FSH_SHA="a9bdf479f8982c4b83b5c5005c8231c6b3352e2a"  # catppuccin/zsh-fsh (2026-02-21)
DIRENV_VERSION="v2.35.0"
export STARSHIP_VERSION FZF_VERSION NERD_FONTS_VERSION LSD_VERSION CATPPUCCIN_FSH_SHA DIRENV_VERSION

# --- Helpers ---
# Helper: run a command as TARGET_USER (skips sudo when already that user)
# When sudo is needed, we use `env` to propagate PATH because sudo's
# secure_path resets it, hiding user-local tools (uv, starship, etc.)
# that live in ~/.local/bin or ~/.cargo/bin.
run_as_user() {
    if [ "$(id -u)" = "$(id -u "$TARGET_USER" 2>/dev/null)" ]; then
        "$@"
    else
        sudo -Hu "$TARGET_USER" env "PATH=$PATH" "$@"
    fi
}
export -f run_as_user

# Helper: run a command as root (uses sudo only when not already root)
run_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif [ "$CAN_ROOT" = "true" ]; then
        sudo "$@"
    else
        printf '\e[33m%s\e[0m\n' "Skipping (requires root): $*" 1>&2
        return 1
    fi
}
export -f run_as_root
