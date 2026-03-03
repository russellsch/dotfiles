#!/bin/bash

set -euo pipefail

ZSH_INSTALL_DIR=$(pwd)
export ZSH_INSTALL_DIR

printf '\n\e[34;1m%s\e[0m\n\n' "--------ZSH Installation--------" 1>&2

printf '\e[34m%s\e[0m\n' "Installing ZSH..." 1>&2
if [ "$MACHINE" = "MacOS" ]; then
    brew install zsh
elif [ "$CAN_ROOT" = "true" ]; then
    if [ "$MACHINE" = "Ubuntu" ]; then
        apt-get install zsh -y
    elif [ "$MACHINE" = "Arch" ]; then
        pacman -S zsh --noconfirm
    fi
else
    if ! command -v zsh &>/dev/null; then
        printf '\e[31;1m%s\e[0m\n' "ERROR: zsh is not installed and cannot be installed without root. Install zsh in your container image." 1>&2
        exit 1
    fi
    printf '\e[33m%s\e[0m\n' "Rootless mode: using pre-installed zsh ($(which zsh))" 1>&2
fi

printf '\e[34m%s\e[0m\n' "Installing Dependency: Zim Framework..." 1>&2
if [ -d "$TARGET_HOME/.zim" ]; then
    printf '\e[33m%s\e[0m\n' "Zim Framework already installed, skipping..." 1>&2
else
    # zimfw/install pinned to 55a2a28d (2026-02-19)
    run_as_user zsh -c "$(curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/zimfw/install/55a2a28dfef53b9a12a16e38279f662363229c69/install.zsh)"
fi


# --- Nerd Fonts ---
if [ "$DOTFILES_SKIP_FONTS" != "true" ]; then
    FONT_DIR="$TARGET_HOME/.local/share/fonts"
    printf '\e[34m%s\e[0m\n' "Installing Nerd Fonts (FiraCode, DroidSansMono)..." 1>&2
    if [ "$MACHINE" = "Ubuntu" ]; then
        run_as_user mkdir -p "$FONT_DIR"
        for font in FiraCode DroidSansMono; do
            curl --proto '=https' --tlsv1.2 -fsSL -o "/tmp/${font}.tar.xz" \
                "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/${font}.tar.xz"
            run_as_user tar -xf "/tmp/${font}.tar.xz" -C "$FONT_DIR"
            rm "/tmp/${font}.tar.xz"
        done
        fc-cache -f
    elif [ "$MACHINE" = "MacOS" ]; then
        brew install --cask font-fira-code-nerd-font font-droid-sans-mono-nerd-font
    elif [ "$MACHINE" = "Arch" ]; then
        pacman -S ttf-firacode-nerd ttf-droid --noconfirm
    fi
else
    printf '\e[33m%s\e[0m\n' "Skipping Nerd Fonts (DOTFILES_SKIP_FONTS=true)" 1>&2
fi

printf '\e[34m%s\e[0m\n' "Installing Dependency: Starship..." 1>&2
if [ "$MACHINE" = "MacOS" ]; then
    brew install starship
elif [ "$CAN_ROOT" = "true" ]; then
    curl --proto '=https' --tlsv1.2 -fsSL https://starship.rs/install.sh | sh -s -- -y -v "$STARSHIP_VERSION"
else
    run_as_user mkdir -p "$TARGET_HOME/.local/bin"
    curl --proto '=https' --tlsv1.2 -fsSL https://starship.rs/install.sh | sh -s -- -y -v "$STARSHIP_VERSION" -b "$TARGET_HOME/.local/bin"
fi

printf '\e[34m%s\e[0m\n' "Installing fzf (from GitHub)..." 1>&2
FZF_DIR="$TARGET_HOME/.fzf"
if [ ! -d "$FZF_DIR" ]; then
    run_as_user git clone --branch "$FZF_VERSION" --depth 1 https://github.com/junegunn/fzf.git "$FZF_DIR"
fi
run_as_user "$FZF_DIR/install" --bin

printf '\e[34m%s\e[0m\n' "Installing lsd (ls replacement)..." 1>&2
if [ "$MACHINE" = "MacOS" ]; then
    brew install lsd
elif [ "$MACHINE" = "Ubuntu" ] || [ "$MACHINE" = "Arch" ]; then
    case "$(uname -m)" in
        x86_64)  LSD_ARCH=amd64; LSD_TRIPLE=x86_64-unknown-linux-gnu ;;
        aarch64) LSD_ARCH=arm64; LSD_TRIPLE=aarch64-unknown-linux-gnu ;;
        *)       LSD_ARCH=amd64; LSD_TRIPLE=x86_64-unknown-linux-gnu ;;
    esac
    if [ "$CAN_ROOT" = "true" ]; then
        if [ "$MACHINE" = "Arch" ]; then
            pacman -S lsd --noconfirm  # Arch repos have recent versions
        else
            # Install from GitHub releases for hex color support (requires >=1.1.0)
            LSD_DEB="lsd_${LSD_VERSION#v}_${LSD_ARCH}.deb"
            curl --proto '=https' --tlsv1.2 -fsSL -o "/tmp/$LSD_DEB" \
                "https://github.com/lsd-rs/lsd/releases/download/${LSD_VERSION}/${LSD_DEB}"
            dpkg -i "/tmp/$LSD_DEB"
            rm -f "/tmp/$LSD_DEB"
        fi
    else
        # Rootless: install binary to user directory from tar.gz
        run_as_user mkdir -p "$TARGET_HOME/.local/bin"
        LSD_TAR="lsd-${LSD_VERSION}-${LSD_TRIPLE}.tar.gz"
        curl --proto '=https' --tlsv1.2 -fsSL -o "/tmp/$LSD_TAR" \
            "https://github.com/lsd-rs/lsd/releases/download/${LSD_VERSION}/${LSD_TAR}"
        tar -xf "/tmp/$LSD_TAR" -C /tmp
        install -m 755 "/tmp/lsd-${LSD_VERSION}-${LSD_TRIPLE}/lsd" "$TARGET_HOME/.local/bin/lsd"
        rm -rf "/tmp/$LSD_TAR" "/tmp/lsd-${LSD_VERSION}-${LSD_TRIPLE}"
    fi
fi

printf '\e[34m%s\e[0m\n' "Installing thefuck..." 1>&2
# shellcheck disable=SC2016
run_as_user bash -c 'export PATH="$HOME/.local/bin:$PATH" && uv tool install thefuck'

printf '\e[34m%s\e[0m\n' "Installing direnv..." 1>&2
if [ "$MACHINE" = "MacOS" ]; then
    brew install direnv
elif [ "$CAN_ROOT" = "true" ]; then
    if [ "$MACHINE" = "Ubuntu" ]; then
        apt-get install direnv -y
    elif [ "$MACHINE" = "Arch" ]; then
        pacman -S direnv --noconfirm
    fi
else
    # Rootless: install binary to user directory from GitHub
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


printf '\e[34m%s\e[0m\n' "Creating links..." 1>&2
ln -sfn "$ZSH_INSTALL_DIR/.zshenv" "$TARGET_HOME/.zshenv"
ln -sfn "$ZSH_INSTALL_DIR/.zshrc" "$TARGET_HOME/.zshrc"
ln -sfn "$ZSH_INSTALL_DIR/.zimrc" "$TARGET_HOME/.zimrc"

# Create starship config dir and link if config exists
if [ -f "$ZSH_INSTALL_DIR/starship.toml" ]; then
    run_as_user mkdir -p "$TARGET_HOME/.config"
    ln -sfn "$ZSH_INSTALL_DIR/starship.toml" "$TARGET_HOME/.config/starship.toml"
fi
if [ -f "$ZSH_INSTALL_DIR/starship-tty.toml" ]; then
    run_as_user mkdir -p "$TARGET_HOME/.config"
    ln -sfn "$ZSH_INSTALL_DIR/starship-tty.toml" "$TARGET_HOME/.config/starship-tty.toml"
fi

# Create lsd config dir and link theme files
run_as_user mkdir -p "$TARGET_HOME/.config/lsd"
ln -sfn "$ZSH_INSTALL_DIR/lsd/config.yaml" "$TARGET_HOME/.config/lsd/config.yaml"
ln -sfn "$ZSH_INSTALL_DIR/lsd/colors.yaml" "$TARGET_HOME/.config/lsd/colors.yaml"

# Download Catppuccin theme for fast-syntax-highlighting
run_as_user mkdir -p "$TARGET_HOME/.config/fsh"
curl --proto '=https' --tlsv1.2 -fsSL -o "$TARGET_HOME/.config/fsh/catppuccin-macchiato.ini" \
    "https://raw.githubusercontent.com/catppuccin/zsh-fsh/${CATPPUCCIN_FSH_SHA}/themes/catppuccin-macchiato.ini"

# --- Set default shell ---
if [ "$DOTFILES_SKIP_CHSH" != "true" ]; then
    if [ "$MACHINE" = "MacOS" ]; then
        which zsh | run_as_root tee -a /etc/shells > /dev/null
    fi
    printf '\e[34m%s\e[0m\n' "Updating shell..." 1>&2
    if ! run_as_root chsh -s "$(which zsh)" "$TARGET_USER" 2>/dev/null; then
        printf '\e[33m%s\e[0m\n' "chsh failed (non-fatal) — set SHELL manually or use DOTFILES_SKIP_CHSH=true" 1>&2
    fi
else
    printf '\e[33m%s\e[0m\n' "Skipping chsh (DOTFILES_SKIP_CHSH=true)" 1>&2
fi

# --- Install zimfw plugins ---
printf '\e[34m%s\e[0m\n' "Installing zsh plugins via zimfw..." 1>&2
run_as_user zsh -c "export ZIM_HOME=$TARGET_HOME/.zim; source \$ZIM_HOME/zimfw.zsh install"

if [ "$(id -u)" -ne "$(id -u "$TARGET_USER" 2>/dev/null)" ]; then
    chown -R "$TARGET_USER":"$TARGET_USER" "$TARGET_HOME/.zim" 2>/dev/null || true
fi

# --- Activate Catppuccin theme for fast-syntax-highlighting ---
printf '\e[34m%s\e[0m\n' "Activating fast-syntax-highlighting theme..." 1>&2
run_as_user zsh -c "export ZIM_HOME=$TARGET_HOME/.zim; source \$ZIM_HOME/init.zsh; fast-theme XDG:catppuccin-macchiato" &>/dev/null || true

printf '\n\e[32;1m%s\e[0m\n' "Done! Restart your shell (logout may be required for zsh also)." 1>&2
