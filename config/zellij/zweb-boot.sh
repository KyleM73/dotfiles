#!/usr/bin/env bash
# zweb-boot.sh — login/boot entrypoint for zweb autostart, installed and
# removed by `zweb enable` / `zweb disable` (launchd on macOS, systemd --user
# on Linux). It runs in a minimal boot environment, so it sets a PATH that
# finds zellij/python (~/.local/bin on Linux, Homebrew on macOS), sources the
# shell aliases for the zweb function, waits for Tailscale to come online —
# the tailnet mounts and cert can't be served until it is — and then runs
# `zweb up`.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

if [ ! -e "$HOME/.aliases" ]; then
    echo "zweb-boot: ~/.aliases missing (run make_symlinks.sh)" >&2
    exit 1
fi
# shellcheck disable=SC1091
. "$HOME/.aliases"

# Gate on Tailscale: poll up to ~60s for the backend to report Running before
# publishing. If it never comes online, exit cleanly — the persisted serve
# mounts (if any) still route once tailscaled is up; nothing to undo.
i=0
until _zweb_tailscale_online; do
    i=$((i + 1))
    if [ "$i" -ge 60 ]; then
        echo "zweb-boot: Tailscale not online after 60s — skipping zweb up" >&2
        exit 0
    fi
    sleep 1
done

zweb up
