#!/usr/bin/env bash
# zweb.sh — zellij web access over the tailnet (the `zweb` function in
# ~/.aliases wraps this). The web server starts with any zellij session
# (web_server true in config.kdl) and listens on 127.0.0.1:8082 ONLY; `up`
# publishes it as https://<machine>.<tailnet>.ts.net via `tailscale serve` —
# browser-trusted TLS, unreachable off-tailnet, persists across reboots.
# https://HOST/<session-name> attaches to (or resurrects) that session.
# Each device logs in once with a token (shown once; revoke to invalidate).
#
#   zweb [status]        web server + tailnet-proxy + switcher status
#   zweb start|stop      run/stop the server by hand (normally automatic)
#   zweb token NAME      mint a login token (one per device: mobile, laptop, ...)
#   zweb rotoken NAME    mint a read-only token (watch, no input)
#   zweb tokens          list token names + creation dates
#   zweb revoke NAME     revoke a token (kills its devices' logins)
#   zweb up|down         publish/unpublish on the tailnet; up also starts the
#                        mobile switcher + key-row page at https://HOST/s
#   zweb enable|disable  run `zweb up` at login (launchd/systemd), after
#                        waiting for Tailscale to come online (zweb-boot.sh)
#   zweb online          exit 0 iff the tailscale backend is Running (internal;
#                        polled by zweb-boot.sh)

# The switcher's pidfile, and its pid when the process is alive (verified by
# matching zweb-switcher.py in the pid's command line).
_zweb_pidfile() { echo "${TMPDIR:-/tmp}/zweb-switcher.$(id -u).pid"; }
_zweb_switcher_pid() {  # print the running switcher's pid, else fail
    local pf pid; pf="$(_zweb_pidfile)"
    pid="$(cat "$pf" 2>/dev/null)" || return 1
    [ -n "$pid" ] && ps -p "$pid" -o command= 2>/dev/null | grep -q 'zweb-switcher\.py' \
        && echo "$pid"
}

_tsbin() {  # tailscale CLI: on PATH (Linux) or inside the macOS app bundle
    if command -v tailscale >/dev/null 2>&1; then command tailscale "$@"
    elif [ -x "/Applications/Tailscale.app/Contents/MacOS/Tailscale" ]; then
        "/Applications/Tailscale.app/Contents/MacOS/Tailscale" "$@"
    else echo "zweb: tailscale CLI not found (install Tailscale)" >&2; return 127; fi
}
_zweb_tailscale_online() {  # 0 only when the tailscale backend is up (Running)
    _tsbin status --json 2>/dev/null | grep -q '"BackendState": *"Running"'
}

# Zellij's token store: a small sqlite db (name + token hash per row). Read
# only by the token-rename workaround for zellij-org/zellij#4976 below.
_zweb_tokendb() {
    case "$(uname -s)" in
        Darwin) echo "$HOME/Library/Application Support/org.Zellij-Contributors.Zellij/tokens.db" ;;
        *)      echo "${XDG_DATA_HOME:-$HOME/.local/share}/zellij/tokens.db" ;;
    esac
}

cmd="${1:-status}" arg="$2"
case "$cmd" in
    status)
        zellij web --status
        _tsbin serve status 2>/dev/null || echo "zweb: no tailnet proxy on this host (publish with: zweb up)"
        [ -n "$(_zweb_switcher_pid)" ] \
            && echo "zweb: mobile switcher running (127.0.0.1:8083, mounted at /s)" \
            || echo "zweb: mobile switcher not running (starts with: zweb up)"
        # Sharing is a per-session property fixed at creation: sessions
        # started while web_sharing was off (or sharing toggled off since)
        # loop "connection lost" in the browser instead of saying why.
        echo "zweb: browser stuck on 'connection lost'? That session isn't web-shared (started while web_sharing was off) -> in it: Ctrl+o, s, then start sharing" ;;
    start) zellij web -d ;;
    stop)  zellij web --stop ;;
    online) _zweb_tailscale_online ;;
    token|rotoken)
        [ -n "$arg" ] || { echo "usage: zweb $cmd NAME   (e.g. zweb $cmd mobile)" >&2; exit 2; }
        case "$arg" in (*[!A-Za-z0-9_-]*) echo "zweb: NAME must be letters/digits/_/- only" >&2; exit 2 ;; esac
        flag=--create-token; [ "$cmd" = rotoken ] && flag=--create-read-only-token
        # Try the documented spelling first; zellij <= 0.44.3 rejects it
        # (--token-name wrongly marked exclusive, zellij-org/zellij#4976).
        if zellij web "$flag" --token-name "$arg" 2>/dev/null; then exit 0; fi
        out="$(zellij web "$flag")" || { printf '%s\n' "$out" >&2; exit 1; }
        printf '%s\n' "$out"
        # Workaround: rename the auto 'token_N' row so `zweb tokens/revoke`
        # can use the device name. Plain-text name column, hash untouched.
        autoname="$(printf '%s\n' "$out" | sed -n 's/^\([A-Za-z0-9_]*\): .*/\1/p' | tail -n1)"
        db="$(_zweb_tokendb)"
        if [ -n "$autoname" ] && [ -f "$db" ] && command -v sqlite3 >/dev/null 2>&1 \
           && sqlite3 "$db" "UPDATE tokens SET name='$arg' WHERE name='$autoname';" 2>/dev/null; then
            echo "zweb: token renamed $autoname -> $arg"
        else
            echo "zweb: could not rename; token is named '$autoname' (zellij#4976)" >&2
        fi ;;
    tokens) zellij web --list-tokens ;;
    revoke)
        [ -n "$arg" ] || { echo "usage: zweb revoke NAME (zweb tokens lists them)" >&2; exit 2; }
        zellij web --revoke-token "$arg" ;;
    up)
        # Publishing needs Tailscale online (for the proxy + cert). Gate on
        # it up front so boot autostart and a manual run both fail loudly
        # rather than half-mounting.
        if ! _zweb_tailscale_online; then
            echo "zweb: Tailscale is not online ('tailscale status') — not publishing" >&2
            exit 1
        fi
        # Ensure the web server is up. web_server true starts it with the
        # first session, but at boot there is none yet, so start it here.
        # `zellij web --status` exits 0 even when offline, so match its
        # output rather than its exit code.
        zellij web --status 2>&1 | grep -qi offline && zellij web -d >/dev/null 2>&1
        # Proxy 443 -> localhost:8082. Needs MagicDNS + HTTPS Certificates
        # enabled for the tailnet (admin console -> DNS); serve config is
        # stored by tailscaled, so this survives reboots.
        if ! _tsbin serve --bg 8082; then
            echo "zweb: tailscale serve failed. Check both:" >&2
            echo "  - MagicDNS + HTTPS Certificates enabled (admin console -> DNS)" >&2
            echo "  - on Linux, serve needs a one-time grant: sudo tailscale set --operator=\$USER" >&2
            exit 1
        fi
        # Self.DNSName is the first DNSName in the status JSON; strip the root dot.
        fqdn="$(_tsbin status --json 2>/dev/null | sed -n 's/.*"DNSName": *"\([^"]*\)".*/\1/p' | head -n1)"
        fqdn="${fqdn%.}"
        [ -n "$fqdn" ] && echo "zweb: serving at https://$fqdn/  (attach: https://$fqdn/<session-name>)"
        # Mobile switcher + on-screen key row (zweb-switcher.py), mounted at
        # /s on the same origin so it shares the login cookie.
        if command -v python3 >/dev/null 2>&1 && [ -f "$HOME/.config/zellij/zweb-switcher.py" ]; then
            # Start it unless already running. The pidfile arg makes the
            # switcher daemonize and record its pid there.
            [ -n "$(_zweb_switcher_pid)" ] \
                || python3 "$HOME/.config/zellij/zweb-switcher.py" "$(_zweb_pidfile)" >/dev/null 2>&1
            if _tsbin serve --bg --set-path=/s http://127.0.0.1:8083 >/dev/null 2>&1; then
                echo "zweb: mobile switcher at https://${fqdn:-HOST}/s"
            else
                echo "zweb: could not mount /s (tailscale serve --set-path failed)" >&2
            fi
        fi ;;
    down)
        arg="$(_zweb_switcher_pid)" && kill "$arg" 2>/dev/null
        rm -f "$(_zweb_pidfile)"
        # Turn off only the two mounts `zweb up` created (not `serve
        # reset`, which clears every mount on the host).
        _tsbin serve --https=443 --set-path=/s off 2>/dev/null
        _tsbin serve --https=443 off \
            && echo "zweb: tailnet proxy removed (server still on 127.0.0.1:8082)" ;;
    enable|disable)
        # Run `zweb up` at login via zweb-boot.sh (which waits for Tailscale
        # first). Per-machine opt-in — not every host should publish — so
        # it's a subcommand, not wired into make_symlinks.
        boot="$HOME/.config/zellij/zweb-boot.sh"
        case "$(uname -s)" in
            Darwin)
                plist="$HOME/Library/LaunchAgents/dev.zellij.zweb.plist"
                launchctl unload "$plist" 2>/dev/null
                if [ "$cmd" = disable ]; then
                    rm -f "$plist"; echo "zweb: login autostart removed"; exit 0
                fi
                [ -f "$boot" ] || { echo "zweb: $boot missing (run make_symlinks.sh)" >&2; exit 1; }
                mkdir -p "$(dirname "$plist")"
                cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>Label</key><string>dev.zellij.zweb</string>
    <key>ProgramArguments</key>
    <array><string>/bin/bash</string><string>$boot</string></array>
    <key>RunAtLoad</key><true/>
    <key>StandardErrorPath</key><string>${TMPDIR:-/tmp}/zweb-boot.log</string>
</dict></plist>
EOF
                launchctl load "$plist" \
                    && echo "zweb: will run at login (launchd dev.zellij.zweb); log: ${TMPDIR:-/tmp}/zweb-boot.log" ;;
            *)
                unit="$HOME/.config/systemd/user/zweb.service"
                if [ "$cmd" = disable ]; then
                    systemctl --user disable --now zweb.service 2>/dev/null
                    rm -f "$unit"; systemctl --user daemon-reload 2>/dev/null
                    echo "zweb: login autostart removed"; exit 0
                fi
                [ -f "$boot" ] || { echo "zweb: $boot missing (run make_symlinks.sh)" >&2; exit 1; }
                mkdir -p "$(dirname "$unit")"
                cat > "$unit" <<EOF
[Unit]
Description=Publish zellij web on the tailnet (zweb up)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash $boot

[Install]
WantedBy=default.target
EOF
                systemctl --user daemon-reload 2>/dev/null
                systemctl --user enable --now zweb.service \
                    && echo "zweb: will run at login (systemd --user zweb.service)"
                echo "zweb: for boot without an active login, run once: sudo loginctl enable-linger $USER" ;;
        esac ;;
    help|-h|--help) echo "usage: zweb [status|start|stop|token NAME|rotoken NAME|tokens|revoke NAME|up|down|enable|disable]  (see the header of config/zellij/zweb.sh)" ;;
    *) echo "usage: zweb [status|start|stop|token NAME|rotoken NAME|tokens|revoke NAME|up|down|enable|disable]" >&2; exit 2 ;;
esac
