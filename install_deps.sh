#!/usr/bin/env bash
# install_deps.sh — install the CLI tools the nvim / zellij / yazi setup uses.
#
#   * Idempotent  : skips anything already on your PATH; safe to re-run.
#   * Best-effort : warns and keeps going if one tool can't be installed.
#   * Portable    : Homebrew on macOS; on Linux the native package manager
#                   (apt/dnf/pacman/zypper/apk) for well-packaged tools.
#
# Homebrew is NOT required on Linux — only used if it happens to be present.
# Three tools are special on Linux because the distro packages are missing or
# too old, so they're installed from OFFICIAL PREBUILT RELEASES into ~/.local
# (no root, no compiler needed):
#     neovim  — apt ships < 0.11; the Python LSP needs the native vim.lsp API
#     zellij  — not packaged on Debian/Ubuntu
#     yazi    — not packaged on Debian/Ubuntu
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
mkdir -p "$LOCAL_BIN"
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
if [ "$PM" != "brew" ] && [ -n "$PM" ] && [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
fi

echo "OS: $OS ($ARCH)   package manager: ${PM:-none}"
if [ "$OS" = "Darwin" ] && [ "$PM" != "brew" ]; then
    echo "  ! No Homebrew on macOS. Install it first: https://brew.sh"
fi

# Can we actually use the system package manager? brew never needs sudo; the
# Linux managers do. Prime sudo ONCE (so you're prompted a single time, not per
# package) and, if it's unavailable non-interactively, skip those installs with
# one clear message instead of erroring on every package. Tools that don't need
# root (nvim/zellij/yazi releases, uv) are installed regardless.
PM_USABLE=1
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
    echo "  ! sudo unavailable non-interactively — skipping $PM packages"
    echo "    (re-run ./install_deps.sh in a terminal to get: fzf, ripgrep, preview tools)"
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
nvim_arch()  { case "$ARCH" in x86_64|amd64) echo x86_64 ;; aarch64|arm64) echo arm64 ;; *) echo "" ;; esac; }
rust_arch()  { case "$ARCH" in x86_64|amd64) echo x86_64 ;; aarch64|arm64) echo aarch64 ;; *) echo "" ;; esac; }

install_nvim_release() {
    local a os url tmp dir
    a="$(nvim_arch)"; [ -z "$a" ] && { echo "  ! neovim: unsupported arch $ARCH"; return 1; }
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
        ls "$HOME/Library/Fonts" /Library/Fonts 2>/dev/null | grep -qi "HackNerdFont"
    fi
}

install_nerdfont_release() {  # download Hack Nerd Font into ~/.local/share/fonts (no root)
    local url dest tmp
    url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip"
    dest="$HOME/.local/share/fonts/HackNerdFont"
    echo "  → Hack Nerd Font -> $dest"
    if [ "$DRY_RUN" = "1" ]; then echo "    [dry-run] dl $url; unzip into $dest; fc-cache -f"; return 0; fi
    have_dl || { echo "  ! need curl or wget"; return 1; }
    command -v unzip >/dev/null 2>&1 || pm_install unzip
    mkdir -p "$dest"; tmp="$(mktemp -d)"
    dl "$url" "$tmp/Hack.zip" || { rm -rf "$tmp"; return 1; }
    unzip -qo "$tmp/Hack.zip" -d "$dest" || { rm -rf "$tmp"; return 1; }
    command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1
    rm -rf "$tmp"
}

lazygit_arch() { case "$ARCH" in x86_64|amd64) echo x86_64 ;; aarch64|arm64) echo arm64 ;; *) echo "" ;; esac; }

install_lazygit_release() {  # download lazygit release binary into ~/.local/bin (no root)
    local a os ver tmp
    a="$(lazygit_arch)"; [ -z "$a" ] && { echo "  ! lazygit: unsupported arch $ARCH"; return 1; }
    if [ "$OS" = "Darwin" ]; then os="Darwin"; else os="Linux"; fi
    echo "  → lazygit    prebuilt release ($os $a) -> $LOCAL_BIN"
    if [ "$DRY_RUN" = "1" ]; then echo "    [dry-run] resolve latest tag; dl lazygit_<ver>_${os}_${a}.tar.gz; cp lazygit -> $LOCAL_BIN"; return 0; fi
    command -v curl >/dev/null 2>&1 || { echo "  ! lazygit: need curl"; return 1; }
    # lazygit asset names embed the version, so resolve the latest tag first.
    ver="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest 2>/dev/null | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -1)"
    [ -z "$ver" ] && { echo "  ! lazygit: could not resolve latest version"; return 1; }
    tmp="$(mktemp -d)"
    dl "https://github.com/jesseduffield/lazygit/releases/download/v${ver}/lazygit_${ver}_${os}_${a}.tar.gz" "$tmp/lg.tar.gz" || { rm -rf "$tmp"; return 1; }
    tar -xzf "$tmp/lg.tar.gz" -C "$tmp" lazygit 2>/dev/null || tar -xzf "$tmp/lg.tar.gz" -C "$tmp" || { rm -rf "$tmp"; return 1; }
    install -m 0755 "$tmp/lazygit" "$LOCAL_BIN/lazygit" || { rm -rf "$tmp"; return 1; }
    rm -rf "$tmp"
    command -v lazygit >/dev/null 2>&1
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
    case "$nv" in 0.[0-9]|0.10) nvim_recent=0 ;; *) nvim_recent=1 ;; esac
fi
if [ "$nvim_recent" = "1" ]; then
    printf '  ✓ %-10s present (%s)\n' neovim "$nv"
elif [ "$PM" = "brew" ]; then
    printf '  → %-10s brew install\n' neovim; pm_install neovim
else
    [ -n "${nv:-}" ] && echo "  (neovim ${nv} is too old; installing a current release alongside it)"
    install_nvim_release || echo "  ! neovim: grab a release from https://github.com/neovim/neovim/releases"
fi

# ---- multiplexer + file manager (release binaries on Linux) ----------------
echo
echo "Multiplexer + file manager:"
smart_install zellij zellij install_zellij_release
smart_install yazi   yazi   install_yazi_release

# ---- finder + search (well packaged everywhere) ----------------------------
echo
echo "Finder + search:"
ensure_pkg fzf fzf     "https://github.com/junegunn/fzf"
ensure_pkg rg  ripgrep "https://github.com/BurntSushi/ripgrep"

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

# ---- C compiler (treesitter compiles parsers on install) -------------------
echo
echo "Build prerequisites (treesitter parsers):"
if command -v cc >/dev/null 2>&1 || command -v gcc >/dev/null 2>&1 || command -v clang >/dev/null 2>&1; then
    echo "  ✓ compiler    present"
else
    case "$PM" in
        brew)    echo "  ! run: xcode-select --install" ;;
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
    echo "  ! uv unavailable; later run: uv tool install ruff ty"
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

# ---- Nerd Font (icons in neovim / yazi) ------------------------------------
# Only matters where you actually RUN a terminal (your Mac, or the Linux box if
# used locally) — over SSH the glyphs are drawn by the Mac's Ghostty.
echo
echo "Nerd Font (Hack — neovim/yazi icons):"
if font_present; then
    echo "  ✓ Hack Nerd Font present"
elif [ "$PM" = "brew" ]; then
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
echo "  * Ghostty is configured to use Hack Nerd Font (config/ghostty/config)."
echo "  * First 'nvim' launch auto-installs plugins."
