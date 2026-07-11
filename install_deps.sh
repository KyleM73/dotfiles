#!/usr/bin/env bash
# install_deps.sh — install the CLI tools the nvim / zellij / yazi setup uses.
#
#   * Idempotent  : skips anything already on your PATH; safe to re-run.
#   * Best-effort : warns and keeps going if one tool can't be installed.
#   * Portable    : Homebrew on macOS; on Linux the native package manager
#                   (apt/dnf/pacman/zypper/apk) for well-packaged tools.
#
# Homebrew is NOT required on Linux — only used if it happens to be present.
# Some tools are special on Linux because the distro packages are missing or
# too old, so they're installed from OFFICIAL PREBUILT RELEASES into ~/.local
# (no root, no compiler needed):
#     neovim  — apt ships < 0.11; the Python LSP needs the native vim.lsp API
#     fzf     — apt ships < 0.48; the shell keybindings need `fzf --bash/--zsh`
#     zellij, yazi, lazygit, glow — not packaged on Debian/Ubuntu
#     zoxide, ripgrep, bat, fd — distro versions lag years; upgraded when old
# Python tools (ruff, ty) always go through uv (no brew, no root).
#
# Usage:
#   ./install_deps.sh            install everything that's missing
#   DRY_RUN=1 ./install_deps.sh  print what WOULD happen, change nothing
#   (run automatically by make_symlinks.sh unless SKIP_DEPS=1)

set -u

DRY_RUN="${DRY_RUN:-0}"
OS="$(uname -s)"
ARCH="$(uname -m)"
LOCAL_BIN="$HOME/.local/bin"
[ "$DRY_RUN" = "1" ] || mkdir -p "$LOCAL_BIN"
# Ensure ~/.local/bin wins on PATH for this run (where release binaries land).
case ":$PATH:" in *":$LOCAL_BIN:"*) ;; *) PATH="$LOCAL_BIN:$PATH"; export PATH ;; esac

run() {  # execute a command, or just echo it in dry-run mode
    if [ "$DRY_RUN" = "1" ]; then echo "    [dry-run] $*"; return 0; fi
    "$@"
}

# ---- detect package manager + privilege escalation -------------------------
PM=""
for c in brew apt-get dnf pacman zypper apk; do
    command -v "$c" >/dev/null 2>&1 && { PM="$c"; break; }
done
PM="${PM_OVERRIDE:-$PM}"   # PM_OVERRIDE lets you test another manager's path
SUDO=""
PM_USABLE=1
if [ "$PM" != "brew" ] && [ -n "$PM" ] && [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        PM_USABLE=0   # non-root and no sudo binary: the PM can't work at all
    fi
fi

echo "OS: $OS ($ARCH)   package manager: ${PM:-none}"
if [ "$OS" = "Darwin" ] && [ "$PM" != "brew" ]; then
    echo "  ! No Homebrew on macOS. Install it first: https://brew.sh"
fi

# Can we actually use the system package manager? brew never needs sudo; the
# Linux managers do. Prime sudo ONCE (so you're prompted a single time, not per
# package) and, if it's unavailable non-interactively, skip those installs with
# one clear message instead of erroring on every package. Tools that don't need
# root (the prebuilt releases, uv) are installed regardless.
if [ -n "$SUDO" ] && [ "$DRY_RUN" != "1" ]; then
    if sudo -n true 2>/dev/null; then
        :   # passwordless sudo already available
    elif [ -t 0 ]; then
        echo "  (some packages need sudo — you may be prompted once)"
        sudo -v 2>/dev/null || PM_USABLE=0
    else
        PM_USABLE=0
    fi
fi
if [ "$PM_USABLE" != "1" ]; then
    echo "  ! no root/sudo available — skipping $PM packages"
    echo "    (ripgrep and the preview tools need it; the release installs still run)"
fi

[ "$PM" = "apt-get" ] && [ "$PM_USABLE" = "1" ] && run $SUDO apt-get update -qq

pm_install() {  # pm_install <pkg...>
    [ "${PM_USABLE:-1}" = "1" ] || return 1
    case "$PM" in
        brew)    run brew install "$@" ;;
        apt-get) run $SUDO apt-get install -y "$@" ;;
        dnf)     run $SUDO dnf install -y "$@" ;;
        pacman)  run $SUDO pacman -S --needed --noconfirm "$@" ;;
        zypper)  run $SUDO zypper install -y "$@" ;;
        apk)     run $SUDO apk add "$@" ;;
        *)       return 1 ;;
    esac
}

pkg_for() {  # package name for the detected manager (defaults to the tool name)
    local t="$1"
    case "$PM" in
        apt-get) case "$t" in
            fd) echo fd-find ;; poppler) echo poppler-utils ;;
            7zip) echo p7zip-full ;; *) echo "$t" ;; esac ;;
        dnf) case "$t" in
            fd) echo fd-find ;; poppler) echo poppler-utils ;;
            7zip) echo p7zip ;; imagemagick) echo ImageMagick ;; *) echo "$t" ;; esac ;;
        brew) case "$t" in 7zip) echo sevenzip ;; *) echo "$t" ;; esac ;;
        pacman) case "$t" in 7zip) echo p7zip ;; *) echo "$t" ;; esac ;;
        zypper) case "$t" in
            7zip) echo p7zip ;; imagemagick) echo ImageMagick ;; *) echo "$t" ;; esac ;;
        apk) case "$t" in
            7zip) echo p7zip ;; poppler) echo poppler-utils ;; *) echo "$t" ;; esac ;;
        *) echo "" ;;
    esac
}

# ---- download helper -------------------------------------------------------
have_dl() { command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; }
dl() {  # dl <url> <outfile>
    if command -v curl >/dev/null 2>&1; then run curl -fSL "$1" -o "$2"
    else run wget -qO "$2" "$1"; fi
}

# Map uname -m to the arch token each project uses in its release asset names.
std_arch()   { case "$ARCH" in x86_64|amd64) echo x86_64 ;; aarch64|arm64) echo arm64 ;; *) echo "" ;; esac; }   # nvim, lazygit, glow
rust_arch()  { case "$ARCH" in x86_64|amd64) echo x86_64 ;; aarch64|arm64) echo aarch64 ;; *) echo "" ;; esac; } # zellij, yazi
go_arch()    { case "$ARCH" in x86_64|amd64) echo amd64 ;; aarch64|arm64) echo arm64 ;; *) echo "" ;; esac; }    # fzf

# Latest release tag of a GitHub repo WITHOUT the rate-limited API (60 req/hr
# per IP): follow the /releases/latest redirect and read the tag off the URL.
github_latest_tag() {  # github_latest_tag <owner/repo>  ->  e.g. "v1.2.3"
    local tag
    command -v curl >/dev/null 2>&1 || return 1
    tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest" 2>/dev/null | sed 's#.*/##')"
    case "$tag" in ""|latest|releases) return 1 ;; *) echo "$tag" ;; esac
}

install_nvim_release() {
    local a os url tmp dir
    a="$(std_arch)"; [ -z "$a" ] && { echo "  ! neovim: unsupported arch $ARCH"; return 1; }
    if [ "$OS" = "Darwin" ]; then os=macos; else os=linux; fi
    url="https://github.com/neovim/neovim/releases/latest/download/nvim-${os}-${a}.tar.gz"
    echo "  → neovim     prebuilt release ($os-$a) -> ~/.local"
    if [ "$DRY_RUN" = "1" ]; then echo "    [dry-run] dl $url; tar -C ~/.local; ln -s nvim -> $LOCAL_BIN"; return 0; fi
    have_dl || { echo "  ! neovim: need curl or wget"; return 1; }
    tmp="$(mktemp -d)"
    dl "$url" "$tmp/nvim.tar.gz" || { rm -rf "$tmp"; return 1; }
    mkdir -p "$HOME/.local"
    tar -xzf "$tmp/nvim.tar.gz" -C "$HOME/.local" || { rm -rf "$tmp"; return 1; }
    dir="$HOME/.local/nvim-${os}-${a}"
    ln -sf "$dir/bin/nvim" "$LOCAL_BIN/nvim"
    rm -rf "$tmp"
}

install_zellij_release() {
    local a triple url tmp
    a="$(rust_arch)"; [ -z "$a" ] && { echo "  ! zellij: unsupported arch $ARCH"; return 1; }
    if [ "$OS" = "Darwin" ]; then triple="${a}-apple-darwin"; else triple="${a}-unknown-linux-musl"; fi
    url="https://github.com/zellij-org/zellij/releases/latest/download/zellij-${triple}.tar.gz"
    echo "  → zellij     prebuilt release ($triple) -> $LOCAL_BIN"
    if [ "$DRY_RUN" = "1" ]; then echo "    [dry-run] dl $url; tar; cp zellij -> $LOCAL_BIN"; return 0; fi
    have_dl || { echo "  ! zellij: need curl or wget"; return 1; }
    tmp="$(mktemp -d)"
    dl "$url" "$tmp/z.tar.gz" || { rm -rf "$tmp"; return 1; }
    tar -xzf "$tmp/z.tar.gz" -C "$tmp" || { rm -rf "$tmp"; return 1; }
    install -m 0755 "$tmp/zellij" "$LOCAL_BIN/zellij" || { rm -rf "$tmp"; return 1; }
    rm -rf "$tmp"
}

install_yazi_release() {
    local a triple url tmp sub
    a="$(rust_arch)"; [ -z "$a" ] && { echo "  ! yazi: unsupported arch $ARCH"; return 1; }
    if [ "$OS" = "Darwin" ]; then triple="${a}-apple-darwin"; else triple="${a}-unknown-linux-musl"; fi
    url="https://github.com/sxyazi/yazi/releases/latest/download/yazi-${triple}.zip"
    echo "  → yazi       prebuilt release ($triple) -> $LOCAL_BIN"
    if [ "$DRY_RUN" = "1" ]; then echo "    [dry-run] dl $url; unzip; cp yazi,ya -> $LOCAL_BIN"; return 0; fi
    have_dl || { echo "  ! yazi: need curl or wget"; return 1; }
    command -v unzip >/dev/null 2>&1 || pm_install unzip
    tmp="$(mktemp -d)"
    dl "$url" "$tmp/yazi.zip" || { rm -rf "$tmp"; return 1; }
    unzip -q "$tmp/yazi.zip" -d "$tmp" || { rm -rf "$tmp"; return 1; }
    sub="$tmp/yazi-${triple}"
    install -m 0755 "$sub/yazi" "$LOCAL_BIN/yazi" 2>/dev/null
    install -m 0755 "$sub/ya"   "$LOCAL_BIN/ya"   2>/dev/null
    rm -rf "$tmp"
    command -v yazi >/dev/null 2>&1
}

font_present() {  # is Hack Nerd Font already installed?
    if command -v fc-list >/dev/null 2>&1; then
        fc-list 2>/dev/null | grep -qi "Hack Nerd Font"
    else
        ls "$HOME/Library/Fonts" /Library/Fonts "$HOME/.local/share/fonts" 2>/dev/null | grep -qi "HackNerdFont"
    fi
}

install_nerdfont_release() {  # download Hack Nerd Font (no root)
    local url dest tmp
    url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip"
    # macOS (CoreText) only scans ~/Library/Fonts; fontconfig Linux scans
    # ~/.local/share/fonts. Installing to the wrong one = invisible font.
    if [ "$OS" = "Darwin" ]; then
        dest="$HOME/Library/Fonts/HackNerdFont"
    else
        dest="$HOME/.local/share/fonts/HackNerdFont"
    fi
    echo "  → Hack Nerd Font -> $dest"
    if [ "$DRY_RUN" = "1" ]; then echo "    [dry-run] dl $url; unzip into $dest; fc-cache -f"; return 0; fi
    have_dl || { echo "  ! need curl or wget"; return 1; }
    command -v unzip >/dev/null 2>&1 || pm_install unzip
    mkdir -p "$dest"; tmp="$(mktemp -d)"
    dl "$url" "$tmp/Hack.zip" || { rm -rf "$tmp"; return 1; }
    unzip -qo "$tmp/Hack.zip" -d "$dest" || { rm -rf "$tmp"; return 1; }
    command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$(dirname "$dest")" >/dev/null 2>&1
    rm -rf "$tmp"
}

# goreleaser-style projects (lazygit, glow) name assets <bin>_<ver>_<Os>_<arch>.tar.gz
# with the version embedded, so resolve the latest tag first (via the redirect).
install_goreleaser_release() {  # install_goreleaser_release <owner/repo> <bin>
    local repo="$1" bin="$2" a os tag ver tmp path
    a="$(std_arch)"; [ -z "$a" ] && { echo "  ! $bin: unsupported arch $ARCH"; return 1; }
    if [ "$OS" = "Darwin" ]; then os="Darwin"; else os="Linux"; fi
    printf '  → %-10s prebuilt release (%s %s) -> %s\n' "$bin" "$os" "$a" "$LOCAL_BIN"
    if [ "$DRY_RUN" = "1" ]; then echo "    [dry-run] resolve latest tag; dl ${bin}_<ver>_${os}_${a}.tar.gz; cp $bin -> $LOCAL_BIN"; return 0; fi
    tag="$(github_latest_tag "$repo")" || { echo "  ! $bin: could not resolve latest version (need curl + github.com)"; return 1; }
    ver="${tag#v}"
    tmp="$(mktemp -d)"
    dl "https://github.com/${repo}/releases/download/${tag}/${bin}_${ver}_${os}_${a}.tar.gz" "$tmp/$bin.tar.gz" || { rm -rf "$tmp"; return 1; }
    tar -xzf "$tmp/$bin.tar.gz" -C "$tmp" || { rm -rf "$tmp"; return 1; }
    # Binary may be at the top level (lazygit) or in a versioned dir (glow).
    path="$(find "$tmp" -type f -name "$bin" | head -1)"
    [ -z "$path" ] && { rm -rf "$tmp"; return 1; }
    install -m 0755 "$path" "$LOCAL_BIN/$bin" || { rm -rf "$tmp"; return 1; }
    rm -rf "$tmp"
    command -v "$bin" >/dev/null 2>&1
}
install_lazygit_release() { install_goreleaser_release jesseduffield/lazygit lazygit; }
install_glow_release()    { install_goreleaser_release charmbracelet/glow    glow; }

# rust-style projects (zoxide, ripgrep, bat, fd) name assets
# <prefix>-[v]<ver>-<rust-triple>.tar.gz; the binary is often in a nested dir.
# x86_64 Linux builds are musl everywhere; aarch64 varies per project.
install_rust_release() {  # install_rust_release <owner/repo> <asset-prefix> <bin> <vprefix:v|""> <aarch64-libc:musl|gnu>
    local repo="$1" prefix="$2" bin="$3" vp="$4" a64libc="${5:-musl}" a triple tag ver tmp path
    a="$(rust_arch)"; [ -z "$a" ] && { echo "  ! $bin: unsupported arch $ARCH"; return 1; }
    if [ "$OS" = "Darwin" ]; then
        triple="${a}-apple-darwin"
    elif [ "$a" = "aarch64" ]; then
        triple="aarch64-unknown-linux-${a64libc}"
    else
        triple="x86_64-unknown-linux-musl"
    fi
    printf '  → %-10s prebuilt release (%s) -> %s\n' "$bin" "$triple" "$LOCAL_BIN"
    if [ "$DRY_RUN" = "1" ]; then echo "    [dry-run] resolve latest tag; dl ${prefix}-${vp}<ver>-${triple}.tar.gz; cp $bin -> $LOCAL_BIN"; return 0; fi
    tag="$(github_latest_tag "$repo")" || { echo "  ! $bin: could not resolve latest version (need curl + github.com)"; return 1; }
    ver="${tag#v}"
    tmp="$(mktemp -d)"
    dl "https://github.com/${repo}/releases/download/${tag}/${prefix}-${vp}${ver}-${triple}.tar.gz" "$tmp/$bin.tar.gz" || { rm -rf "$tmp"; return 1; }
    tar -xzf "$tmp/$bin.tar.gz" -C "$tmp" || { rm -rf "$tmp"; return 1; }
    path="$(find "$tmp" -type f -name "$bin" | head -1)"
    [ -z "$path" ] && { rm -rf "$tmp"; return 1; }
    install -m 0755 "$path" "$LOCAL_BIN/$bin" || { rm -rf "$tmp"; return 1; }
    rm -rf "$tmp"
    command -v "$bin" >/dev/null 2>&1
}

# First line of `<bin> --version` -> "MAJ.MIN" (works when a space or v
# precedes the number, as in "zoxide v0.9.8" / "ripgrep 14.1.1" / "bat 0.25.0").
ver_mm() { "$1" --version 2>/dev/null | sed -n '1s/.*[ v]\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p'; }

ver_lt() {  # ver_lt <MAJ.MIN> <MAJ.MIN> — true if $1 is older than $2 (or unparseable)
    [ -z "$1" ] && return 0
    local vmaj="${1%%.*}" vmin="${1#*.}" fmaj="${2%%.*}" fmin="${2#*.}"
    [ "$vmaj" -ge 0 ] 2>/dev/null || return 0   # garbage -> treat as old
    [ "$vmaj" -lt "$fmaj" ] && return 0
    [ "$vmaj" -eq "$fmaj" ] && [ "$vmin" -lt "$fmin" ] && return 0
    return 1
}

maybe_upgrade() {  # maybe_upgrade <bin> <floor> <install_cmd...> — install when missing or older than floor
    local bin="$1" floor="$2"; shift 2
    local v=""
    if command -v "$bin" >/dev/null 2>&1; then
        v="$(ver_mm "$bin")"
        if ! ver_lt "$v" "$floor"; then
            printf '  ✓ %-10s present (%s)\n' "$bin" "$v"
            return 0
        fi
        echo "  ($bin ${v:-?} is older than $floor; installing a current release)"
    fi
    "$@" || printf '  ! %-10s not installed/upgraded\n' "$bin"
}

install_fzf_release() {  # download the fzf binary into ~/.local/bin (no root)
    local a os tag ver tmp
    a="$(go_arch)"; [ -z "$a" ] && { echo "  ! fzf: unsupported arch $ARCH"; return 1; }
    if [ "$OS" = "Darwin" ]; then os="darwin"; else os="linux"; fi
    printf '  → %-10s prebuilt release (%s_%s) -> %s\n' fzf "$os" "$a" "$LOCAL_BIN"
    if [ "$DRY_RUN" = "1" ]; then echo "    [dry-run] resolve latest tag; dl fzf-<ver>-${os}_${a}.tar.gz; cp fzf -> $LOCAL_BIN"; return 0; fi
    tag="$(github_latest_tag junegunn/fzf)" || { echo "  ! fzf: could not resolve latest version (need curl + github.com)"; return 1; }
    ver="${tag#v}"
    tmp="$(mktemp -d)"
    dl "https://github.com/junegunn/fzf/releases/download/${tag}/fzf-${ver}-${os}_${a}.tar.gz" "$tmp/fzf.tar.gz" || { rm -rf "$tmp"; return 1; }
    tar -xzf "$tmp/fzf.tar.gz" -C "$tmp" || { rm -rf "$tmp"; return 1; }
    install -m 0755 "$tmp/fzf" "$LOCAL_BIN/fzf" || { rm -rf "$tmp"; return 1; }
    rm -rf "$tmp"
    command -v fzf >/dev/null 2>&1
}

ts_cli_arch() { case "$ARCH" in x86_64|amd64) echo x64 ;; aarch64|arm64) echo arm64 ;; *) echo "" ;; esac; }

install_tree_sitter_cli() {  # download the tree-sitter CLI into ~/.local/bin (no root)
    local a os tmp ver
    # Pin to 0.25.x: tree-sitter 0.26+ release binaries need glibc 2.39 (Ubuntu
    # 24.04+), too new for older distros like Ubuntu 22.04 (glibc 2.35). 0.25.10
    # runs on glibc 2.35+ and on macOS, and builds parsers fine for nvim-treesitter.
    ver="0.25.10"
    a="$(ts_cli_arch)"; [ -z "$a" ] && { echo "  ! tree-sitter: unsupported arch $ARCH"; return 1; }
    if [ "$OS" = "Darwin" ]; then os="macos"; else os="linux"; fi
    echo "  → tree-sitter prebuilt release v$ver ($os-$a) -> $LOCAL_BIN"
    if [ "$DRY_RUN" = "1" ]; then echo "    [dry-run] dl tree-sitter-${os}-${a}.gz (v$ver); gunzip -> $LOCAL_BIN/tree-sitter"; return 0; fi
    have_dl || { echo "  ! tree-sitter: need curl or wget"; return 1; }
    tmp="$(mktemp -d)"
    dl "https://github.com/tree-sitter/tree-sitter/releases/download/v${ver}/tree-sitter-${os}-${a}.gz" "$tmp/ts.gz" || { rm -rf "$tmp"; return 1; }
    gunzip -c "$tmp/ts.gz" > "$tmp/tree-sitter" || { rm -rf "$tmp"; return 1; }
    install -m 0755 "$tmp/tree-sitter" "$LOCAL_BIN/tree-sitter" || { rm -rf "$tmp"; return 1; }
    rm -rf "$tmp"
    command -v tree-sitter >/dev/null 2>&1
}

# Install a tool that may not be packaged: brew -> prebuilt release -> note.
smart_install() {  # smart_install <binary> <tool> <release_fn>
    local bin="$1" tool="$2" relfn="$3"
    if command -v "$bin" >/dev/null 2>&1; then
        printf '  ✓ %-10s present\n' "$tool"; return 0
    fi
    if [ "$PM" = "brew" ]; then
        printf '  → %-10s brew install\n' "$tool"
        pm_install "$(pkg_for "$tool")"
        { [ "$DRY_RUN" = "1" ] || command -v "$bin" >/dev/null 2>&1; } && return 0
    fi
    if have_dl; then
        "$relfn" && { [ "$DRY_RUN" = "1" ] || command -v "$bin" >/dev/null 2>&1; } && return 0
    fi
    printf '  ! %-10s install manually\n' "$tool"; return 1
}

# Install a well-packaged tool straight from the system manager.
ensure_pkg() {  # ensure_pkg <binary> <tool> [hint]
    local bin="$1" tool="$2" hint="${3:-}"
    if command -v "$bin" >/dev/null 2>&1; then
        printf '  ✓ %-10s present\n' "$tool"; return 0
    fi
    local pkg; pkg="$(pkg_for "$tool")"
    if [ -n "$pkg" ]; then
        printf '  → %-10s %s install (%s)\n' "$tool" "$PM" "$pkg"
        pm_install $pkg
        { [ "$DRY_RUN" = "1" ] || command -v "$bin" >/dev/null 2>&1; } && return 0
    fi
    printf '  ! %-10s not installed%s\n' "$tool" "${hint:+ — $hint}"; return 1
}

# ---- neovim (version-aware: need >= 0.11) ----------------------------------
echo
echo "Editor:"
nvim_recent=0
if command -v nvim >/dev/null 2>&1; then
    nv="$(nvim --version 2>/dev/null | sed -n '1s/.*v\([0-9]*\.[0-9]*\).*/\1/p')"
    # "" = --version failed/unparseable: treat as broken, NOT as recent.
    case "$nv" in ""|0.[0-9]|0.10) nvim_recent=0 ;; *) nvim_recent=1 ;; esac
fi
if [ "$nvim_recent" = "1" ]; then
    printf '  ✓ %-10s present (%s)\n' neovim "$nv"
elif [ "$PM" = "brew" ]; then
    # `brew install` errors if an old brew nvim is present; upgrade it instead.
    if brew list neovim >/dev/null 2>&1; then
        printf '  → %-10s brew upgrade\n' neovim
        run brew upgrade neovim || echo "  ! neovim: brew upgrade failed (pinned or HEAD install?)"
    else
        printf '  → %-10s brew install\n' neovim; pm_install neovim
    fi
    # An old nvim earlier on PATH (e.g. a stale ~/.local/bin symlink) can still
    # shadow brew's fresh one — recheck instead of assuming success.
    if [ "$DRY_RUN" != "1" ]; then
        nv="$(nvim --version 2>/dev/null | sed -n '1s/.*v\([0-9]*\.[0-9]*\).*/\1/p')"
        case "$nv" in
            ""|0.[0-9]|0.10) echo "  ! nvim on PATH is still ${nv:-broken} — is an old ~/.local/bin/nvim shadowing brew's?" ;;
        esac
    fi
else
    [ -n "${nv:-}" ] && echo "  (neovim ${nv:-?} is too old; installing a current release alongside it)"
    install_nvim_release || echo "  ! neovim: grab a release from https://github.com/neovim/neovim/releases"
fi

# ---- multiplexer + file manager (release binaries on Linux) ----------------
echo
echo "Multiplexer + file manager:"
smart_install zellij zellij install_zellij_release
smart_install yazi   yazi   install_yazi_release

# ---- finder + search --------------------------------------------------------
echo
echo "Finder + search:"
# fzf is version-gated like neovim: the shell keybindings in bashrc (Ctrl-R /
# Ctrl-T / Alt-C) need `fzf --bash/--zsh` (>= 0.48), but apt ships 0.29-0.44.
fzf_recent=0
fv=""
if command -v fzf >/dev/null 2>&1; then
    fv="$(fzf --version 2>/dev/null | sed -n 's/^\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')"
    case "$fv" in
        ""|0.[0-9]|0.[1-3][0-9]|0.4[0-7]) fzf_recent=0 ;;
        *) fzf_recent=1 ;;
    esac
fi
if [ "$fzf_recent" = "1" ]; then
    printf '  ✓ %-10s present (%s)\n' fzf "$fv"
elif [ "$PM" = "brew" ]; then
    if brew list fzf >/dev/null 2>&1; then
        printf '  → %-10s brew upgrade\n' fzf
        run brew upgrade fzf || echo "  ! fzf: brew upgrade failed"
    else
        printf '  → %-10s brew install\n' fzf; pm_install fzf
    fi
else
    [ -n "$fv" ] && echo "  (fzf ${fv} is too old for the shell keybindings; installing a current release)"
    install_fzf_release || ensure_pkg fzf fzf "https://github.com/junegunn/fzf"
fi
ensure_pkg rg ripgrep "https://github.com/BurntSushi/ripgrep"

# ---- git UI (lazygit, used by lazygit.nvim) --------------------------------
echo
echo "Git UI:"
if command -v lazygit >/dev/null 2>&1; then
    echo "  ✓ lazygit    present"
elif [ "$PM" = "brew" ]; then
    echo "  → lazygit    brew install"
    pm_install lazygit
elif have_dl; then
    install_lazygit_release || echo "  ! lazygit: see https://github.com/jesseduffield/lazygit"
else
    echo "  ! lazygit: install from https://github.com/jesseduffield/lazygit"
fi

# ---- markdown viewer (glow: `glow README.md` renders it in the terminal) ---
# Not packaged on Debian/Ubuntu, so smart_install falls back to the release.
echo
echo "Markdown viewer:"
smart_install glow glow install_glow_release

# ---- C compiler (treesitter compiles parsers on install) -------------------
echo
echo "Build prerequisites (treesitter parsers):"
if [ "$OS" = "Darwin" ]; then
    # /usr/bin/cc & friends are xcrun shims that exist even WITHOUT the Command
    # Line Tools, so `command -v cc` lies here — ask xcode-select instead.
    if xcode-select -p >/dev/null 2>&1; then
        echo "  ✓ compiler    present"
    else
        echo "  ! run: xcode-select --install"
    fi
elif command -v cc >/dev/null 2>&1 || command -v gcc >/dev/null 2>&1 || command -v clang >/dev/null 2>&1; then
    echo "  ✓ compiler    present"
else
    case "$PM" in
        apt-get) pm_install build-essential ;;
        dnf)     pm_install gcc make ;;
        pacman)  pm_install base-devel ;;
        zypper)  pm_install gcc make ;;
        apk)     pm_install build-base ;;
        *)       echo "  ! install a C compiler (gcc/clang) + make" ;;
    esac
fi
# tree-sitter CLI: nvim-treesitter's `main` branch builds parsers with it.
# (Homebrew's `tree-sitter` is the library, not the CLI, so use the release binary.)
if command -v tree-sitter >/dev/null 2>&1; then
    echo "  ✓ tree-sitter present"
elif have_dl; then
    install_tree_sitter_cli || echo "  ! tree-sitter CLI: https://github.com/tree-sitter/tree-sitter/releases"
else
    echo "  ! tree-sitter CLI: install from https://github.com/tree-sitter/tree-sitter/releases"
fi

# ---- Python tooling via uv (no brew / no root needed) ----------------------
echo
echo "Python tooling (ruff + ty, via uv):"
if ! command -v uv >/dev/null 2>&1; then
    if [ "$PM" = "brew" ]; then
        pm_install uv
    else
        echo "  → uv         astral.sh installer"
        if [ "$DRY_RUN" = "1" ]; then echo "    [dry-run] curl -LsSf https://astral.sh/uv/install.sh | sh"
        else curl -LsSf https://astral.sh/uv/install.sh | sh; fi
    fi
    [ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
fi
if command -v uv >/dev/null 2>&1 || [ "$DRY_RUN" = "1" ]; then
    for tool in ruff ty; do
        printf '  → uv tool install %s\n' "$tool"
        run uv tool install "$tool"
    done
else
    echo "  ! uv unavailable; later run: uv tool install ruff && uv tool install ty"
fi

# ---- optional: richer yazi previews + navigation (best-effort) -------------
echo
echo "Optional preview/navigation tools (best-effort):"
for t in bat fd zoxide jq ffmpegthumbnailer poppler imagemagick 7zip; do
    pkg="$(pkg_for "$t")"
    if [ -n "$pkg" ]; then
        printf '  → %s (%s)\n' "$t" "$pkg"
        pm_install $pkg || true
    else
        printf '  - %s (no package manager; skip)\n' "$t"
    fi
done

# Debian/Ubuntu install fd-find/bat under different binary names; expose the
# expected `fd` / `bat` names in ~/.local/bin so yazi's previews find them.
if [ "$PM" = "apt-get" ] && [ "$DRY_RUN" != "1" ]; then
    command -v fdfind >/dev/null 2>&1 && [ ! -e "$LOCAL_BIN/fd" ]  && ln -sf "$(command -v fdfind)" "$LOCAL_BIN/fd"
    command -v batcat >/dev/null 2>&1 && [ ! -e "$LOCAL_BIN/bat" ] && ln -sf "$(command -v batcat)" "$LOCAL_BIN/bat"
fi

# ---- keep the shell/preview tools current -----------------------------------
# Distro packages of these lag years behind (Ubuntu 22.04: zoxide 0.4, bat
# 0.19, fd 8, rg 13). When one is missing or older than the floor, install a
# current release into ~/.local/bin (which PATH prefers). Skipped under brew —
# it stays current on its own. Floors ≈ what current distros ship; bump freely.
if [ "$PM" != "brew" ]; then
    echo
    echo "Version-gated upgrades (release binaries into ~/.local/bin):"
    maybe_upgrade zoxide 0.9  install_rust_release ajeetdsouza/zoxide zoxide  zoxide "" musl
    maybe_upgrade rg     14.0 install_rust_release BurntSushi/ripgrep ripgrep rg     "" gnu
    maybe_upgrade bat    0.24 install_rust_release sharkdp/bat        bat     bat    v  gnu
    maybe_upgrade fd     10.0 install_rust_release sharkdp/fd         fd      fd     v  gnu
fi

# ---- Nerd Font (icons in neovim / yazi) ------------------------------------
# Only matters where you actually RUN a terminal (your Mac, or the Linux box if
# used locally) — over SSH the glyphs are drawn by the Mac's Ghostty.
echo
echo "Nerd Font (Hack — neovim/yazi icons):"
if font_present; then
    echo "  ✓ Hack Nerd Font present"
elif [ "$PM" = "brew" ] && [ "$OS" = "Darwin" ]; then
    # casks are macOS-only; Linuxbrew falls through to the release download
    echo "  → Hack Nerd Font (brew cask)"
    pm_install --cask font-hack-nerd-font
elif have_dl; then
    install_nerdfont_release || echo "  ! Hack Nerd Font: get it from https://github.com/ryanoasis/nerd-fonts"
else
    echo "  ! install a Nerd Font (https://github.com/ryanoasis/nerd-fonts) for icons"
fi

echo
echo "Done. Reminders:"
echo "  * ~/.local/bin must be on your PATH (the shell config adds it)."
echo "  * Ghostty is configured to use Hack Nerd Font Mono (config/ghostty/config)."
echo "  * First 'nvim' launch auto-installs plugins."
