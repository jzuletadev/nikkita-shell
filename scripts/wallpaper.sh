#!/usr/bin/env bash
# ~/nikita-shell/scripts/wallpaper.sh — wallpaper backend (awww, the lock and login screens)
#
#   wallpaper.sh set FILE [peek|calm]
#                                 a new wallpaper, on every monitor. `peek` hides every
#                                 window while it arrives (and brings them back); `calm`
#                                 changes it at once, with no transition
#   wallpaper.sh restore          the current one, on every monitor (at login)
#   wallpaper.sh output NAME      the current one on that monitor only: hyprland.lua
#                                 runs it when a monitor is plugged in, which awww
#                                 would otherwise leave black

set -uo pipefail

REPO="$HOME/nikita-shell"
DEFAULT_DIR="$HOME/Pictures/wallpapers"
CURRENT="$HOME/.local/state/nikita-shell/wallpaper"
LOGIN="/var/lib/nikita-shell"

notify()   { notify-send -a Wallpaper "Wallpaper" "$1"; }
is_image() { [ -f "$1" ] && [[ "${1,,}" =~ \.(jpe?g|png|webp|gif|bmp)$ ]]; }

wait_daemon() {
    local i
    for ((i = 0; i < 50; i++)); do
        awww query >/dev/null 2>&1 && return 0
        sleep 0.1
    done
    return 1
}

apply() {   # apply <file> <transition-type> [seconds]
    wait_daemon || { notify "awww-daemon isn't running"; return 1; }
    awww img "$1" --transition-type "$2" --transition-pos center --transition-duration "${3:-1.2}" --transition-fps 60 || return 1
    mkdir -p "$(dirname "$CURRENT")"
    ln -sfn "$1" "$CURRENT"
    if [ -w "$LOGIN" ]; then
        { cp -f "$1" "$LOGIN/.wallpaper.tmp" && mv -f "$LOGIN/.wallpaper.tmp" "$LOGIN/wallpaper"; } ||
            notify "Couldn't update the login screen's wallpaper"
    fi
    return 0
}

# The windows out of the way while the picture arrives, and back after (also if this
# is killed meanwhile). Nothing to hide, nothing to wait for.
# shortcut: fixed waits (they leaving, the transition and a look), awww says nothing
# when a transition ends; upgrade if it ever does.
peek() {   # peek <file>
    local hidden=0 shown
    shown=$(hyprctl -j clients 2>/dev/null | python3 -c 'import json,sys; print(len([c for c in json.load(sys.stdin) if c["mapped"] and not c["hidden"]]))')
    if [ "${shown:-0}" -gt 0 ]; then
        hidden=1
        trap '"$REPO/scripts/minimize.sh" show-all' EXIT
        "$REPO/scripts/minimize.sh" hide-all
        sleep 0.6
    fi
    # The same circle growing from the center as without peek, only slower: the desktop is clear, so it is all there is to see.
    apply "$1" grow 1.8 || return 1
    if [ "$hidden" = 1 ]; then
        sleep 2.8
        "$REPO/scripts/minimize.sh" show-all
        trap - EXIT
        # Settings asked for this: it gets the keyboard back.
        hyprctl dispatch 'hl.dsp.focus({ window = "title:^Settings$" })' >/dev/null 2>&1
    fi
}

set_file() {
    local file
    file=$(realpath -e -- "${1:-}" 2>/dev/null) || { notify "File not found: ${1:-}"; exit 1; }
    is_image "$file" || { notify "Not an image: $(basename "$file")"; exit 1; }
    # A success is only a toast (transient): the history keeps what went wrong.
    case "${2:-}" in
        peek) peek "$file" ;;
        calm) apply "$file" none ;;
        *)    apply "$file" grow ;;
    esac && notify-send -a Wallpaper --transient "Wallpaper" "$(basename "$file")"
}

restore() {
    local file
    if ! file=$(readlink -e "$CURRENT" 2>/dev/null); then
        file=$(find "$DEFAULT_DIR" -maxdepth 1 -type f -print0 2>/dev/null | sort -z |
               while IFS= read -r -d '' f; do is_image "$f" && { printf '%s' "$f"; break; }; done)
    fi
    [ -n "$file" ] || { notify "No wallpaper found in ~/Pictures/wallpapers"; return 1; }
    apply "$file" fade
}

# The current wallpaper on one monitor, once awww knows it (it may come a moment
# after Hyprland's event). Nothing else changes: not the saved one, not the others.
output() {
    local name=${1:-} file i
    [ -n "$name" ] || { echo "usage: wallpaper.sh output NAME" >&2; exit 2; }
    file=$(readlink -e "$CURRENT" 2>/dev/null) || { restore; return; }
    wait_daemon || { notify "awww-daemon isn't running"; return 1; }
    for ((i = 0; i < 50; i++)); do
        awww query 2>/dev/null | grep -q ": $name:" && break
        sleep 0.1
    done
    awww img "$file" --outputs "$name" --transition-type fade --transition-duration 1.2 --transition-fps 60 ||
        { notify "Couldn't put the wallpaper on $name"; return 1; }
}

case "${1:-restore}" in
    set)     set_file "${2:-}" "${3:-}" ;;
    restore) restore ;;
    output)  output "${2:-}" ;;
    *)       echo "usage: wallpaper.sh [set FILE | restore | output NAME]" >&2; exit 2 ;;
esac
