#!/usr/bin/env bash
# ~/nikita-shell/scripts/audio-check.sh

set -uo pipefail

DELAY=${1:-10}
notify() { command -v notify-send >/dev/null && notify-send -a "Audio" "$@"; }

# ALSA cards that PipeWire knows about but never got to configure.
missing_profile() {
    local cards profiles
    cards=$(pactl list cards 2>/dev/null | grep -c 'Name: alsa_card') || return 1
    profiles=$(pactl list cards 2>/dev/null | grep -c 'Active Profile:')
    [ "$cards" -gt 0 ] && [ "$profiles" -lt "$cards" ]
}

sleep "$DELAY"

# Without PipeWire there is nothing to fix here.
pactl info >/dev/null 2>&1 || exit 0
missing_profile || exit 0

echo "audio-check: a card was left without a profile; restarting wireplumber" >&2
systemctl --user restart wireplumber || exit 1
sleep 4

if missing_profile; then
    notify -u critical "A sound card is still unconfigured"
    exit 1
fi
echo "audio-check: fixed" >&2
