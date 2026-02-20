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
  "dotfiles.installCommand": "install.sh",
  "terminal.integrated.defaultProfile.linux": "zsh"
}
```

The terminal setting ensures VS Code opens zsh in containers. It only applies to Linux remotes and falls back silently if zsh isn't installed.

For GitHub Codespaces, configure the same under **Settings > Codespaces > Dotfiles** in your GitHub account.

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

# Fully non-interactive container-style install
DOTFILES_CONTAINER=true DOTFILES_INTERACTIVE=false ./install.sh
```

## Updating

To update packages and tools used, as well as reload Zim FW and starship, run the `./update.sh` script.
