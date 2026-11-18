#!/usr/bin/env bash
# ~/nikita-shell/scripts/gpu-drivers.sh
#
# Graphics drivers: what this machine has, and what each GPU needs. install.sh uses it
# (Mesa's part always, the rest with --gpu-drivers); it can also run alone.
#
#   gpu-drivers.sh detect                         what was found, and what it gets
#   gpu-drivers.sh packages [--dedicated] [--multilib]
#                                                 pacman packages: Vulkan and video decoding
#                                                 for Intel/AMD always; NVIDIA's with --dedicated
#   gpu-drivers.sh aur-packages [--multilib]      AUR packages (NVIDIA's legacy driver), if needed
#   gpu-drivers.sh setup [--link] [--dry-run]     after installing: NVIDIA's module options,
#                                                 early modules, suspend; on a hybrid laptop
#                                                 also the GPU order and names
#   gpu-drivers.sh advice                         GPUs it doesn't handle, and where to look
#
# Intel and AMD GPUs, integrated or not, run on Mesa and drivers already in the kernel:
# they only need Vulkan and hardware video decoding. NVIDIA goes by generation (its PCI
# device id):
#
#   Turing or newer: GTX 16, RTX 20/30/40/50    id >= 0x1E00    nvidia-open (official repo)
#   Maxwell, Pascal, Volta: GTX 900/10           0x1340-0x1DFF   nvidia-580xx, the legacy
#                                                                branch for them (AUR)
#   Kepler and older                             < 0x1340        not handled: advice only
#
# A laptop with an Intel/AMD GPU plus an NVIDIA one is "hybrid": the desktop draws on the
# integrated GPU and NVIDIA runs what asks for it (`prime-run`).
#
# GPU_SYSFS points it at another /sys (tests).

set -euo pipefail

REPO="$HOME/nikita-shell"
SRC="$REPO/system/nvidia"
SYS="${GPU_SYSFS:-/sys}"

# ---- what is there ----
name_of() {   # name_of <vendor> <device>: the marketing name, from hwdata
    awk -v v="${1#0x}" -v d="${2#0x}" '
        /^[0-9a-f]{4} / { in_vendor = ($1 == v) }
        in_vendor && /^\t[0-9a-f]{4} / && $1 == d { sub(/^\t[0-9a-f]{4} +/, ""); print; exit }
    ' /usr/share/hwdata/pci.ids 2>/dev/null || true
}

INTEL=0 AMD=0 AMD_OLD="" NV_KIND="" NV_NAME="" NV_ID="" IGPU_DRIVER=""
FOUND=()
for dev in "$SYS"/bus/pci/devices/*; do
    [ -r "$dev/class" ] || continue
    class=$(<"$dev/class")
    [[ $class == 0x0300* || $class == 0x0302* || $class == 0x0380* ]] || continue
    vendor=$(<"$dev/vendor")
    device=$(<"$dev/device")
    driver=$(basename "$(readlink -f "$dev/driver" 2>/dev/null || echo none)")
    name=$(name_of "$vendor" "$device")
    name=${name:-"$vendor:$device"}
    case $vendor in
        0x8086)
            INTEL=1
            [[ -z $IGPU_DRIVER ]] && IGPU_DRIVER=$([[ $driver == xe ]] && echo xe || echo i915)
            FOUND+=("$name|Intel|Mesa, plus Vulkan and video decoding") ;;
        0x1002)
            if [[ $driver == radeon ]]; then
                AMD_OLD=$name
                FOUND+=("$name|AMD, old (radeon driver)|not handled: see the advice")
            else
                AMD=1
                [[ -z $IGPU_DRIVER ]] && IGPU_DRIVER=amdgpu
                FOUND+=("$name|AMD|Mesa, plus Vulkan and video decoding")
            fi ;;
        0x10de)
            NV_NAME=$name
            NV_ID=$device
            if (( device >= 0x1E00 )); then
                NV_KIND=open
                FOUND+=("$name|NVIDIA, Turing or newer|nvidia-open, the official driver")
            elif (( device >= 0x1340 )); then
                NV_KIND=legacy
                FOUND+=("$name|NVIDIA, Maxwell to Volta|nvidia-580xx, the legacy driver for it (AUR)")
            else
                NV_KIND=unsupported
                FOUND+=("$name|NVIDIA, Kepler or older|not handled: see the advice")
            fi ;;
    esac
done

chassis=$(cat "$SYS/class/dmi/id/chassis_type" 2>/dev/null || echo 0)
LAPTOP=0
case " 8 9 10 11 14 30 31 32 " in *" $chassis "*) LAPTOP=1 ;; esac
compgen -G "$SYS/class/power_supply/BAT*" >/dev/null && LAPTOP=1

HYBRID=0
[[ ( $NV_KIND == open || $NV_KIND == legacy ) && -n $IGPU_DRIVER && $LAPTOP == 1 ]] && HYBRID=1

headers() {   # the headers of every installed kernel (DKMS builds the driver for each)
    local k out=()
    for k in linux linux-lts linux-zen linux-hardened; do
        pacman -Qq "$k" >/dev/null 2>&1 && out+=("$k-headers")
    done
    printf '%s\n' "${out[@]:-linux-headers}"
}

# ---- the commands ----
cmd=${1:-detect}
shift || true
DEDICATED=0 MULTILIB=0 LINK=0 DRY=0
for arg in "$@"; do
    case "$arg" in
        --dedicated) DEDICATED=1 ;;
        --multilib)  MULTILIB=1 ;;
        --link)      LINK=1 ;;
        --dry-run)   DRY=1 ;;
        *) echo "gpu-drivers.sh: unknown option $arg" >&2; exit 2 ;;
    esac
done
run() { echo "+ $*"; (( DRY )) || "$@"; }

case $cmd in
detect)
    if (( ${#FOUND[@]} == 0 )); then
        echo "no GPU found"
        exit 0
    fi
    for f in "${FOUND[@]}"; do
        IFS='|' read -r name kind what <<<"$f"
        echo "$name ($kind): $what"
    done
    (( HYBRID )) && echo "hybrid laptop: the desktop draws on $IGPU_DRIVER, NVIDIA runs what asks for it (prime-run)"
    [[ -n $NV_KIND && $NV_KIND != unsupported && $HYBRID == 0 ]] && echo "NVIDIA drives the desktop (no hybrid setup)"
    exit 0 ;;

packages)
    out=()
    (( INTEL )) && out+=(vulkan-intel intel-media-driver libva-intel-driver)   # iHD for 2014+, i965 before: libva picks
    (( AMD )) && out+=(vulkan-radeon)
    if (( MULTILIB )); then
        (( INTEL || AMD )) && out+=(lib32-mesa)
        (( INTEL )) && out+=(lib32-vulkan-intel)
        (( AMD )) && out+=(lib32-vulkan-radeon)
    fi
    if (( DEDICATED )) && [[ $NV_KIND == open || $NV_KIND == legacy ]]; then
        mapfile -t -O "${#out[@]}" out < <(headers)
        if [[ $NV_KIND == open ]]; then
            out+=(nvidia-open-dkms nvidia-utils nvidia-settings libva-nvidia-driver)
            (( MULTILIB )) && out+=(lib32-nvidia-utils)
        fi
        (( HYBRID )) && out+=(nvidia-prime)
    fi
    printf '%s\n' "${out[@]}" ;;

aur-packages)
    if [[ $NV_KIND == legacy ]]; then
        echo nvidia-580xx-dkms
        echo nvidia-580xx-utils
        (( MULTILIB )) && echo lib32-nvidia-580xx-utils
    fi
    exit 0 ;;

advice)
    if [[ $NV_KIND == unsupported ]]; then
        echo "$NV_NAME (NVIDIA, device $NV_ID) is older than Maxwell: no current NVIDIA driver supports it"
        echo "  on Wayland. Look for a driver for your GPU: https://wiki.archlinux.org/title/NVIDIA"
    fi
    if [[ -n $AMD_OLD ]]; then
        echo "$AMD_OLD uses the old radeon driver: Vulkan needs amdgpu, which GCN 1 and 2 cards can switch"
        echo "  to and older ones can't. Look for your GPU: https://wiki.archlinux.org/title/AMDGPU"
    fi
    exit 0 ;;

setup)
    if [[ $NV_KIND != open && $NV_KIND != legacy ]]; then
        echo "Nothing to set up: Intel and AMD GPUs need nothing beyond their packages."
        exit 0
    fi
    echo "NVIDIA: $NV_NAME$( (( HYBRID )) && echo ", hybrid laptop with $IGPU_DRIVER" )"

    echo "1. Module options -> /etc/modprobe.d/nvidia.conf"
    run sudo install -Dm644 "$SRC/nvidia.conf" /etc/modprobe.d/nvidia.conf

    echo "2. Suspend and hibernate keep the video memory (needed by those options)"
    run sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service

    conf=/etc/mkinitcpio.conf
    wanted="nvidia nvidia_modeset nvidia_uvm nvidia_drm"
    (( HYBRID )) && wanted="$IGPU_DRIVER $wanted"
    echo "3. Modules loaded early: $wanted"
    current=$(sed -n 's/^MODULES=(\(.*\))/\1/p' "$conf" | head -1)
    # Ours first (the integrated GPU drives a laptop's panel), then whatever was there.
    merged=$(printf '%s\n' $wanted $current | awk '!seen[$0]++' | xargs)
    if [[ "$current" == "$merged" ]]; then
        echo "   already: MODULES=($merged)"
    else
        echo "   MODULES=($current) -> MODULES=($merged); a copy of mkinitcpio.conf stays as .bak-<date>"
        run sudo cp "$conf" "$conf.bak-$(date +%Y%m%d-%H%M%S)"
        run sudo sed -i "s/^MODULES=(.*)/MODULES=($merged)/" "$conf"
        run sudo mkinitcpio -P
    fi

    if (( HYBRID )); then
        echo "4. Stable GPU names: /dev/dri/amd-igpu or intel-igpu, and nvidia-dgpu"
        run sudo install -Dm644 "$SRC/99-gpu-symlinks.rules" /etc/udev/rules.d/99-gpu-symlinks.rules
        run sudo udevadm control --reload-rules
        run sudo udevadm trigger --subsystem-match=drm
        echo "5. Hyprland draws on the integrated GPU first -> ~/.config/uwsm/env-hyprland"
        run mkdir -p "$HOME/.config/uwsm"
        if (( LINK )); then
            run ln -sfn "$SRC/env-hyprland" "$HOME/.config/uwsm/env-hyprland"
        else
            run install -m644 "$SRC/env-hyprland" "$HOME/.config/uwsm/env-hyprland"
        fi
    fi
    echo "After rebooting, \`nvidia-smi\` should list the GPU$( (( HYBRID )) && echo ", and \`printenv AQ_DRM_DEVICES\` start with the integrated one" )." ;;

*)
    echo "usage: gpu-drivers.sh detect|packages|aur-packages|setup|advice" >&2
    exit 2 ;;
esac
