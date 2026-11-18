#!/usr/bin/env bash
# ~/nikita-shell/scripts/greeter-sync.sh
#
# Copies what the login screen shows of you (theme, clock format, picture) and the
# monitor layout you kept in Settings → Display to /var/lib/nikita-shell,
# which it can read. Quickshell runs it whenever the
# theme or the settings load; it does nothing until install-greeter.sh made that folder.

set -euo pipefail

SHARED=/var/lib/nikita-shell
STATE="$HOME/.local/state/nikita-shell"

[ -w "$SHARED" ] || exit 0

# A temporary file of its own each time: two runs at once must not share one.
for f in theme settings.json; do
    if [ -f "$STATE/$f" ]; then
        tmp=$(mktemp "$SHARED/.$f.XXXXXX")
        cp "$STATE/$f" "$tmp"
        chmod 644 "$tmp"
        mv -f "$tmp" "$SHARED/$f"
    fi
done

# The monitor layout, as plain data: "output mode position scale transform" or
# "output disabled", a line each. The login screen's Hyprland reads and checks it
# (system/greetd/hyprland.lua); it never runs a file you can write.
if [ -f "$STATE/monitors.lua" ]; then
    tmp=$(mktemp "$SHARED/.monitors.XXXXXX")
    sed -nE \
        -e 's/.*output = "([A-Za-z0-9_.-]+)", mode = "([0-9]+x[0-9]+@[0-9.]+)", position = "(-?[0-9]+x-?[0-9]+)", scale = ([0-9.]+), transform = ([0-7]).*/\1 \2 \3 \4 \5/p' \
        -e 's/.*output = "([A-Za-z0-9_.-]+)", disabled = true.*/\1 disabled/p' \
        "$STATE/monitors.lua" > "$tmp"
    chmod 644 "$tmp"
    mv -f "$tmp" "$SHARED/monitors"
else
    rm -f "$SHARED/monitors"
fi

mkdir -p "$SHARED/faces"
if [ -f "$HOME/.face" ]; then
    cp "$HOME/.face" "$SHARED/faces/$USER"
else
    rm -f "$SHARED/faces/$USER"
fi

# The login screen offers this user first.
echo "$USER" > "$SHARED/user"
