#!/usr/bin/env bash
# ~/nikita-shell/scripts/updates.sh
#
# Package updates, for the desktop (services/Updates.qml).
#   updates.sh check     JSON on stdout: {"repo": [{"name", "from", "to"}], "aur": [...]}.
#                        checkupdates (pacman-contrib) reads a copy of the package
#                        database: no root, and it never leaves the system half
#                        updated. AUR ones through paru, when it's installed.
#   updates.sh install   updates everything in this terminal, then has the desktop
#                        check again.

set -uo pipefail

case "${1:-check}" in
check)
    command -v checkupdates >/dev/null ||
        { echo "checkupdates isn't installed: sudo pacman -S pacman-contrib" >&2; exit 1; }
    err=$(mktemp)
    trap 'rm -f "$err"' EXIT
    repo=$(checkupdates 2>"$err")
    rc=$?
    # 0: there are updates, 2: there are none; anything else failed.
    if [ $rc -ne 0 ] && [ $rc -ne 2 ]; then
        tail -n1 "$err" >&2
        exit 1
    fi
    aur=""
    if command -v paru >/dev/null; then
        aur=$(paru -Qua 2>/dev/null | grep -v '\[ignored\]') || true
    fi
    python3 -I -c '
import json, sys
def parse(text):
    out = []
    for line in text.splitlines():
        p = line.split()
        if len(p) >= 4 and p[2] == "->":
            out.append({"name": p[0], "from": p[1], "to": p[3]})
    return out
print(json.dumps({"repo": parse(sys.argv[1]), "aur": parse(sys.argv[2])}))
' "$repo" "$aur"
    ;;
install)
    echo "Updating the system (pacman asks for your password)."
    sudo pacman -Syu
    if command -v paru >/dev/null; then
        echo
        echo "AUR packages (paru):"
        paru -Sua
    fi
    qs ipc call nikita updates >/dev/null 2>&1
    echo
    read -rp "Done. Press Enter to close. " _
    ;;
*)
    echo "usage: updates.sh check|install" >&2
    exit 2
    ;;
esac
