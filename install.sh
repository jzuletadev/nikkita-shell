#!/usr/bin/env bash
# ~/nikkita-shell/install.sh
#
# Installs this desktop on Arch Linux. Run it as your user from ~/nikkita-shell
# (it asks for sudo when it needs it). It shows what it will do and asks before starting.
#
#   ./install.sh                  the desktop; configs are copied into ~/.config
#   ./install.sh --link           the same, but ~/.config/<app> links to this repo: edits are live
#
# Add parts, in any combination:
#   --apps            the apps in packages/apps.txt (Docker, Node, Steam...);
#                     enables [multilib] in /etc/pacman.conf, which Steam needs
#   --aur             paru (an AUR helper; built if missing) and packages/aur.txt
#                     (Brave, VS Code, ble.sh...)
#   --gpu-drivers     drivers for a dedicated GPU, by what it finds (scripts/gpu-drivers.sh):
#                     NVIDIA Turing or newer -> nvidia-open; Maxwell to Volta -> the legacy
#                     580xx driver (AUR); a laptop with integrated + NVIDIA also gets the
#                     hybrid setup. Older GPUs get advice only.
#   --all             --apps, --aur and --gpu-drivers
#
# Integrated and AMD/Intel GPUs need no option: Vulkan and video decoding for them are
# part of the desktop.
#
# Other options:
#   --dry-run         print every command, change nothing
#   -y, --yes         don't ask before starting
#   -h, --help        this text
#
# Safe to run again: after `git pull` to update, or later to add a part
# (./install.sh --aur on an installed desktop only adds what is missing).

set -euo pipefail

REPO="$HOME/nikkita-shell"
MODE=copy
APPS=0 AUR=0 GPU=0 DRY=0 YES=0
for arg in "$@"; do
    case "$arg" in
        --link)          MODE=link ;;
        --apps)          APPS=1 ;;
        --aur)           AUR=1 ;;
        --gpu-drivers|--nvidia-hybrid) GPU=1 ;;
        --all)           APPS=1; AUR=1; GPU=1 ;;
        --dry-run)       DRY=1 ;;
        -y|--yes)        YES=1 ;;
        -h|--help)       sed -n '3,31p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $arg (see ./install.sh --help)" >&2; exit 2 ;;
    esac
done

# ---- helpers ----
bold=$'\033[1m' dim=$'\033[2m' blue=$'\033[1;34m' green=$'\033[1;32m' yellow=$'\033[1;33m' off=$'\033[0m'
step()  { printf '\n%s==>%s %s%s%s\n' "$blue" "$off" "$bold" "$*" "$off"; }
note()  { printf '%s    %s%s\n' "$dim" "$*" "$off"; }
warn()  { printf '%s!!%s %s\n' "$yellow" "$off" "$*"; }
run()   { printf '%s+ %s%s\n' "$dim" "$*" "$off"; (( DRY )) || "$@"; }
packages() {   # packages <list>: the names in packages/<list>, comments stripped
    sed 's/#.*//' "$REPO/packages/$1" | tr -s ' \t' '\n' | grep -v '^$' || true
}
has_multilib() { grep -q '^\[multilib\]' /etc/pacman.conf; }
gpu() { "$REPO/scripts/gpu-drivers.sh" "$@"; }

# ---- checks ----
[ "$(id -u)" -ne 0 ] || { echo "Run it as your user, not root: it uses sudo itself." >&2; exit 1; }
[ "$(cd "$(dirname "$0")" && pwd)" = "$REPO" ] || {
    echo "Clone the repo to $REPO first: configs and scripts refer to that path." >&2; exit 1; }
command -v pacman >/dev/null || { echo "This installer is for Arch Linux (no pacman here)." >&2; exit 1; }

# ---- what to install ----
mapfile -t PKGS < <(packages base.txt)
(( APPS )) && mapfile -t -O "${#PKGS[@]}" PKGS < <(packages apps.txt)
# Graphics, by what is there: Vulkan and video for Intel/AMD always; a dedicated GPU's
# driver with --gpu-drivers. 32-bit ones too when [multilib] is (or will be) on, for Steam.
gpuflags=()
(( GPU )) && gpuflags+=(--dedicated)
(( APPS )) || has_multilib && gpuflags+=(--multilib)
mapfile -t -O "${#PKGS[@]}" PKGS < <(gpu packages "${gpuflags[@]}")
mapfile -t AURPKGS < <( (( AUR )) && packages aur.txt )
# NVIDIA's legacy driver lives in the AUR: then paru is needed even without --aur.
mapfile -t GPUAUR < <( (( GPU )) && gpu aur-packages "${gpuflags[@]}" )
mapfile -t GPUFOUND < <(gpu detect)
# What earlier versions installed and this one replaced, still installed explicitly.
mapfile -t LEFTOVERS < <(packages removed.txt | while read -r p; do pacman -Qqe "$p" 2>/dev/null || true; done)

# ---- the plan ----
printf '\n%sNikkita Shell — installer%s%s\n' "$bold" "$off" "$( (( DRY )) && echo "  (dry run: nothing will change)" )"
echo
echo "  ${green}✓${off} the desktop: ${#PKGS[@]} packages with pacman (system updated first), configs"
echo "    ${dim}$( [ $MODE = link ] && echo "linked to this repo" || echo "copied into ~/.config" ), services, theme, login screen, folders (Music, wallpapers...)${off}"
(( APPS ))   && echo "  ${green}✓${off} apps: packages/apps.txt$(has_multilib || echo ", enabling [multilib] for Steam")"
(( AUR ))    && echo "  ${green}✓${off} AUR: $(command -v paru >/dev/null && echo "paru (already here)" || echo "paru, built from the AUR"), then ${#AURPKGS[@]} packages from packages/aur.txt"
(( GPU ))    && echo "  ${green}✓${off} GPU drivers for what is below$( (( ${#GPUAUR[@]} )) && echo " (the legacy NVIDIA one from the AUR, with paru)")"
(( APPS ))   || echo "  ${dim}· not now: --apps (Docker, Node, Steam...)${off}"
(( AUR ))    || echo "  ${dim}· not now: --aur (Brave, VS Code, ble.sh...)${off}"
(( GPU ))    || echo "  ${dim}· not now: --gpu-drivers (a dedicated GPU's driver: NVIDIA...)${off}"
(( ${#LEFTOVERS[@]} )) && echo "  ${dim}· from earlier versions, replaced now: ${LEFTOVERS[*]} (asked at the end)${off}"
echo
echo "  Graphics found:"
printf '    %s\n' "${GPUFOUND[@]}"
echo
if (( ! YES && ! DRY )); then
    read -rp "Continue? [Y/n] " answer
    [[ -z $answer || $answer =~ ^[YySs] ]] || { echo "Nothing done."; exit 0; }
fi

# =============================================================================
if (( APPS )) && ! has_multilib; then
    step "Enabling [multilib] in /etc/pacman.conf (Steam needs it)"
    note "a copy stays as /etc/pacman.conf.bak-nikkita"
    run sudo cp /etc/pacman.conf /etc/pacman.conf.bak-nikkita
    run sudo sed -i '/^#\[multilib\]$/{s/^#//;n;s/^#//}' /etc/pacman.conf
    if ! (( DRY )) && ! has_multilib; then
        warn "Couldn't find '#[multilib]' to uncomment: enable it by hand and run again. Steam and 32-bit drivers are skipped."
        mapfile -t PKGS < <(printf '%s\n' "${PKGS[@]}" | grep -vE '^(steam|lib32-.*)$')
        mapfile -t GPUAUR < <(printf '%s\n' "${GPUAUR[@]}" | grep -v '^lib32-')
    fi
fi

step "Packages (pacman)"
note "one transaction: the system is updated first (-Syu), as Arch expects when installing"
run sudo pacman -Syu --needed "${PKGS[@]}"
run fc-cache -f

if (( AUR || ${#GPUAUR[@]} )); then
    step "AUR (paru$( (( AUR )) && echo " and packages/aur.txt")$( (( ${#GPUAUR[@]} )) && echo ", NVIDIA's legacy driver"))"
    if ! command -v paru >/dev/null; then
        note "paru isn't here: building it from the AUR (needs base-devel and git)"
        run sudo pacman -S --needed base-devel git
        build=/tmp/paru-build
        (( DRY )) || build=$(mktemp -d)
        run git clone https://aur.archlinux.org/paru.git "$build/paru"
        printf '%s+ (cd %s && makepkg -si)%s\n' "$dim" "$build/paru" "$off"
        (( DRY )) || (cd "$build/paru" && makepkg -si)
        run rm -rf "$build"
    fi
    if (( ${#AURPKGS[@]} + ${#GPUAUR[@]} )); then
        note "paru may show each PKGBUILD for review before building"
        run paru -S --needed "${AURPKGS[@]}" "${GPUAUR[@]}"
    fi
fi

step "Configs into ~/.config ($( [ $MODE = link ] && echo "linked to the repo" || echo "copied" ))"
note "anything already there that isn't ours is kept as <name>.bak-<date>"
if [ $MODE = copy ]; then
    run "$REPO/scripts/link-dotfiles.sh" --copy
else
    run "$REPO/scripts/link-dotfiles.sh"
fi

step "Shell: history, suggestions, fzf (~/.bashrc)"
# ~/.bashrc stays your own (tokens, paths): it only sources ours.
if grep -qF '.config/bash/bashrc' "$HOME/.bashrc" 2>/dev/null; then
    note "already sourced from ~/.bashrc"
else
    echo "+ append to ~/.bashrc: . ~/.config/bash/bashrc"
    (( DRY )) || printf '\n# nikkita-shell: history, suggestions, fzf\n[ -f ~/.config/bash/bashrc ] && . ~/.config/bash/bashrc\n' >> "$HOME/.bashrc"
fi

step "Desktop (Quickshell)"
# Quickshell is the notification server: dunst must not take the D-Bus name first.
run systemctl --user mask dunst.service
run "$REPO/scripts/theme-manager.sh"
# A user service, so systemd brings the shell back if it dies; hyprland.lua starts it.
run install -Dm644 "$REPO/system/shell/nikkita-shell.service" "$HOME/.config/systemd/user/nikkita-shell.service"
run systemctl --user daemon-reload

step "Safety: firewall and snapshots"
note "firewall: nothing may connect to this computer except what you allow (Settings → Network);"
note "SSH stays allowed if sshd is enabled here, so this never locks you out"
other_fw=$( { systemctl is-active --quiet ufw.service && echo ufw; systemctl is-active --quiet firewalld.service && echo firewalld; } || true)
if [ -n "$other_fw" ]; then
    note "$other_fw already runs here: left as it is"
else
    run sudo "$REPO/scripts/firewall.sh" install
fi
if [ "$(findmnt -no FSTYPE /)" = btrfs ]; then
    note "snapshots: one before and one after every pacman run, the last 10 kept (snapper, snap-pac)"
    run sudo "$REPO/scripts/snapshots.sh" setup
else
    note "snapshots: skipped, they need a btrfs root (this one is $(findmnt -no FSTYPE /))"
fi

step "Services"
# NetworkManager drives Wi-Fi through iwd; the desktop's Wi-Fi panel talks to NetworkManager.
echo "+ write /etc/NetworkManager/conf.d/wifi-backend.conf (wifi.backend=iwd)"
if ! (( DRY )); then
    sudo mkdir -p /etc/NetworkManager/conf.d
    printf '[device]\nwifi.backend=iwd\n' | sudo tee /etc/NetworkManager/conf.d/wifi-backend.conf >/dev/null
fi
run sudo systemctl enable NetworkManager.service iwd.service bluetooth.service power-profiles-daemon.service
if (( APPS )) && printf '%s\n' "${PKGS[@]}" | grep -qx docker; then
    run sudo systemctl enable docker.socket
fi

step "Default apps (folders -> Nautilus, images -> Loupe, video and audio -> Celluloid)"
run "$REPO/scripts/default-apps.sh"
# localsearch (Nautilus's background indexer) stays off; Nautilus still searches.
note "Nautilus's background file indexer (localsearch) stays off; search still works"
run systemctl --user mask localsearch-3.service localsearch-control-3.service

step "Folders"
note "~/Pictures/wallpapers (the defaults, without overwriting yours), screenshots,"
note "recordings, and ~/Music with its Playlists folder for the music player"
run mkdir -p "$HOME/Pictures/wallpapers" "$HOME/Pictures/screenshots" "$HOME/Videos/recordings" "$HOME/Music/Playlists"
run cp --update=none "$REPO/assets/wallpapers/"* "$HOME/Pictures/wallpapers/"

step "Login screen (Quickshell, through greetd)"
run sudo "$REPO/scripts/install-greeter.sh"

if (( GPU )); then
    step "GPU drivers: setup"
    gs=()
    [ $MODE = link ] && gs+=(--link)
    (( DRY )) && gs+=(--dry-run)
    gpu setup "${gs[@]}"
fi

if (( ${#LEFTOVERS[@]} )); then
    step "Leftovers from earlier versions"
    note "this desktop replaced them (see packages/removed.txt): ${LEFTOVERS[*]}"
    if (( DRY )); then
        echo "+ sudo pacman -Rs ${LEFTOVERS[*]}   (only if you answer yes)"
    elif (( YES )); then
        note "-y never removes anything; to remove them: sudo pacman -Rs ${LEFTOVERS[*]}"
    else
        read -rp "Remove them? pacman shows what goes and asks again. [y/N] " answer
        if [[ $answer =~ ^[YySs] ]]; then
            sudo pacman -Rs "${LEFTOVERS[@]}" ||
                warn "pacman removed nothing (another package may need one of them): see its message above."
        else
            note "kept; later: sudo pacman -Rs ${LEFTOVERS[*]}"
        fi
    fi
fi

# =============================================================================
step "Done$( (( DRY )) && echo " (dry run: nothing changed)" )"
echo "  1. Reboot and log in."
echo "  2. Tap ${bold}SUPER${off} to search apps, ${bold}SUPER + /${off} for Settings (Shortcuts lists every key)."
echo "  3. Put your music in ~/Music (${bold}SUPER + SHIFT + M${off})."
if (( APPS )) && printf '%s\n' "${PKGS[@]}" | grep -qx docker && ! id -nG "$USER" | grep -qw docker; then
    echo "  · Docker without sudo: sudo usermod -aG docker $USER, then log out and in"
    echo "    ${dim}(the docker group is as powerful as root)${off}"
fi
if (( GPU )) && printf '%s\n' "${GPUFOUND[@]}" | grep -q '^hybrid laptop'; then
    echo "  · Games on the NVIDIA GPU: launch options in Steam -> prime-run %command%"
fi
(( AUR ))    || echo "  · Later, Brave, VS Code and terminal suggestions: ./install.sh --aur"
(( APPS ))   || echo "  · Later, Docker, Node and Steam: ./install.sh --apps"
# A GPU that needs its driver and didn't get it, and GPUs this installer can't handle.
if (( ! GPU )) && printf '%s\n' "${GPUFOUND[@]}" | grep -qE 'nvidia-open|nvidia-580xx'; then
    warn "Your NVIDIA GPU needs its driver: run ./install.sh --gpu-drivers before rebooting."
fi
gpu advice | while IFS= read -r line; do warn "$line"; done
