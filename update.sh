#!/bin/bash

source "$(cd "$(dirname "$0")" && pwd)/common.sh"

printf '\n\e[34;1m%s\e[0m\n\n' "=== Dotfiles Update ($MACHINE) ===" 1>&2

# --- Update system packages ---
printf '\e[34m%s\e[0m\n' "Updating system packages (zsh, direnv)..." 1>&2
if [ "$MACHINE" = "MacOS" ]; then
    brew upgrade zsh lsd direnv starship
elif [ "$CAN_ROOT" = "true" ]; then
    if [ "$MACHINE" = "Ubuntu" ]; then
        apt-get update
        apt-get install --only-upgrade -y zsh direnv
    elif [ "$MACHINE" = "Arch" ]; then
        pacman -Syu --noconfirm zsh lsd direnv
    fi
else
    printf '\e[33m%s\e[0m\n' "Rootless mode: skipping system package updates" 1>&2
fi

# --- Update starship binary ---
if [ "$MACHINE" != "MacOS" ]; then
    printf '\e[34m%s\e[0m\n' "Updating starship..." 1>&2
    if [ "$CAN_ROOT" = "true" ]; then
        curl --proto '=https' --tlsv1.2 -fsSL https://starship.rs/install.sh | sh -s -- -y -v "$STARSHIP_VERSION"
    else
        run_as_user mkdir -p "$TARGET_HOME/.local/bin"
        curl --proto '=https' --tlsv1.2 -fsSL https://starship.rs/install.sh | sh -s -- -y -v "$STARSHIP_VERSION" -b "$TARGET_HOME/.local/bin"
    fi
fi

# --- Update lsd from GitHub releases (Ubuntu/Arch rootless; macOS/Arch-root handled above) ---
if [ "$MACHINE" = "Ubuntu" ] || { [ "$MACHINE" = "Arch" ] && [ "$CAN_ROOT" = "false" ]; }; then
    printf '\e[34m%s\e[0m\n' "Updating lsd..." 1>&2
    case "$(uname -m)" in
        x86_64)  LSD_ARCH=amd64; LSD_TRIPLE=x86_64-unknown-linux-gnu ;;
        aarch64) LSD_ARCH=arm64; LSD_TRIPLE=aarch64-unknown-linux-gnu ;;
        *)       LSD_ARCH=amd64; LSD_TRIPLE=x86_64-unknown-linux-gnu ;;
    esac
    if [ "$CAN_ROOT" = "true" ]; then
        LSD_DEB="lsd_${LSD_VERSION#v}_${LSD_ARCH}.deb"
        curl --proto '=https' --tlsv1.2 -fsSL -o "/tmp/$LSD_DEB" \
            "https://github.com/lsd-rs/lsd/releases/download/${LSD_VERSION}/${LSD_DEB}"
        dpkg -i "/tmp/$LSD_DEB"
        rm -f "/tmp/$LSD_DEB"
    else
        run_as_user mkdir -p "$TARGET_HOME/.local/bin"
        LSD_TAR="lsd-${LSD_VERSION}-${LSD_TRIPLE}.tar.gz"
        curl --proto '=https' --tlsv1.2 -fsSL -o "/tmp/$LSD_TAR" \
            "https://github.com/lsd-rs/lsd/releases/download/${LSD_VERSION}/${LSD_TAR}"
        tar -xf "/tmp/$LSD_TAR" -C /tmp
        install -m 755 "/tmp/lsd-${LSD_VERSION}-${LSD_TRIPLE}/lsd" "$TARGET_HOME/.local/bin/lsd"
        rm -rf "/tmp/$LSD_TAR" "/tmp/lsd-${LSD_VERSION}-${LSD_TRIPLE}"
    fi
fi

# --- Update fzf ---
printf '\e[34m%s\e[0m\n' "Updating fzf..." 1>&2
if [ -d "$TARGET_HOME/.fzf" ]; then
    run_as_user git -C "$TARGET_HOME/.fzf" fetch --tags
    run_as_user git -C "$TARGET_HOME/.fzf" checkout "$FZF_VERSION"
else
    run_as_user git clone --branch "$FZF_VERSION" --depth 1 https://github.com/junegunn/fzf.git "$TARGET_HOME/.fzf"
fi
run_as_user "$TARGET_HOME/.fzf/install" --bin

# --- Update uv + thefuck ---
printf '\e[34m%s\e[0m\n' "Updating uv..." 1>&2
# shellcheck disable=SC2016
run_as_user bash -c 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH" && uv self update'

printf '\e[34m%s\e[0m\n' "Updating thefuck..." 1>&2
# shellcheck disable=SC2016
run_as_user bash -c 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH" && uv tool upgrade thefuck'

# --- Update direnv (rootless only — system installs handled by package manager above) ---
if [ "$CAN_ROOT" = "false" ] && [ "$MACHINE" != "MacOS" ]; then
    printf '\e[34m%s\e[0m\n' "Updating direnv..." 1>&2
    run_as_user mkdir -p "$TARGET_HOME/.local/bin"
    case "$(uname -m)" in
        x86_64)  DIRENV_ARCH=amd64 ;;
        aarch64) DIRENV_ARCH=arm64 ;;
        *)       DIRENV_ARCH=amd64 ;;
    esac
    curl --proto '=https' --tlsv1.2 -fsSL -o "$TARGET_HOME/.local/bin/direnv" \
        "https://github.com/direnv/direnv/releases/download/${DIRENV_VERSION}/direnv.linux-${DIRENV_ARCH}"
    chmod +x "$TARGET_HOME/.local/bin/direnv"
fi

# --- Zimfw update/install/compile ---
printf '\e[34m%s\e[0m\n' "Updating zimfw modules..." 1>&2
run_as_user zsh -c "export ZIM_HOME=$TARGET_HOME/.zim; source \$ZIM_HOME/zimfw.zsh update"
run_as_user zsh -c "export ZIM_HOME=$TARGET_HOME/.zim; source \$ZIM_HOME/zimfw.zsh install"
run_as_user zsh -c "export ZIM_HOME=$TARGET_HOME/.zim; source \$ZIM_HOME/zimfw.zsh compile"

# Update and re-apply Catppuccin theme for fast-syntax-highlighting
printf '\e[34m%s\e[0m\n' "Updating fast-syntax-highlighting theme..." 1>&2
run_as_user mkdir -p "$TARGET_HOME/.config/fsh"
curl --proto '=https' --tlsv1.2 -fsSL -o "$TARGET_HOME/.config/fsh/catppuccin-macchiato.ini" \
    "https://raw.githubusercontent.com/catppuccin/zsh-fsh/${CATPPUCCIN_FSH_SHA}/themes/catppuccin-macchiato.ini"
run_as_user zsh -c "export ZIM_HOME=$TARGET_HOME/.zim; source \$ZIM_HOME/init.zsh; fast-theme XDG:catppuccin-macchiato" &>/dev/null || true

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

printf '\e[34m%s\e[0m\n' "Verifying lsd config symlinks..." 1>&2
for cfg in config.yaml colors.yaml; do
    link="$TARGET_HOME/.config/lsd/$cfg"
    target="$DOTFILES_DIR/zsh/lsd/$cfg"
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
