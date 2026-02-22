# hydra-complete

Zim module that provides tab completion and highlighting for [Hydra](https://hydra.cc/) CLIs in zsh.

## How it works

The module reads the `HYDRA_COMPLETE` environment variable (a space-separated list of Hydra CLI command names) and lazily registers bash-style completions for each one via a `precmd` hook. Completions are loaded once per command per shell session. When [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting) is detected, the hook also registers a chroma that highlights Hydra override syntax — prefix operators (`+`, `++`, `~`), config keys, `=`, typed values, and flags.

This pairs with [direnv](https://direnv.net/) — each project's `.envrc` sets `HYDRA_COMPLETE` to the relevant CLIs, and direnv automatically unsets it when you leave the directory.

## Optional: syntax highlighting

Syntax highlighting requires [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting) (f-sy-h). Without it, tab completion still works normally. To enable highlighting, add f-sy-h to your `.zimrc` — loading order doesn't matter since the chroma registration happens in a `precmd` hook.

## Setup

### 1. Add to `.zimrc`

**GitHub (for standalone use):**

```zsh
zmodule russelsch/dotfiles --root zsh/hydra-complete
```

**Local path (from within this dotfiles repo):**

```zsh
zmodule ${0:A:h}/hydra-complete
```

Then run `zimfw install`.

### 2. Set `HYDRA_COMPLETE` in your project's `.envrc`

```bash
export HYDRA_COMPLETE="my-hydra-cli"
```

For multiple CLIs:

```bash
export HYDRA_COMPLETE="train-cli convert-cli"
```

Then run `direnv allow` in the project directory.

### 3. Restart your shell

```bash
exec zsh
```

`cd` into the project and use `<TAB>` to complete config groups and values.
