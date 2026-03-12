# dotfiles

Dotfiles (and general environment setup) for clean OS ramp-up in a variety of contexts.

## Supported OSes
- Ubuntu (tested on 24.04)
- OS X (tested on OS X 26 Tahoe)


## Installing

`./install.sh`

The script will prompt for sudo automatically and install everything into the correct user home directory.

## Quickstart

Key shortcuts provided by fzf (via Zim):

| Shortcut | Action |
|---|---|
| `Ctrl-R` | Search command history |
| `Ctrl-T` | Find and insert a file path |
| `Alt-C` | cd into a directory |
| `Tab` | fzf-powered completion (fzf-tab) |

All use the Catppuccin Macchiato color theme.

## Devcontainers / Codespaces

The installer auto-detects container environments (Docker, Codespaces, devcontainers, systemd-nspawn, Podman) and adjusts its behavior:

- Skips interactive prompts (auto-accepts defaults)
- Skips Nerd Font installation (the host terminal provides fonts)
- `chsh` is attempted but failures are non-fatal

### VS Code devcontainer setup

Add to your VS Code user `settings.json`:

```json
{
  "dotfiles.repository": "YOUR_USER/dotfiles",
  "dotfiles.installCommand": "install.sh --unattended",
  "terminal.integrated.defaultProfile.linux": "zsh",
  "terminal.integrated.sendKeybindingsToShell": true
}
```

The `--unattended` flag forces non-interactive container mode (equivalent to `DOTFILES_CONTAINER=true DOTFILES_INTERACTIVE=false`). While the installer auto-detects containers, the explicit flag is more reliable since the devcontainer dotfiles install may run before all container env vars are available.

The terminal setting ensures VS Code opens zsh in containers. It only applies to Linux remotes and falls back silently if zsh isn't installed.
Additionally, sendKeybindingsToShell allows Alt+Arrow key bindings (word movement, autosuggestion partial accept) pass through to integrated terminal.

For GitHub Codespaces, configure the same under **Settings > Codespaces > Dotfiles** in your GitHub account.

### Non-root containers

The installer works in containers where the user does not have root or sudo. In this mode:

- System package installs (`apt-get`, `pacman`, `dpkg`) are skipped — **zsh, curl, and git must be pre-installed** in the container image
- Tools that normally install to system paths (starship, lsd, direnv) are installed to `~/.local/bin` instead
- `chsh` is automatically skipped
- Everything else (Zim, fzf, uv, thefuck, symlinks, themes) works normally

Example `devcontainer.json` for a non-root container:

```jsonc
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  // or for a custom image, ensure zsh + curl + git are installed:
  // "build": { "dockerfile": "Dockerfile" },

  "remoteUser": "vscode",

  "features": {
    // The common-utils feature installs zsh, curl, git, etc. and is
    // included by default in most devcontainer base images.
    // If your image doesn't have them, add this feature explicitly:
    "ghcr.io/devcontainers/features/common-utils:2": {
      "installZsh": true
    }
  }
}
```

The VS Code user settings shown above (`dotfiles.repository`, `dotfiles.installCommand`) are **user-level** — they apply automatically to all devcontainers you open without any per-project `devcontainer.json` changes.

### Environment variable overrides

All behavior can be overridden with env vars. These are checked before auto-detection, so an explicit value always wins.

| Variable | Default | Description |
|---|---|---|
| `DOTFILES_CONTAINER` | auto-detected | Set to `true` to force container mode |
| `DOTFILES_INTERACTIVE` | `true` (unless stdin is not a TTY) | Set to `false` to skip all prompts |
| `DOTFILES_SKIP_FONTS` | same as `DOTFILES_CONTAINER` | Set to `true` to skip Nerd Font installation |
| `DOTFILES_SKIP_CHSH` | `false` | Set to `true` to skip changing the default shell |

Examples:

```bash
# Skip only fonts on a regular host install
DOTFILES_SKIP_FONTS=true ./install.sh

# Fully non-interactive container-style install (equivalent to --unattended)
DOTFILES_CONTAINER=true DOTFILES_INTERACTIVE=false ./install.sh
```

## Updating

To update packages and tools used, as well as reload Zim FW and starship, run the `./update.sh` script.

## Machine-local zsh config

For per-machine customization without modifying tracked dotfiles:

| File | Purpose |
|---|---|
| `~/.zshenv.local` | Environment vars for all zsh sessions (login, scripts, etc.) |
| `~/.zshrc.local` | Interactive shell config (aliases, functions, prompts) |

These are sourced at the end of their respective files if they exist.
