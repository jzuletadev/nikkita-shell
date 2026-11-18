#!/usr/bin/env bash
# ~/nikita-shell/scripts/minimize.sh

#   minimize.sh window    the focused window
#   minimize.sh all       every window on this workspace
#   minimize.sh restore   all minimized windows, here
#   minimize.sh toggle    all if there's something here, restore otherwise (SUPER+D)
#   minimize.sh hide-all  every window on screen, on every monitor; it notes where
#                         each one was (3 fingers down: one move and nothing shows)
#   minimize.sh show-all  those back where they were (3 fingers up); with nothing
#                         noted, the minimized ones come here, as `restore`

PARKING="special:minimized"

active_ws() {
    hyprctl activeworkspace -j | python3 -c '
import json,sys
w = json.load(sys.stdin)
# Special workspaces have no `id`, only `name` (special:minimized).
print(w.get("id", w.get("name", "")))'
}

addresses() {   # addresses <workspace name or id>: the windows on it
    hyprctl clients -j | python3 -c '
import json, sys
target = sys.argv[1]
for c in json.load(sys.stdin):
    ws = c["workspace"]
    if target in (str(ws.get("id")), ws.get("name", "")):
        print(c["address"])' "$1"
}

# `follow = false`: the old movetoworkspacesilent.
move_all() {   # move_all <from> <to>: one batch, so it's a single redraw
    local batch="" address
    for address in $(addresses "$1"); do
        batch+="dispatch hl.dsp.window.move({ workspace = \"$2\", window = \"address:$address\", follow = false });"
    done
    [ -n "$batch" ] && hyprctl --batch "$batch" >/dev/null
}

# What hide-all moved away: "address workspace" a line, until show-all.
NOTED="${XDG_RUNTIME_DIR:-/tmp}/nikita-hidden-windows"

hide_all() {
    local lines
    # The windows on each monitor's visible workspace.
    lines=$(hyprctl -j monitors | python3 -c '
import json, subprocess, sys
shown = {str(m["activeWorkspace"]["id"]) for m in json.load(sys.stdin)}
clients = json.loads(subprocess.run(["hyprctl", "-j", "clients"], capture_output=True, text=True).stdout)
for c in clients:
    ws = str(c["workspace"].get("id"))
    if ws in shown:
        print(c["address"], ws)')
    [ -n "$lines" ] || return 0
    local batch="" address ws
    while read -r address ws; do
        batch+="dispatch hl.dsp.window.move({ workspace = \"$PARKING\", window = \"address:$address\", follow = false });"
    done <<< "$lines"
    hyprctl --batch "$batch" >/dev/null
    # Added to what an earlier hide-all noted, so two in a row lose nothing.
    printf '%s\n' "$lines" >> "$NOTED"
}

show_all() {
    if [ ! -s "$NOTED" ]; then
        move_all "$PARKING" "$(active_ws)"
        return
    fi
    local parked batch="" address ws
    parked=$(addresses "$PARKING")
    while read -r address ws; do
        # Only those still parked: one closed or brought back meanwhile is skipped.
        grep -qx "$address" <<< "$parked" || continue
        batch+="dispatch hl.dsp.window.move({ workspace = \"$ws\", window = \"address:$address\", follow = false });"
    done < "$NOTED"
    rm -f "$NOTED"
    [ -n "$batch" ] && hyprctl --batch "$batch" >/dev/null
}

case "${1:-}" in
    window)  hyprctl dispatch "hl.dsp.window.move({ workspace = \"$PARKING\", follow = false })" >/dev/null ;;
    all)     move_all "$(active_ws)" "$PARKING" ;;
    restore) move_all "$PARKING" "$(active_ws)" ;;
    toggle)
        here=$(active_ws)
        if [ -n "$(addresses "$here")" ]; then move_all "$here" "$PARKING"; else move_all "$PARKING" "$here"; fi ;;
    hide-all) hide_all ;;
    show-all) show_all ;;
    *)       echo "usage: minimize.sh window|all|restore|toggle|hide-all|show-all" >&2; exit 2 ;;
esac
