#!/usr/bin/env bash
# ~/nikkita-shell/scripts/theme-manager.sh
#
# Dark or light theme, saved in ~/.local/state/nikkita-shell/theme.
#
#   theme-manager.sh dark | light   set that theme
#   theme-manager.sh toggle         switch to the other one
#   theme-manager.sh                reapply the saved one (dark if there is none)
#
# Quickshell watches the file; hyprland.lua reads it for the border grays (hence the
# reload). GTK4 apps, kitty and browsers follow GTK's color-scheme through the portal;
# GTK3 apps only read settings.ini, when they start.

set -u

STATE="$HOME/.local/state/nikkita-shell/theme"
GTK3="$HOME/.config/gtk-3.0/settings.ini"

current=$(cat "$STATE" 2>/dev/null)
[ "$current" = light ] || current=dark

case "${1:-$current}" in
    dark | light) theme=${1:-$current} ;;
    toggle) if [ "$current" = dark ]; then theme=light; else theme=dark; fi ;;
    *) echo "usage: $(basename "$0") [dark|light|toggle]" >&2; exit 2 ;;
esac

mkdir -p "$(dirname "$STATE")" "$(dirname "$GTK3")"
echo "$theme" > "$STATE"

if [ "$theme" = dark ]; then scheme=prefer-dark; dark=1; else scheme=prefer-light; dark=0; fi
gsettings set org.gnome.desktop.interface color-scheme "$scheme" 2>/dev/null || true

# GTK3: only the dark-mode key; the rest of settings.ini belongs to the user.
if grep -q '^gtk-application-prefer-dark-theme=' "$GTK3" 2>/dev/null; then
    sed -i "s/^gtk-application-prefer-dark-theme=.*/gtk-application-prefer-dark-theme=$dark/" "$GTK3"
elif grep -q '^\[Settings\]' "$GTK3" 2>/dev/null; then
    sed -i "/^\[Settings\]/a gtk-application-prefer-dark-theme=$dark" "$GTK3"
else
    printf '[Settings]\ngtk-application-prefer-dark-theme=%s\n' "$dark" >> "$GTK3"
fi

hyprctl reload >/dev/null 2>&1 || true
