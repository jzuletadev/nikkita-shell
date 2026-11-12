#!/usr/bin/env bash
# ~/nikkita-shell/scripts/install-greeter.sh
#
# The login screen: dotfiles/quickshell/greeter.qml under greetd. Run it with sudo;
# install.sh does. Run it again after changing the lock or login screen.
#
# greetd runs it as the `greeter` user, who can't read your home. So the QML, the
# fonts and system/greetd are copied to /usr/share/nikkita-shell, and your
# theme, settings, picture and wallpaper go to /var/lib/nikkita-shell, which
# you own and greeter-sync.sh and wallpaper.sh keep current.
#
# If the login screen ever fails: Ctrl+Alt+F2, log in, `uwsm start hyprland.desktop`.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST=/usr/share/nikkita-shell
SHARED=/var/lib/nikkita-shell

[ "$(id -u)" -eq 0 ] || { echo "Run it with sudo." >&2; exit 1; }
OWNER="${SUDO_USER:-}"
[[ -n $OWNER && $OWNER != root ]] || { echo "Run it with sudo from your user: the login screen shows your theme and picture." >&2; exit 1; }
OWNER_HOME=$(getent passwd "$OWNER" | cut -d: -f6)

getent passwd greeter >/dev/null || { echo "greetd isn't installed: sudo pacman -S greetd" >&2; exit 1; }

echo "1. The login screen -> $DEST"
rm -rf "$DEST.new"
install -d "$DEST.new/dotfiles" "$DEST.new/assets" "$DEST.new/system"
cp -rL "$REPO/dotfiles/quickshell" "$DEST.new/dotfiles/"
cp -rL "$REPO/assets/fonts" "$DEST.new/assets/"
cp -rL "$REPO/system/greetd" "$DEST.new/system/"
chmod -R u=rwX,go=rX "$DEST.new"
rm -rf "$DEST"
mv "$DEST.new" "$DEST"
runuser -u "$OWNER" -- env -u HYPRLAND_INSTANCE_SIGNATURE \
    Hyprland --verify-config --config "$DEST/system/greetd/hyprland.lua" >/dev/null ||
    { echo "system/greetd/hyprland.lua has errors: nothing switched" >&2; exit 1; }

echo "2. Your theme, settings, picture and wallpaper -> $SHARED"
install -d -m 755 -o "$OWNER" -g "$(id -gn "$OWNER")" "$SHARED"
runuser -u "$OWNER" -- env HOME="$OWNER_HOME" USER="$OWNER" "$REPO/scripts/greeter-sync.sh"
# wallpaper.sh refreshes it on every change; this is the first one.
if [ ! -f "$SHARED/wallpaper" ]; then
    wall=$(readlink -e "$OWNER_HOME/.local/state/nikkita-shell/wallpaper" ||
           find "$REPO/assets/wallpapers" -maxdepth 1 -type f | sort | head -1)
    if [ -n "$wall" ]; then
        install -m 644 -o "$OWNER" -g "$(id -gn "$OWNER")" "$wall" "$SHARED/wallpaper"
    fi
fi

# Quickshell and Hyprland keep caches in the greeter's home.
greeter_home=$(getent passwd greeter | cut -d: -f6)
if [[ -n $greeter_home && $greeter_home != / && ! -d $greeter_home ]]; then
    install -d -o greeter -g greeter "$greeter_home"
fi

echo "3. greetd -> /etc/greetd/config.toml"
# The first copy is the original: a later run (or the rename's) never replaces it.
if [ -f /etc/greetd/config.toml ] && ! grep -q nikkita-shell /etc/greetd/config.toml &&
    [ ! -f /etc/greetd/config.toml.bak-nikkita ]; then
    cp /etc/greetd/config.toml /etc/greetd/config.toml.bak-nikkita
    echo "   the previous one stays as config.toml.bak-nikkita"
fi
install -Dm644 "$REPO/system/greetd/config.toml" /etc/greetd/config.toml

echo "4. greetd starts at boot"
if systemctl is-enabled --quiet sddm.service 2>/dev/null; then
    systemctl disable sddm.service
fi
systemctl enable greetd.service

echo "5. Your keyring opens with your login (gnome-keyring)"
# Brave, VS Code and other apps keep passwords and tokens in the Secret Service;
# without one they fall back to weak "basic" encryption. pam_gnome_keyring takes
# the password you type at the login screen and unlocks the keyring with it;
# in passwd, it follows a change of that password. `optional`: if the module is
# missing, login goes on as before.
add_pam() {   # add_pam <file> <after this type> <line>
    local file=$1 type=$2 line=$3
    [ -f "$file" ] || return 0
    grep -qF "$line" "$file" && return 0
    [ -f "$file.bak-nikkita" ] || cp "$file" "$file.bak-nikkita"
    # After the last line of that type, so it runs once the stack before it has.
    awk -v type="$type" -v line="$line" '
        { lines[NR] = $0; if ($1 == type) last = NR }
        END { for (i = 1; i <= NR; i++) { print lines[i]; if (i == last) print line } if (!last) print line }
    ' "$file" > "$file.new" && cat "$file.new" > "$file" && rm "$file.new"
}
if [ -f /usr/lib/security/pam_gnome_keyring.so ]; then
    add_pam /etc/pam.d/greetd auth "auth       optional     pam_gnome_keyring.so"
    add_pam /etc/pam.d/greetd session "session    optional     pam_gnome_keyring.so auto_start"
    add_pam /etc/pam.d/passwd password "password   optional     pam_gnome_keyring.so"
    echo "   the previous files stay as greetd.bak-nikkita and passwd.bak-nikkita in /etc/pam.d"
else
    echo "   gnome-keyring isn't installed (sudo pacman -S gnome-keyring): skipped"
fi

# Earlier versions of this desktop used SDDM, with a theme of their own.
rm -rf /usr/share/sddm/themes/arch-neutral /etc/sddm.conf.d/10-arch-neutral.conf /usr/share/backgrounds/current_wallpaper.jpg
if [ -d /usr/share/backgrounds ]; then
    rmdir --ignore-fail-on-non-empty /usr/share/backgrounds
fi
if pacman -Q sddm >/dev/null 2>&1; then
    echo "   SDDM isn't used anymore: sudo pacman -Rs sddm"
fi

echo
echo "The login screen shows from the next boot. If it ever fails: Ctrl+Alt+F2, log in,"
echo "run 'uwsm start hyprland.desktop', and then this script again."
