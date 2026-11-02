#!/usr/bin/env bash
# zellij-persist USER [--once] — root daemon behind zpersist.sh. Not run from
# the repo: `zpersist.sh install` copies it, root-owned, to
# /usr/local/sbin/zellij-persist and runs it as zellij-persist@USER.service.
#
# Every few seconds it finds USER's zellij session servers (`zellij --server
# .../NAME`) and web server (`zellij ... web -d`) and moves each one, with its
# pane processes, into its own scope under system.slice
# (zellij-NAME-PID.scope). Processes there are outside user.slice, so they
# survive anything that tears user.slice down: logout, `loginctl
# terminate-user`, or the systemd --user manager dying. That holds however
# the session was started: z/zv/zw/zm, za, zssh/mssh, plain `zellij`, or the
# browser. A scope goes away by itself when its server exits.
#
# Panes forked after adoption inherit the scope. A pane forked between the
# scan and the move is attached on the next pass, but only if it is still in
# the server's ORIGINAL cgroup: processes that something deliberately moved
# elsewhere (snap apps, `systemd-run --scope`) are left alone.

set -u
user="${1:?usage: zellij-persist USER [--once]}"
uid="$(id -u "$user")" || exit 1
interval="${ZPERSIST_INTERVAL:-2}"

declare -A orig   # root pid -> the cgroup it was adopted from (this run only)

mgr() {
    busctl --quiet call org.freedesktop.systemd1 /org/freedesktop/systemd1 \
        org.freedesktop.systemd1.Manager "$@"
}
cgroup_of() { sed -n 's/^0:://p' "/proc/$1/cgroup" 2>/dev/null; }

# One snapshot of USER's processes -> lines "R pid label" for each server and
# "K rootpid pid" for each process under it, stopping at nested servers (a
# session the web server spawned is its own root, not the web server's pane).
scan() {
    ps -u "$uid" -o pid=,ppid=,args= 2>/dev/null | awk '
    {
        pid = $1; ppid = $2; $1 = $2 = ""; args = substr($0, 3)
        kids[ppid] = kids[ppid] " " pid
        exe = args; sub(/ .*/, "", exe); sub(/.*\//, "", exe)
        if (exe != "zellij") next
        if (match(args, / --server /)) {
            name = substr(args, RSTART + RLENGTH); sub(/.*\//, "", name)
            root[pid] = name
        } else if (args ~ / web( |$)/ && args ~ / (-d|--daemonize)( |$)/) {
            root[pid] = "web"
        }
    }
    END {
        for (r in root) {
            print "R", r, root[r]
            q = kids[r]
            while (q != "") {
                n = split(q, a, " "); q = ""
                for (i = 1; i <= n; i++) {
                    if (a[i] in root) continue
                    print "K", r, a[i]; q = q " " kids[a[i]]
                }
            }
        }
    }'
}

pass() {
    local -A label kids
    local kind r x cg own unit k
    while read -r kind r x; do
        case "$kind" in
            R) label[$r]="$x" ;;
            K) kids[$r]+=" $x" ;;
        esac
    done < <(scan)

    for r in "${!label[@]}"; do
        cg="$(cgroup_of "$r")"; [ -n "$cg" ] || continue
        case "$cg" in
            /system.slice/zellij-*-"$r".scope) own="$cg" ;;
            *) own="" ;;
        esac
        local -a pids=()
        if [ -z "$own" ]; then
            # Adopt the server plus the panes that share its cgroup.
            pids=("$r")
            for k in ${kids[$r]-}; do [ "$(cgroup_of "$k")" = "$cg" ] && pids+=("$k"); done
            unit="zellij-$(systemd-escape -- "${label[$r]}")-$r.scope"
            if mgr StartTransientUnit 'ssa(sv)a(sa(sv))' "$unit" fail 3 \
                    PIDs au "${#pids[@]}" "${pids[@]}" Slice s system.slice \
                    Description s "zellij ${label[$r]} ($user, pid $r)" 0; then
                orig[$r]="$cg"
                echo "adopted '${label[$r]}' (pid $r, ${#pids[@]} processes) from $cg -> $unit"
            fi
        elif [ -n "${orig[$r]-}" ]; then
            # Catch panes that were forked mid-adoption, still in the old cgroup.
            for k in ${kids[$r]-}; do [ "$(cgroup_of "$k")" = "${orig[$r]}" ] && pids+=("$k"); done
            if [ "${#pids[@]}" -gt 0 ] && mgr AttachProcessesToUnit ssau "${own##*/}" "" \
                    "${#pids[@]}" "${pids[@]}"; then
                echo "attached ${#pids[@]} late process(es) to ${own##*/}"
            fi
        fi
    done
    # Forget servers that have exited.
    for r in "${!orig[@]}"; do [ -d "/proc/$r" ] || unset "orig[$r]"; done
}

[ "${2-}" = "--once" ] && { pass; exit 0; }
while :; do pass; sleep "$interval"; done
