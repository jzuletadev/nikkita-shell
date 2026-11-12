#!/usr/bin/env bash
# ~/nikkita-shell/scripts/color-pick.sh
#
# Pick a color anywhere on the screen (hyprpicker): its hex goes to the clipboard
# and a notification shows it, with a swatch. Escape picks nothing, silently.
# SUPER+SHIFT+C and the launcher ("Pick a color") run it.

set -uo pipefail

fail() {
    notify-send -a Desktop -i dialog-warning-symbolic "Picking a color didn't work" "$1"
    exit 1
}

command -v hyprpicker >/dev/null || fail "hyprpicker isn't installed: sudo pacman -S hyprpicker"

err=$(mktemp)
trap 'rm -f "$err"' EXIT
color=$(hyprpicker --format=hex --autocopy --no-fancy --quiet 2>"$err") || fail "$(tail -n1 "$err")"
color=$(printf '%s' "$color" | tr -d '[:space:]')
[ -n "$color" ] || exit 0   # Escape

hex=${color#\#}
rgb="rgb($((16#${hex:0:2})), $((16#${hex:2:2})), $((16#${hex:4:2})))"

# A swatch for the notification; without one, the text says it all.
swatch="${XDG_RUNTIME_DIR:-/tmp}/nikkita-color-swatch.png"
icon=color-select-symbolic
if ffmpeg -loglevel error -y -f lavfi -i "color=c=0x${hex}:s=64x64" -frames:v 1 "$swatch" 2>/dev/null; then
    icon=$swatch
fi
notify-send -a Desktop -i "$icon" "Copied $color" "$rgb"
