#!/usr/bin/env bash
# ~/nikkita-shell/scripts/migrate-name.sh
#
# Once, on a computer that has this desktop under its first name, hyprland-from-scratch:
# moves what was installed to the new one, nikkita-shell (the short name hfs became
# nikkita). Each step looks first and is skipped once done, so running it again is safe.
# The old names below are on purpose: they are what it looks for.
#
#   scripts/migrate-name.sh              as you, right after `git pull`: the repo folder
#                                        (~/hyprland-from-scratch stays as a link to
#                                        ~/nikkita-shell), your settings and caches,
#                                        ~/.config's links, the shell's service
#   sudo scripts/migrate-name.sh system  then root's part: /etc's folder, the firewall
#                                        and charge limit services, the login screen,
#                                        the copies the installers kept of your files
#
# Once you have logged in again, the three links the first part leaves can go:
#   rm ~/hyprland-from-scratch ~/.local/state/hyprland-from-scratch ~/.cache/hyprland-from-scratch

set -uo pipefail

OLD=hyprland-from-scratch
NEW=nikkita-shell

say() { echo "· $*"; }

as_user() {
    [ "$(id -u)" != 0 ] || { echo "First as yourself: $0; then sudo $0 system." >&2; exit 1; }
    cd "$HOME" || exit 1

    # The repo. What still has the old path open (an editor; hypridle, until you log
    # in again) goes on working through the link.
    if [ -d "$OLD" ] && [ ! -L "$OLD" ]; then
        [ -L "$NEW" ] && rm "$NEW"
        [ -e "$NEW" ] && { echo "~/$NEW already exists: move ~/$OLD yourself, then run this again." >&2; exit 1; }
        mv "$OLD" "$NEW" && ln -s "$NEW" "$OLD" || exit 1
        say "the repo is now ~/$NEW (~/$OLD is a link to it)"
    fi
    [ -d "$NEW/scripts" ] || { echo "~/$NEW isn't this repo." >&2; exit 1; }

    # Settings, notifications, clipboard (state) and the music covers (cache). The
    # desktop may already have made a fresh folder under the new name, since it reloads
    # as soon as git pull changes it: yours wins.
    local base old new
    for base in "$HOME/.local/state" "${XDG_CACHE_HOME:-$HOME/.cache}"; do
        old="$base/$OLD" new="$base/$NEW"
        if [ -d "$old" ] && [ ! -L "$old" ]; then
            mkdir -p "$new" && cp -a "$old/." "$new/" && rm -rf "$old" && ln -s "$NEW" "$old" || exit 1
            say "moved ${old#"$HOME/"} to ${new#"$HOME/"}"
        fi
    done

    # ~/.config: links into the repo (they would break with the old path's link), or
    # copies carrying its mark.
    local cfg="${XDG_CONFIG_HOME:-$HOME/.config}" dst target
    for dst in "$cfg"/*; do
        if [ -L "$dst" ]; then
            target=$(readlink "$dst")
            case "$target" in
                "$HOME/$OLD/"*)
                    ln -sfn "$HOME/$NEW/${target#"$HOME/$OLD/"}" "$dst" || exit 1
                    say "relinked ${dst#"$HOME/"}" ;;
            esac
        elif [ -e "$dst/.$OLD" ]; then
            mv "$dst/.$OLD" "$dst/.$NEW" && say "marked ${dst#"$HOME/"} as this desktop's copy"
        fi
    done

    # The shell's service, by its new name. Restarting it closes no app: they run in
    # units of their own.
    local units="$cfg/systemd/user"
    if [ -f "$units/hfs-shell.service" ]; then
        install -Dm644 "$HOME/$NEW/system/shell/nikkita-shell.service" "$units/nikkita-shell.service" || exit 1
        systemctl --user daemon-reload
        if systemctl --user is-active --quiet hfs-shell.service; then
            systemctl --user stop hfs-shell.service
            systemctl --user start nikkita-shell.service
        fi
        rm -f "$units/hfs-shell.service"
        systemctl --user daemon-reload
        say "the shell runs as nikkita-shell.service"
    fi
    # The old shell's clipboard watchers outlive it and carry its mark; the new one
    # only knows its own.
    local p
    for p in $(pgrep -x wl-paste); do
        if grep -qa hfs-clip "/proc/$p/cmdline" 2>/dev/null; then
            kill "$p" && say "stopped an old clipboard watcher ($p)"
        fi
    done

    # Hyprland again, with your settings and monitors from their new place.
    hyprctl reload >/dev/null 2>&1 || true
    echo "Done as you. Now: sudo ~/$NEW/scripts/migrate-name.sh system"
}

as_root() {
    [ "$(id -u)" = 0 ] || { echo "This part needs root: sudo $0 system" >&2; exit 1; }
    local repo owner_home units=/etc/systemd/system
    repo=$(cd "$(dirname "$0")/.." && pwd)
    owner_home=$(getent passwd "${SUDO_USER:-}" | cut -d: -f6)
    [ -n "$owner_home" ] || { echo "Run it with sudo from your user." >&2; exit 1; }
    if [ -d "$owner_home/$OLD" ] && [ ! -L "$owner_home/$OLD" ]; then
        echo "First the part as yourself: ~/$OLD/scripts/migrate-name.sh" >&2
        exit 1
    fi

    # /etc's folder: the firewall's allow list and rules, the charge limit.
    if [ -d "/etc/$OLD" ] && [ ! -e "/etc/$NEW" ]; then
        mv "/etc/$OLD" "/etc/$NEW" || exit 1
        say "/etc/$OLD is now /etc/$NEW"
    fi

    # The firewall: the new service starts first, from the same allow list, and only
    # then the old one stops (taking its table with it), so nothing gets through in
    # between. On or off as it was.
    if [ -f "$units/hfs-firewall.service" ]; then
        local was_on=false
        systemctl is-enabled --quiet hfs-firewall.service && was_on=true
        "$repo/scripts/firewall.sh" install || exit 1
        systemctl disable --now hfs-firewall.service
        rm -f "$units/hfs-firewall.service"
        systemctl daemon-reload
        $was_on || "$repo/scripts/firewall.sh" off
        say "the firewall runs as nikkita-firewall.service"
    fi

    # The charge limit: the same limit, from the new service.
    if [ -f "$units/hfs-charge-limit.service" ]; then
        local limit=""
        [ -r "/etc/$NEW/charge-limit" ] && limit=$(tr -cd '0-9' < "/etc/$NEW/charge-limit")
        systemctl disable --quiet hfs-charge-limit.service 2>/dev/null
        rm -f "$units/hfs-charge-limit.service"
        rm -rf "/usr/local/lib/$OLD"
        systemctl daemon-reload
        if [ -n "$limit" ]; then
            "$repo/scripts/charge-limit.sh" set "$limit" || exit 1
        fi
        say "the charge limit runs as nikkita-charge-limit.service"
    fi

    # The copies the installers kept of your files are still the originals.
    local f
    for f in /etc/pacman.conf.bak-hfs /etc/greetd/config.toml.bak-hfs /etc/pam.d/*.bak-hfs; do
        [ -f "$f" ] && [ ! -e "${f%.bak-hfs}.bak-nikkita" ] || continue
        mv "$f" "${f%.bak-hfs}.bak-nikkita" && say "$f is now ${f%.bak-hfs}.bak-nikkita"
    done

    # The login screen, copied to its new place; the old copies go once greetd points there.
    if [ -d "/usr/share/$OLD" ] || [ -d "/var/lib/$OLD" ]; then
        "$repo/scripts/install-greeter.sh" || exit 1
        rm -rf "/usr/share/$OLD" "/var/lib/$OLD"
        say "the login screen reads /usr/share/$NEW and /var/lib/$NEW"
    fi

    echo "Done. Once you have logged in again, three links are left to remove:"
    echo "  rm ~/$OLD ~/.local/state/$OLD ~/.cache/$OLD"
}

case "${1:-user}" in
    user) as_user ;;
    system) as_root ;;
    *) echo "usage: migrate-name.sh [system]" >&2; exit 2 ;;
esac
