#!/bin/bash

# --- Parse CLI flags ---
for arg in "$@"; do
    case "$arg" in
        --unattended)
            # Force non-interactive container mode (for devcontainer installCommand)
            export DOTFILES_CONTAINER=true
            export DOTFILES_INTERACTIVE=false
            ;;
    esac
done

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

# Feature flags — sensible defaults, all overridable
DOTFILES_SKIP_FONTS="${DOTFILES_SKIP_FONTS:-$DOTFILES_CONTAINER}"
DOTFILES_SKIP_CHSH="${DOTFILES_SKIP_CHSH:-false}"

# Force-skip operations that require root when running rootless
if [ "$CAN_ROOT" = "false" ]; then
    DOTFILES_SKIP_CHSH=true
fi
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
if [ "$MACHINE" = "MacOS" ]; then
    if ! command -v brew &>/dev/null; then
        # Homebrew/install pinned to 5838cadb (2026-02-19)
        /bin/bash -c "$(curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/Homebrew/install/5838cadbb2c7beb17c7dcdddb5f0dba6c4780feb/install.sh)" </dev/null
    fi
    brew install curl git
elif [ "$CAN_ROOT" = "true" ]; then
    if [ "$MACHINE" = "Ubuntu" ]; then
        apt-get update
        apt-get install curl git -y
    elif [ "$MACHINE" = "Arch" ]; then
        pacman -Sy --noconfirm
        pacman -S curl git --noconfirm
    fi
else
    printf '\e[33m%s\e[0m\n' "Rootless mode: skipping system package install (curl, git must be pre-installed)" 1>&2
fi

printf '\e[34m%s\e[0m\n' "Installing Dependency: uv ..." 1>&2
# Helper: source the cargo-dist env file from well-known install locations.
# This adds whichever directory the installer chose to PATH (handles /opt/bin
# in containers, CARGO_HOME overrides, etc.).
_source_uv_env() {
    for _uv_env in \
        "$TARGET_HOME/.local/bin/env" \
        "$TARGET_HOME/.cargo/bin/env" \
        "${CARGO_HOME:+$CARGO_HOME/bin/env}" \
        /opt/bin/env; do
        if [ -n "$_uv_env" ] && [ -f "$_uv_env" ]; then
            # shellcheck disable=SC1090
            . "$_uv_env"
            return 0
        fi
    done
    return 1
}
# Source early so an already-installed uv at a non-standard location (e.g.
# /opt/bin) is discovered before we download.  Using `command -v` (instead of
# run_as_user) avoids sudo resetting PATH and hiding the binary.
_source_uv_env || true
if [ -z "${UV_SKIP_INSTALL:-}" ] && ! command -v uv &>/dev/null; then
    # Download installer to a temp file instead of piping (curl|sh swallows errors)
    curl --proto '=https' --tlsv1.2 -LsSf -o /tmp/uv-installer.sh \
        https://github.com/astral-sh/uv/releases/download/0.10.2/uv-installer.sh
    run_as_user sh /tmp/uv-installer.sh
    rm -f /tmp/uv-installer.sh
    # Re-source to pick up the newly created env file
    _source_uv_env || true
fi
unset -f _source_uv_env
# Verify uv is available
if ! command -v uv &>/dev/null; then
    printf '\e[31;1m%s\e[0m\n' "ERROR: uv installation failed — uv not found on PATH" 1>&2
    printf '\e[31m%s\e[0m\n' "PATH=$PATH" 1>&2
    exit 1
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
