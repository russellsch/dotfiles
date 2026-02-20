#!/bin/bash

set -euo pipefail

ZSH_INSTALL_DIR=$(pwd)
export ZSH_INSTALL_DIR

printf '\n\e[34;1m%s\e[0m\n\n' "--------ZSH Installation--------" 1>&2

printf '\e[34m%s\e[0m\n' "Installing ZSH..." 1>&2
if [ "$MACHINE" = "Ubuntu" ]; then
    apt-get install zsh -y
elif [ "$MACHINE" = "MacOS" ]; then
    brew install zsh
elif [ "$MACHINE" = "Arch" ]; then
    pacman -S zsh --noconfirm
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
        NERD_FONTS_VERSION="v3.4.0"
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
else
    curl --proto '=https' --tlsv1.2 -fsSL https://starship.rs/install.sh | sh -s -- -y -v "$STARSHIP_VERSION"
fi

printf '\e[34m%s\e[0m\n' "Installing fzf (from GitHub)..." 1>&2
FZF_DIR="$TARGET_HOME/.fzf"
if [ ! -d "$FZF_DIR" ]; then
    run_as_user git clone --branch "$FZF_VERSION" --depth 1 https://github.com/junegunn/fzf.git "$FZF_DIR"
fi
run_as_user "$FZF_DIR/install" --bin

printf '\e[34m%s\e[0m\n' "Installing lsd (ls replacement)..." 1>&2
if [ "$MACHINE" = "Ubuntu" ]; then
    apt-get install lsd -y
elif [ "$MACHINE" = "MacOS" ]; then
    brew install lsd
elif [ "$MACHINE" = "Arch" ]; then
    pacman -S lsd --noconfirm
fi

printf '\e[34m%s\e[0m\n' "Installing thefuck..." 1>&2
# shellcheck disable=SC2016
run_as_user bash -c 'export PATH="$HOME/.local/bin:$PATH" && uv tool install thefuck'

printf '\e[34m%s\e[0m\n' "Installing direnv..." 1>&2
if [ "$MACHINE" = "Ubuntu" ]; then
    apt-get install direnv -y
elif [ "$MACHINE" = "MacOS" ]; then
    brew install direnv
elif [ "$MACHINE" = "Arch" ]; then
    pacman -S direnv --noconfirm
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

chown -R "$TARGET_USER":"$TARGET_USER" "$TARGET_HOME/.zim" 2>/dev/null || true

printf '\n\e[32;1m%s\e[0m\n' "Done! Restart your shell (logout may be required for zsh also)." 1>&2
