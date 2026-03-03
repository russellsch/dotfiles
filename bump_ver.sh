#!/bin/bash
# bump_ver.sh — Bump all pinned dependency versions to latest
set -euo pipefail
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

errors=0

# --- Helpers ---

fail() {
    printf '\e[31m  ERROR fetching %s\e[0m\n' "$1" >&2
    errors=$((errors + 1))
}

github_latest_release() {
    local repo="$1"
    curl --proto '=https' --tlsv1.2 -fsSL \
        "https://api.github.com/repos/${repo}/releases/latest" \
        | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
        | sed 's/.*:[[:space:]]*"//;s/"//'
}

github_latest_tag() {
    local repo="$1"
    curl --proto '=https' --tlsv1.2 -fsSL \
        "https://api.github.com/repos/${repo}/tags?per_page=1" \
        | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
        | sed 's/.*:[[:space:]]*"//;s/"//'
}

github_head_sha() {
    local repo="$1"
    git ls-remote "https://github.com/${repo}.git" HEAD | cut -f1
}

get_var() {
    local file="$1" var="$2"
    grep "^${var}=" "$file" | head -1 | sed "s/^${var}=\"//;s/\".*$//"
}

update_var() {
    local file="$1" var="$2" new_val="$3"
    sed -i "s/^${var}=\".*\"/${var}=\"${new_val}\"/" "$file"
}

update_sha() {
    local file="$1" old_sha="$2" new_sha="$3" date="$4"
    local old_short="${old_sha:0:8}" new_short="${new_sha:0:8}"
    sed -i "s/${old_sha}/${new_sha}/g" "$file"
    sed -i "s/pinned to ${old_short} ([0-9-]*)/pinned to ${new_short} (${date})/" "$file"
}

update_zimrc_tag() {
    local file="$1" module="$2" new_tag="$3"
    sed -i "s|\(zmodule ${module} --tag \)[^ ]*|\1${new_tag}|" "$file"
}

print_row() {
    local name="$1" old="$2" new="$3" extra="${4:-}"
    if [ "$old" = "$new" ]; then
        printf '  %-22s %-12s (up to date)\n' "$name" "$old"
    elif [ -n "$extra" ]; then
        printf '  %-22s %-12s → %-12s %s\n' "$name" "$old" "$new" "$extra"
    else
        printf '  %-22s %-12s → %s\n' "$name" "$old" "$new"
    fi
}

# --- Main ---

printf 'Bumping pinned dependency versions...\n\n'

today=$(date +%Y-%m-%d)

# 1. Version variables in common.sh

common="$DOTFILES_DIR/common.sh"

old_starship=$(get_var "$common" STARSHIP_VERSION)
old_fzf=$(get_var "$common" FZF_VERSION)
old_nerdfonts=$(get_var "$common" NERD_FONTS_VERSION)
old_lsd=$(get_var "$common" LSD_VERSION)
old_uv=$(get_var "$common" UV_VERSION)
old_direnv=$(get_var "$common" DIRENV_VERSION)

new_starship=$(github_latest_release "starship/starship")    || { fail "starship/starship";    new_starship=""; }
new_fzf=$(github_latest_release "junegunn/fzf")              || { fail "junegunn/fzf";         new_fzf=""; }
new_nerdfonts=$(github_latest_release "ryanoasis/nerd-fonts") || { fail "ryanoasis/nerd-fonts"; new_nerdfonts=""; }
new_lsd=$(github_latest_release "lsd-rs/lsd")                || { fail "lsd-rs/lsd";           new_lsd=""; }
new_uv=$(github_latest_release "astral-sh/uv")               || { fail "astral-sh/uv";         new_uv=""; }
new_direnv=$(github_latest_release "direnv/direnv")           || { fail "direnv/direnv";        new_direnv=""; }

if [ -n "$new_starship" ]; then update_var "$common" STARSHIP_VERSION "$new_starship"; fi
if [ -n "$new_fzf" ]; then update_var "$common" FZF_VERSION "$new_fzf"; fi
if [ -n "$new_nerdfonts" ]; then update_var "$common" NERD_FONTS_VERSION "$new_nerdfonts"; fi
if [ -n "$new_lsd" ]; then update_var "$common" LSD_VERSION "$new_lsd"; fi
# uv tags are bare versions (no v prefix) — strip it if present
if [ -n "$new_uv" ]; then update_var "$common" UV_VERSION "${new_uv#v}"; fi
if [ -n "$new_direnv" ]; then update_var "$common" DIRENV_VERSION "$new_direnv"; fi

print_row "starship"    "$old_starship"  "${new_starship:-FAILED}"
print_row "fzf"         "$old_fzf"       "${new_fzf:-FAILED}"
print_row "nerd-fonts"  "$old_nerdfonts" "${new_nerdfonts:-FAILED}"
print_row "lsd"         "$old_lsd"       "${new_lsd:-FAILED}"
print_row "uv"          "$old_uv"        "${new_uv:-FAILED}"
print_row "direnv"      "$old_direnv"    "${new_direnv:-FAILED}"

# 2. Homebrew installer SHA in install.sh

install_file="$DOTFILES_DIR/install.sh"

old_brew_sha=$(grep -o 'Homebrew/install/[a-f0-9]\{40\}' "$install_file" | head -1 | sed 's|Homebrew/install/||')
new_brew_sha=$(github_head_sha "Homebrew/install") || { fail "Homebrew/install"; new_brew_sha=""; }

if [ -n "$new_brew_sha" ]; then
    if [ "$old_brew_sha" != "$new_brew_sha" ]; then
        update_sha "$install_file" "$old_brew_sha" "$new_brew_sha" "$today"
    fi
    print_row "homebrew/install" "${old_brew_sha:0:7}" "${new_brew_sha:0:7}" "($today)"
else
    print_row "homebrew/install" "${old_brew_sha:0:7}" "FAILED"
fi

# 3. Zim installer SHA in zsh/install.sh

zsh_install="$DOTFILES_DIR/zsh/install.sh"

old_zim_sha=$(grep -o 'zimfw/install/[a-f0-9]\{40\}' "$zsh_install" | head -1 | sed 's|zimfw/install/||')
new_zim_sha=$(github_head_sha "zimfw/install") || { fail "zimfw/install"; new_zim_sha=""; }

if [ -n "$new_zim_sha" ]; then
    if [ "$old_zim_sha" != "$new_zim_sha" ]; then
        update_sha "$zsh_install" "$old_zim_sha" "$new_zim_sha" "$today"
    fi
    print_row "zimfw/install" "${old_zim_sha:0:7}" "${new_zim_sha:0:7}" "($today)"
else
    print_row "zimfw/install" "${old_zim_sha:0:7}" "FAILED"
fi

# 4. catppuccin/zsh-fsh SHA in common.sh

old_fsh_sha=$(get_var "$common" CATPPUCCIN_FSH_SHA)
new_fsh_sha=$(github_head_sha "catppuccin/zsh-fsh") || { fail "catppuccin/zsh-fsh"; new_fsh_sha=""; }

if [ -n "$new_fsh_sha" ]; then
    if [ "$old_fsh_sha" != "$new_fsh_sha" ]; then
        update_var "$common" CATPPUCCIN_FSH_SHA "$new_fsh_sha"
        # Update the inline date comment
        sed -i "s|catppuccin/zsh-fsh ([0-9-]*)|catppuccin/zsh-fsh (${today})|" "$common"
    fi
    print_row "catppuccin/zsh-fsh" "${old_fsh_sha:0:7}" "${new_fsh_sha:0:7}" "($today)"
else
    print_row "catppuccin/zsh-fsh" "${old_fsh_sha:0:7}" "FAILED"
fi

# 5. Zimrc module tags

zimrc="$DOTFILES_DIR/zsh/.zimrc"

bump_zimrc_module() {
    local display="$1" repo="$2"
    local old_tag new_tag

    old_tag=$(grep "zmodule ${repo}" "$zimrc" | grep -o -- '--tag [^ ]*' | sed 's/--tag //')

    new_tag=$(github_latest_release "$repo" 2>/dev/null) || new_tag=""
    if [ -z "$new_tag" ]; then
        new_tag=$(github_latest_tag "$repo" 2>/dev/null) || { fail "$repo"; new_tag=""; }
    fi

    if [ -n "$new_tag" ] && [ "$old_tag" != "$new_tag" ]; then
        update_zimrc_tag "$zimrc" "$repo" "$new_tag"
    fi
    print_row "$display" "$old_tag" "${new_tag:-FAILED}"
}

bump_zimrc_module "zim-alias-finder"    "shanwker1223/zim-alias-finder"
bump_zimrc_module "fzf-tab"             "Aloxaf/fzf-tab"
bump_zimrc_module "fast-syntax-high."   "zdharma-continuum/fast-syntax-highlighting"
bump_zimrc_module "zsh-autosuggestions" "zsh-users/zsh-autosuggestions"

# 6. Pre-commit hooks

if command -v pre-commit &>/dev/null; then
    printf '  %-22s %s\n' "pre-commit hooks" "(via pre-commit autoupdate --freeze)"
    (cd "$DOTFILES_DIR" && pre-commit autoupdate --freeze)
else
    printf '  %-22s %s\n' "pre-commit hooks" "(skipped — pre-commit not found)"
fi

# --- Done ---

printf '\nDone. Review changes with: git diff\n'

if [ "$errors" -gt 0 ]; then
    printf '\e[31m%d fetch failure(s) — re-run after checking connectivity.\e[0m\n' "$errors" >&2
    exit 1
fi
