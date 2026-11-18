#!/usr/bin/env bash
# ~/nikita-shell/tests/gpu-drivers.sh
#
# scripts/gpu-drivers.sh against simulated machines (GPU_SYSFS points it at a fake
# /sys): what it finds, what each one gets, and what it warns about. Run with
# tests/run.sh.

set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO/scripts/gpu-drivers.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
FAILED=0

# machine <name> <chassis> <battery 0|1> <slot,vendor,device,driver>...
machine() {
    local sys="$WORK/$1" chassis=$2 battery=$3 dev slot vendor device driver
    shift 3
    mkdir -p "$sys/class/dmi/id" "$sys/bus/pci/devices"
    echo "$chassis" > "$sys/class/dmi/id/chassis_type"
    (( battery )) && mkdir -p "$sys/class/power_supply/BAT0"
    for dev in "$@"; do
        IFS=, read -r slot vendor device driver <<<"$dev"
        mkdir -p "$sys/bus/pci/devices/$slot" "$sys/bus/pci/drivers/$driver"
        echo 0x030000 > "$sys/bus/pci/devices/$slot/class"
        echo "$vendor" > "$sys/bus/pci/devices/$slot/vendor"
        echo "$device" > "$sys/bus/pci/devices/$slot/device"
        ln -s "$sys/bus/pci/drivers/$driver" "$sys/bus/pci/devices/$slot/driver"
    done
    echo "$sys"
}

# expect <machine> <has|lacks> <text> -- <gpu-drivers.sh arguments>
expect() {
    local sys=$1 mode=$2 text=$3 out
    shift 4
    out=$(GPU_SYSFS="$sys" "$SCRIPT" "$@" 2>&1)
    if [[ $mode == has && $out != *"$text"* ]] || [[ $mode == lacks && $out == *"$text"* ]]; then
        echo "FAIL $(basename "$sys"): \`gpu-drivers.sh $*\` should $( [[ $mode == has ]] && echo "include" || echo "not include" ) \"$text\""
        printf '     %s\n' "${out//$'\n'/$'\n'     }"
        FAILED=1
    fi
}

intel=$(machine intel-laptop 10 1 0000:00:02.0,0x8086,0x5917,i915)
expect "$intel" has "(Intel)" -- detect
expect "$intel" has vulkan-intel -- packages
expect "$intel" lacks nvidia -- packages --dedicated
expect "$intel" has "Nothing to set up" -- setup --dry-run

hybrid=$(machine g15-hybrid 10 1 0000:00:02.0,0x8086,0x9a49,i915 0000:01:00.0,0x10de,0x2560,nvidia)
expect "$hybrid" has "Turing or newer" -- detect
expect "$hybrid" has "hybrid laptop: the desktop draws on i915" -- detect
expect "$hybrid" has nvidia-open-dkms -- packages --dedicated
expect "$hybrid" has nvidia-prime -- packages --dedicated
expect "$hybrid" lacks nvidia-open -- packages
expect "$hybrid" has "MODULES" -- setup --dry-run

desktop=$(machine rtx-desktop 3 0 0000:01:00.0,0x10de,0x2786,nvidia)
expect "$desktop" has "NVIDIA drives the desktop" -- detect
expect "$desktop" lacks nvidia-prime -- packages --dedicated
expect "$desktop" has lib32-nvidia-utils -- packages --dedicated --multilib

pascal=$(machine gtx1060-desktop 3 0 0000:01:00.0,0x10de,0x1c03,nvidia)
expect "$pascal" has "Maxwell to Volta" -- detect
expect "$pascal" has nvidia-580xx-dkms -- aur-packages
expect "$pascal" lacks nvidia-open -- packages --dedicated

kepler=$(machine kepler-laptop 10 1 0000:00:02.0,0x8086,0x0416,i915 0000:01:00.0,0x10de,0x1180,nouveau)
expect "$kepler" has "Kepler or older" -- detect
expect "$kepler" lacks hybrid -- detect
expect "$kepler" has "older than Maxwell" -- advice
expect "$kepler" lacks nvidia -- aur-packages

radeon=$(machine old-radeon 3 0 0000:01:00.0,0x1002,0x6798,radeon)
expect "$radeon" has "old (radeon driver)" -- detect
expect "$radeon" has "uses the old radeon driver" -- advice
expect "$radeon" lacks vulkan-radeon -- packages

(( FAILED )) && exit 1
echo "gpu-drivers: 6 machines ok"
