#!/usr/bin/env bash
# zpersist.sh — keep zellij sessions alive when your Linux login goes away.
#
# By default a zellij server lives in your login's cgroup under user.slice,
# and its socket in /run/user/UID. Logging out of the desktop, `loginctl
# terminate-user`, or the systemd --user manager dying (as on AD-0117,
# 2026-10-31) kills that cgroup and wipes /run/user/UID, so sessions die or
# can't be re-attached. Two pieces fix that:
#
#   1. A root service, zellij-persist@USER (zpersist-adopt.sh, installed as
#      /usr/local/sbin/zellij-persist), moves every zellij session server and
#      the web server into its own scope under system.slice within ~2s of it
#      starting. It needs no wrappers, so z/zv/zw/zm, za, zssh, mssh, plain
#      `zellij` and browser sessions are all covered.
#   2. ZELLIJ_SOCKET_DIR=~/.local/state/zellij/sock: sockets live outside
#      /run/user. bashrc, zshenv and zweb-boot.sh export it on Linux, so
#      every zellij command, interactive or not, uses the same directory.
#
# macOS needs neither: nothing there kills sessions on logout.
#
#   zpersist.sh [status]   service state + whether each running server is protected
#   zpersist.sh install    install/refresh the service for $USER (sudo; idempotent;
#                          install_deps.sh runs this on Linux)
#   zpersist.sh uninstall  remove it (sessions already adopted keep their scope)

SELF_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
SRC="$SELF_DIR/zpersist-adopt.sh"
BIN=/usr/local/sbin/zellij-persist
UNIT_FILE=/etc/systemd/system/zellij-persist@.service
INSTANCE="zellij-persist@$(id -un).service"
SOCKDIR="${ZELLIJ_SOCKET_DIR:-$HOME/.local/state/zellij/sock}"

supported() { [ "$(uname -s)" = Linux ] && [ -d /run/systemd/system ]; }

unit_text() {
    cat <<'EOF'
# Installed by dotfiles config/zellij/zpersist.sh — see that file.
[Unit]
Description=Keep %i's zellij sessions alive across logout (zpersist)
After=systemd-logind.service

[Service]
ExecStart=/usr/local/sbin/zellij-persist %i
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

cmd="${1:-status}"
case "$cmd" in
    status)
        supported || { echo "zpersist: not needed here (Linux + systemd only)"; exit 0; }
        echo "socket dir: $SOCKDIR"
        if [ ! -x "$BIN" ]; then
            echo "service:    NOT installed (run: zpersist.sh install)"
        else
            echo "service:    $INSTANCE $(systemctl is-active "$INSTANCE" 2>/dev/null)"
            cmp -s "$SRC" "$BIN" || echo "            installed copy is stale (run: zpersist.sh install)"
        fi
        echo "--- running servers"
        for pid in $(pgrep -u "$(id -u)" -x zellij); do
            args="$(ps -o args= -p "$pid" 2>/dev/null)"
            case "$args" in *" --server "*|*" web -d"*|*" web --daemonize"*) ;; *) continue ;; esac
            cg="$(sed -n 's/^0:://p' "/proc/$pid/cgroup" 2>/dev/null)"
            case "$cg" in /system.slice/zellij-*) state=protected ;; *) state="NOT protected" ;; esac
            name="${args##*/}"; case "$args" in *" web "*) name=web ;; esac
            printf '  %-28s %-14s %s\n' "$name" "$state" "$cg"
        done
        echo "--- sessions"
        zellij list-sessions -n 2>&1 ;;

    install)
        supported || { echo "zpersist: not needed here (Linux + systemd only)"; exit 0; }
        mkdir -p "$SOCKDIR" && chmod 700 "$SOCKDIR" "$(dirname "$SOCKDIR")"
        changed=0
        if ! cmp -s "$SRC" "$BIN"; then
            sudo install -o root -g root -m 0755 "$SRC" "$BIN" || exit 1
            changed=1
        fi
        if [ "$(unit_text)" != "$(cat "$UNIT_FILE" 2>/dev/null)" ]; then
            unit_text | sudo tee "$UNIT_FILE" >/dev/null || exit 1
            sudo systemctl daemon-reload
            changed=1
        fi
        sudo systemctl enable --quiet "$INSTANCE" || exit 1
        if [ "$changed" = 1 ]; then sudo systemctl restart "$INSTANCE"
        else sudo systemctl start "$INSTANCE"; fi
        echo "zpersist: $INSTANCE $(systemctl is-active "$INSTANCE") — zellij sessions survive logout" ;;

    uninstall)
        supported || exit 0
        sudo systemctl disable --now --quiet "$INSTANCE" 2>/dev/null
        if ! systemctl list-units --plain --no-legend 'zellij-persist@*' 2>/dev/null | grep -q .; then
            sudo rm -f "$UNIT_FILE" "$BIN" && sudo systemctl daemon-reload
        fi
        echo "zpersist: removed (sessions already adopted keep running in their scopes)" ;;

    -h|--help|help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//' ;;
    *) echo "usage: zpersist.sh [status|install|uninstall]" >&2; exit 2 ;;
esac
