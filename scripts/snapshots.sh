#!/usr/bin/env bash
# ~/nikita-shell/scripts/snapshots.sh
#
# A way back from a bad update: on a btrfs root, snapper keeps a snapshot of the
# system before and after every pacman transaction (snap-pac), the last 10 pairs.
# Your home isn't in them: an update never touches it, and rolling the system back
# never takes your files back.
#
#   snapshots.sh status     JSON, no root: {"btrfs", "installed", "configured",
#                           "snapshots": [{"number", "date", "description"}]}
#   snapshots.sh setup      root: install snapper and snap-pac, make the "root"
#                           config, keep 10, no hourly ones, and let you (the user
#                           who ran sudo) list them without root
#   snapshots.sh undo N     root: put back the system files as they were in
#                           snapshot N (snapper undochange N..0). For the files an
#                           update changed: undo the "pre" snapshot of it.
#
# If the system doesn't boot after an update: from the boot menu's fallback, or a
# live USB, `snapper -c root list` and then `snapper -c root undochange N..0`.

set -uo pipefail

need_root() {
    [ "$(id -u)" = 0 ] || { echo "snapshots.sh $1 needs root: sudo $0 $*" >&2; exit 1; }
}
btrfs_root() { [ "$(findmnt -no FSTYPE /)" = btrfs ]; }

case "${1:-status}" in
status)
    btrfs=false; installed=false; configured=false; list="[]"
    btrfs_root && btrfs=true
    command -v snapper >/dev/null && pacman -Q snap-pac >/dev/null 2>&1 && installed=true
    if command -v snapper >/dev/null && out=$(snapper --jsonout -c root list --disable-used-space 2>/dev/null); then
        configured=true
        list=$(printf '%s' "$out" | python3 -I -c '
import json, sys
d = json.load(sys.stdin).get("root", [])
print(json.dumps([{"number": s["number"], "date": s.get("date", ""), "description": s.get("description", "") or s.get("type", "")}
                  for s in d if s.get("number", 0) > 0][-12:]))')
    fi
    printf '{"btrfs": %s, "installed": %s, "configured": %s, "snapshots": %s}\n' "$btrfs" "$installed" "$configured" "$list"
    ;;
setup)
    need_root "$@"
    btrfs_root || { echo "Snapshots need a btrfs root; this one is $(findmnt -no FSTYPE /)." >&2; exit 1; }
    pacman -S --needed --noconfirm snapper snap-pac || exit 1
    if ! snapper -c root get-config >/dev/null 2>&1; then
        snapper -c root create-config / || exit 1
    fi
    who=${SUDO_USER:-${PKEXEC_UID:+$(id -nu "$PKEXEC_UID")}}
    snapper -c root set-config NUMBER_CLEANUP=yes NUMBER_LIMIT=10 NUMBER_LIMIT_IMPORTANT=5 \
        TIMELINE_CREATE=no TIMELINE_CLEANUP=yes ${who:+ALLOW_USERS="$who"} SYNC_ACL=yes || exit 1
    systemctl enable --now snapper-cleanup.timer
    echo "Snapshots are on: one before and one after every pacman run, the last 10 kept."
    ;;
undo)
    need_root "$@"
    n=${2:-}
    case "$n" in ''|*[!0-9]*) echo "usage: snapshots.sh undo N   (a number from \`snapper -c root list\`)" >&2; exit 2 ;; esac
    snapper -c root undochange "$n..0"
    ;;
*)
    echo "usage: snapshots.sh status | setup | undo N" >&2
    exit 2
    ;;
esac
