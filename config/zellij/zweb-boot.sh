#!/usr/bin/env bash
# zweb-boot.sh — login/boot entrypoint for zweb autostart, installed and
# removed by `zweb enable` / `zweb disable` (launchd on macOS, systemd --user
# on Linux). Runs in a minimal boot environment: set a PATH that finds
# zellij/python, wait for Tailscale to come online, then `zweb up`.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

ZWEB="$HOME/.config/zellij/zweb.sh"
if [ ! -x "$ZWEB" ]; then
    echo "zweb-boot: $ZWEB missing (run make_symlinks.sh)" >&2
    exit 1
fi

# Poll up to ~60s for the tailscale backend to report Running. If it never
# comes online, exit cleanly — the persisted serve mounts (if any) still
# route once tailscaled is up; nothing to undo.
i=0
until "$ZWEB" online; do
    i=$((i + 1))
    if [ "$i" -ge 60 ]; then
        echo "zweb-boot: Tailscale not online after 60s — skipping zweb up" >&2
        exit 0
    fi
    sleep 1
done

"$ZWEB" up
