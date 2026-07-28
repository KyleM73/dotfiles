#!/bin/sh
# ztab.sh — name zellij tabs after their focused pane's path.
#
#   ztab.sh          refresh ALL tabs: rename each to its focused pane's path
#   ztab.sh self     name the CURRENT tab from this shell's $PWD (fire-once)
#   ztab.sh set NAME name the CURRENT tab to NAME (nvim passes dir/filename)
#
# A shell pane -> the last two components of its cwd (projects/dotfiles); an
# nvim pane -> dir/filename, which nvim publishes as its pane title (see the
# nvim `titlestring` autocmd). The refresh reads one `zellij action list-panes`
# and renames each tab by its stable id, so it never has to switch tabs.
#
# Stickiness: a tab you rename yourself is left alone — refresh only touches a
# tab whose name is still the default ("Tab #N") or the last name ztab itself
# set (tracked under $STATE). To hand a tab back to ztab, clear your name
# (zellij: undo-rename-tab, i.e. rename mode then delete).

[ -n "${ZELLIJ:-}" ] || exit 0
command -v zellij >/dev/null 2>&1 || exit 0

STATE="${XDG_CACHE_HOME:-$HOME/.cache}/zellij/ztab/${ZELLIJ_SESSION_NAME:-default}"
mkdir -p "$STATE" 2>/dev/null || true
TAB="$(printf '\t')"

# echo the last two components of a path: /a/b/c -> b/c, /a -> a, / -> /
last2() {
    p=${1%/}
    case $p in ""|/) echo "/"; return ;; esac
    base=${p##*/}
    parent=${p%/*}; parent=${parent##*/}
    if [ -n "$parent" ]; then echo "$parent/$base"; else echo "$base"; fi
}

# is NAME an untouched default tab name ("Tab #3")?
is_default() { case $1 in "Tab #"[0-9]*) return 0 ;; *) return 1 ;; esac; }

# apply DESIRED to tab ID (whose current name is CURRENT), honoring stickiness
apply() {  # apply ID CURRENT DESIRED
    _id=$1; _cur=$2; _want=$3
    [ -n "$_want" ] || return 0
    _f="$STATE/$_id"
    _last=""; [ -f "$_f" ] && _last=$(cat "$_f" 2>/dev/null)
    if is_default "$_cur" || [ "$_cur" = "$_last" ]; then
        [ "$_cur" != "$_want" ] && { zellij action rename-tab-by-id "$_id" "$_want" 2>/dev/null || return 0; }
        printf '%s' "$_want" > "$_f" 2>/dev/null
    fi
    # else: a name you set yourself -> leave it be
}

case ${1:-refresh} in
    self|set)
        # Name the current tab — but only if THIS pane is the focused one, so a
        # background pane (e.g. the shell beside nvim in the wide layout) doesn't
        # fight the focused pane for the tab name.
        if [ "$1" = set ]; then want=$2; else want=$(last2 "$PWD"); fi
        [ -n "$want" ] || exit 0
        line=$(zellij action list-panes -a 2>/dev/null | awk -F '  +' -v p="terminal_${ZELLIJ_PANE_ID}" '
            NR==1 { for (i=1;i<=NF;i++) c[$i]=i; next }
            $c["PANE_ID"]==p && $c["FOCUSED"]=="true" { print $c["TAB_ID"] "\t" $c["TAB_NAME"]; exit }')
        id=${line%%"$TAB"*}; cur=${line#*"$TAB"}
        [ -n "$id" ] && [ "$id" != "$line" ] && apply "$id" "$cur" "$want"
        ;;
    *)
        # Refresh every tab from its focused terminal pane.
        zellij action list-panes -a 2>/dev/null | awk -F '  +' '
            NR==1 { for (i=1;i<=NF;i++) c[$i]=i; next }
            $c["TYPE"]=="terminal" && $c["FOCUSED"]=="true" {
                t=$c["TITLE"]
                if (t=="" || t=="-" || t ~ /^Pane #[0-9]+$/) print $c["TAB_ID"] "\tcwd\t"   $c["CWD"]  "\t" $c["TAB_NAME"]
                else                                         print $c["TAB_ID"] "\ttitle\t" t          "\t" $c["TAB_NAME"]
            }' | while IFS="$TAB" read -r id kind val cur; do
                if [ "$kind" = cwd ]; then want=$(last2 "$val"); else want=$val; fi
                apply "$id" "$cur" "$want"
            done
        # Drop state for tabs that no longer exist.
        ids=$(zellij action list-panes -a 2>/dev/null | awk -F '  +' '
            NR==1 { for (i=1;i<=NF;i++) c[$i]=i; next } { print $c["TAB_ID"] }' | sort -u)
        for f in "$STATE"/*; do
            [ -e "$f" ] || continue
            printf '%s\n' "$ids" | grep -qx "${f##*/}" || rm -f "$f"
        done
        ;;
esac
