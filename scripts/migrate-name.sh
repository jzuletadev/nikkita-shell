#!/usr/bin/env bash
# ~/nikita-shell/scripts/migrate-name.sh
#
# Once, on a computer that has this desktop under an earlier name: moves what was
# installed to the current one, nikita-shell (short: nikita). It was first
# hyprland-from-scratch (hfs), then nikkita-shell (nikkita). Each step looks first and
# is skipped once done, so running it again is safe. The old names below are on
# purpose: they are what it looks for.
#
#   scripts/migrate-name.sh              as you, right after `git pull`: the repo folder
#                                        (the old path stays as a link to ~/nikita-shell),
#                                        your settings and caches, ~/.config's links, the
#                                        shell's service, hypridle
#   sudo scripts/migrate-name.sh system  then root's part: /etc's folder, the firewall
#                                        and charge limit services, the login screen,
#                                        the copies the installers kept of your files
#
# Once you have logged in again, the links the first part leaves can go: the second
# part lists them.

set -uo pipefail

NEW=nikita-shell
SHORT=nikita
OLD_NAMES=(hyprland-from-scratch nikkita-shell)   # oldest first: the latest copy wins
OLD_SHORTS=(hfs nikkita)

say() { echo "· $*"; }

as_user() {
    [ "$(id -u)" != 0 ] || { echo "First as yourself: $0; then sudo $0 system." >&2; exit 1; }
    cd "$HOME" || exit 1
    local old changed=false

    # The repo. What still has the old path open (an editor) goes on working through
    # the link. A link at the new name is only a bridge to the old folder.
    for old in "${OLD_NAMES[@]}"; do
        if [ -d "$old" ] && [ ! -L "$old" ]; then
            [ -L "$NEW" ] && rm "${NEW:?}"
            [ -e "$NEW" ] && { echo "~/$NEW already exists: move ~/$old yourself, then run this again." >&2; exit 1; }
            mv "$old" "$NEW" && ln -s "$NEW" "$old" || exit 1
            changed=true
            say "the repo is now ~/$NEW (~/$old is a link to it)"
        fi
    done
    [ -d "$NEW/scripts" ] && [ ! -L "$NEW" ] || { echo "~/$NEW isn't this repo." >&2; exit 1; }
    # A link left by an earlier rename would go through one that can be removed.
    for old in "${OLD_NAMES[@]}"; do
        if [ -L "$old" ] && [ "$(readlink "$old")" != "$NEW" ] && [ "$(readlink -f "$old")" = "$(readlink -f "$NEW")" ]; then
            ln -sfn "$NEW" "$old" || exit 1
        fi
    done

    # Settings, notifications, clipboard (state) and the music covers (cache). The new
    # name may be a bridge to the old folder (never copy a folder onto itself), or a
    # fresh folder the desktop made after git pull: yours wins.
    local base from to
    for base in "$HOME/.local/state" "${XDG_CACHE_HOME:-$HOME/.cache}"; do
        for old in "${OLD_NAMES[@]}"; do
            from="$base/$old" to="$base/$NEW"
            if [ -d "$from" ] && [ ! -L "$from" ]; then
                [ -L "$to" ] && rm "${to:?}"
                if [ -e "$to" ]; then
                    cp -a "$from/." "$to/" && rm -rf "${from:?}" || exit 1
                else
                    mv "$from" "$to" || exit 1
                fi
                ln -s "$NEW" "$from" || exit 1
                changed=true
                say "moved ${from#"$HOME/"} to ${to#"$HOME/"}"
            fi
        done
        # Links from an earlier rename, once the real folder is in place.
        for old in "${OLD_NAMES[@]}"; do
            from="$base/$old" to="$base/$NEW"
            if [ -L "$from" ] && [ "$(readlink "$from")" != "$NEW" ] && [ -d "$to" ] && [ ! -L "$to" ]; then
                ln -sfn "$NEW" "$from" || exit 1
            fi
        done
    done

    # ~/.config: links into the repo (they would break with the old path's link), or
    # copies carrying its mark.
    local cfg="${XDG_CONFIG_HOME:-$HOME/.config}" dst target
    for dst in "$cfg"/*; do
        for old in "${OLD_NAMES[@]}"; do
            if [ -L "$dst" ]; then
                target=$(readlink "$dst")
                case "$target" in
                    "$HOME/$old/"*)
                        ln -sfn "$HOME/$NEW/${target#"$HOME/$old/"}" "$dst" || exit 1
                        say "relinked ${dst#"$HOME/"}" ;;
                esac
            elif [ -e "$dst/.$old" ]; then
                mv "$dst/.$old" "$dst/.$NEW" && say "marked ${dst#"$HOME/"} as this desktop's copy"
            fi
        done
    done

    # The shell's service, by its new name. Restarting it closes no app: they run in
    # units of their own.
    local units="$cfg/systemd/user" unit
    for unit in hfs-shell nikkita-shell; do
        [ -f "$units/$unit.service" ] || continue
        install -Dm644 "$HOME/$NEW/system/shell/$NEW.service" "$units/$NEW.service" || exit 1
        systemctl --user daemon-reload
        if systemctl --user is-active --quiet "$unit.service"; then
            systemctl --user stop "$unit.service"
            systemctl --user start "$NEW.service"
        fi
        rm -f "${units:?}/${unit:?}.service"
        systemctl --user daemon-reload
        changed=true
        say "the shell runs as $NEW.service"
    done
    # An old shell's clipboard watchers outlive it and carry its mark; the new one
    # only knows its own.
    local p short
    for p in $(pgrep -x wl-paste); do
        for short in "${OLD_SHORTS[@]}"; do
            if grep -qa "$short-clip" "/proc/$p/cmdline" 2>/dev/null; then
                kill "$p" && say "stopped an old clipboard watcher ($p)"
            fi
        done
    done

    # Hyprland again, with your settings and monitors from their new place.
    hyprctl reload >/dev/null 2>&1 || true
    # hypridle only reads its config at start, and that has the command that locks.
    if $changed && pgrep -x hypridle >/dev/null; then
        pkill -x hypridle
        local i
        for ((i = 0; i < 50; i++)); do
            pgrep -x hypridle >/dev/null || break
            sleep 0.1
        done
        hyprctl dispatch 'hl.dsp.exec_cmd("hypridle")' >/dev/null 2>&1 && say "hypridle started again"
    fi
    echo "Done as you. Now: sudo ~/$NEW/scripts/migrate-name.sh system"
}

as_root() {
    [ "$(id -u)" = 0 ] || { echo "This part needs root: sudo $0 system" >&2; exit 1; }
    local repo owner_home units=/etc/systemd/system old short i
    repo=$(cd "$(dirname "$0")/.." && pwd)
    owner_home=$(getent passwd "${SUDO_USER:-}" | cut -d: -f6)
    [ -n "$owner_home" ] || { echo "Run it with sudo from your user." >&2; exit 1; }
    for old in "${OLD_NAMES[@]}"; do
        if [ -d "$owner_home/$old" ] && [ ! -L "$owner_home/$old" ]; then
            echo "First the part as yourself: ~/$old/scripts/migrate-name.sh" >&2
            exit 1
        fi
    done

    # /etc's folder: the firewall's allow list and rules, the charge limit. What is
    # already in the new one (the firewall turned on from Settings meanwhile) stays.
    for old in "${OLD_NAMES[@]}"; do
        [ -d "/etc/$old" ] || continue
        if [ -e "/etc/$NEW" ]; then
            cp -an "/etc/$old/." "/etc/$NEW/" && rm -rf "/etc/${old:?}" || exit 1
        else
            mv "/etc/$old" "/etc/$NEW" || exit 1
        fi
        say "/etc/$old is now /etc/$NEW"
    done

    # The firewall: the new service starts first, from the same allow list, and only
    # then the old one stops (taking its table with it), so nothing gets through in
    # between. On or off as it was.
    for short in "${OLD_SHORTS[@]}"; do
        [ -f "$units/$short-firewall.service" ] || continue
        local was_on=false
        systemctl is-enabled --quiet "$short-firewall.service" && was_on=true
        "$repo/scripts/firewall.sh" install || exit 1
        systemctl disable --now "$short-firewall.service"
        rm -f "${units:?}/${short:?}-firewall.service"
        systemctl daemon-reload
        $was_on || "$repo/scripts/firewall.sh" off
        say "the firewall runs as $SHORT-firewall.service"
    done

    # The charge limit: the same limit, from the new service.
    for i in "${!OLD_SHORTS[@]}"; do
        short=${OLD_SHORTS[$i]} old=${OLD_NAMES[$i]}
        [ -f "$units/$short-charge-limit.service" ] || continue
        local limit=""
        [ -r "/etc/$NEW/charge-limit" ] && limit=$(tr -cd '0-9' < "/etc/$NEW/charge-limit")
        systemctl disable --quiet "$short-charge-limit.service" 2>/dev/null
        rm -f "${units:?}/${short:?}-charge-limit.service"
        rm -rf "/usr/local/lib/${old:?}"
        systemctl daemon-reload
        if [ -n "$limit" ]; then
            "$repo/scripts/charge-limit.sh" set "$limit" || exit 1
        fi
        say "the charge limit runs as $SHORT-charge-limit.service"
    done

    # The copies the installers kept of your files are still the originals. Before the
    # login screen: install-greeter.sh would take the old config for someone else's.
    local f to
    for short in "${OLD_SHORTS[@]}"; do
        for f in "/etc/pacman.conf.bak-$short" "/etc/greetd/config.toml.bak-$short" /etc/pam.d/*".bak-$short"; do
            to="${f%".bak-$short"}.bak-$SHORT"
            [ -f "$f" ] && [ ! -e "$to" ] || continue
            mv "$f" "$to" && say "$f is now $to"
        done
    done

    # The login screen, copied to its new place; the old copies go once greetd points there.
    local stale=() d
    for old in "${OLD_NAMES[@]}"; do
        [ -d "/usr/share/$old" ] && stale+=("/usr/share/$old")
        [ -d "/var/lib/$old" ] && stale+=("/var/lib/$old")
    done
    if (( ${#stale[@]} )); then
        "$repo/scripts/install-greeter.sh" || exit 1
        for d in "${stale[@]}"; do
            rm -rf "${d:?}"
        done
        say "the login screen reads /usr/share/$NEW and /var/lib/$NEW"
    fi

    echo "Done. Once you have logged in again, these links can go:"
    local base
    for old in "${OLD_NAMES[@]}"; do
        for base in "$owner_home" "$owner_home/.local/state" "$owner_home/.cache"; do
            [ -L "$base/$old" ] && echo "  $base/$old"
        done
    done
}

case "${1:-user}" in
    user) as_user ;;
    system) as_root ;;
    *) echo "usage: migrate-name.sh [system]" >&2; exit 2 ;;
esac
