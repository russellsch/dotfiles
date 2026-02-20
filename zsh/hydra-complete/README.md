# hydra-complete

Zim module that provides tab completion for [Hydra](https://hydra.cc/) CLIs in zsh.

## How it works

The module reads the `HYDRA_COMPLETE` environment variable (a space-separated list of Hydra CLI command names) and lazily registers bash-style completions for each one via a `precmd` hook. Completions are loaded once per command per shell session.

This pairs with [direnv](https://direnv.net/) — each project's `.envrc` sets `HYDRA_COMPLETE` to the relevant CLIs, and direnv automatically unsets it when you leave the directory.

## Setup

### 1. Add to `.zimrc`

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
