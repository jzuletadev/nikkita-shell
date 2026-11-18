#!/usr/bin/env bash
# ~/nikita-shell/tests/charge-limit.sh
#
# scripts/charge-limit.sh against simulated laptops (POWER_SUPPLY points it at a
# fake /sys/class/power_supply): the three kinds of driver, a laptop without the
# switch, a desktop. Run with tests/run.sh.

set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO/scripts/charge-limit.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
FAILED=0

# machine <name> <end|-> <start|-> <charge_types|->: a battery with those files
machine() {
    local dir="$WORK/$1"
    mkdir -p "$dir/sys/AC" "$dir/sys/BAT0" "$dir/etc" "$dir/lib" "$dir/units"
    echo Mains > "$dir/sys/AC/type"
    echo Battery > "$dir/sys/BAT0/type"
    [ "$2" = - ] || echo "$2" > "$dir/sys/BAT0/charge_control_end_threshold"
    [ "$3" = - ] || echo "$3" > "$dir/sys/BAT0/charge_control_start_threshold"
    [ "$4" = - ] || echo "$4" > "$dir/sys/BAT0/charge_types"
    echo "$dir"
}
run() {   # run <machine dir> <arguments>
    local dir=$1
    shift
    POWER_SUPPLY="$dir/sys" CHARGE_LIMIT_ETC="$dir/etc" CHARGE_LIMIT_LIB="$dir/lib" CHARGE_LIMIT_UNITS="$dir/units" "$SCRIPT" "$@" 2>&1
}
check() {   # check <what> <got> <expected>
    if [ "$2" != "$3" ]; then
        echo "FAIL $1: got \"$2\", expected \"$3\""
        FAILED=1
    fi
}
file() { cat "$1" 2>/dev/null || echo "(missing)"; }

# ---- end threshold only (ASUS): one file to write
m=$(machine asus 100 - -)
check "asus: starts unlimited" "$(run "$m" status)" '{"supported": true, "battery": "BAT0", "limit": 100, "saved": null}'
run "$m" set 80
check "asus: end threshold" "$(file "$m/sys/BAT0/charge_control_end_threshold")" 80
check "asus: saved for the next boot" "$(file "$m/etc/charge-limit")" 80
check "asus: the boot service runs root's copy" "$(grep -c "ExecStart=$m/lib/charge-limit.sh apply" "$m/units/nikita-charge-limit.service")" 1
check "asus: root's copy is there" "$([ -x "$m/lib/charge-limit.sh" ] && echo yes)" yes
check "asus: status after" "$(run "$m" status)" '{"supported": true, "battery": "BAT0", "limit": 80, "saved": 80}'
# The laptop forgot it over a restart: the service puts it back.
echo 100 > "$m/sys/BAT0/charge_control_end_threshold"
run "$m" apply
check "asus: back after a boot" "$(file "$m/sys/BAT0/charge_control_end_threshold")" 80
run "$m" set 100
check "asus: limit removed" "$(file "$m/sys/BAT0/charge_control_end_threshold")" 100
check "asus: nothing left saved" "$(ls "$m/etc" "$m/units" "$m/lib" | tr -d '\n')" "$m/etc:$m/lib:$m/units:"

# ---- start and end (ThinkPad): start goes 5 below
m=$(machine thinkpad 100 0 -)
run "$m" set 60
check "thinkpad: end" "$(file "$m/sys/BAT0/charge_control_end_threshold")" 60
check "thinkpad: start" "$(file "$m/sys/BAT0/charge_control_start_threshold")" 55
run "$m" set 100
check "thinkpad: unlimited end" "$(file "$m/sys/BAT0/charge_control_end_threshold")" 100
check "thinkpad: unlimited start" "$(file "$m/sys/BAT0/charge_control_start_threshold")" 95

# ---- thresholds that only count in "Custom" (Dell)
m=$(machine dell 90 50 "Trickle [Standard] Custom")
check "dell: thresholds idle in Standard" "$(run "$m" status)" '{"supported": true, "battery": "BAT0", "limit": 100, "saved": null}'
run "$m" set 80
# A real driver brackets the mode it took; the plain file just holds what was written.
check "dell: Custom selected" "$(file "$m/sys/BAT0/charge_types")" Custom
check "dell: end" "$(file "$m/sys/BAT0/charge_control_end_threshold")" 80
check "dell: start" "$(file "$m/sys/BAT0/charge_control_start_threshold")" 75
echo "Trickle Standard [Custom]" > "$m/sys/BAT0/charge_types"
check "dell: limit in force" "$(run "$m" status)" '{"supported": true, "battery": "BAT0", "limit": 80, "saved": 80}'
run "$m" set 100
check "dell: back to Standard" "$(file "$m/sys/BAT0/charge_types")" Standard

# ---- the driver refuses a value (it kept the old one): said, not hidden
m=$(machine picky 100 - -)
chmod a-w "$m/sys/BAT0/charge_control_end_threshold"
if [ -w "$m/sys/BAT0/charge_control_end_threshold" ]; then
    : # root ignores permissions: nothing to simulate
else
    out=$(CHARGE_LIMIT_VERIFY=1 run "$m" set 80)
    check "picky: says the battery didn't take it" "$(echo "$out" | grep -c "didn't take 80 %")" 1
    check "picky: nothing saved" "$(file "$m/etc/charge-limit")" "(missing)"
fi

# ---- no switch, and no battery
m=$(machine plain - - -)
check "plain laptop: not supported" "$(run "$m" status)" '{"supported": false, "battery": "", "limit": 100, "saved": null}'
check "plain laptop: set says why" "$(run "$m" set 80)" "This computer's battery has no charge limit the kernel can set."
mkdir -p "$WORK/desktop/sys/AC" && echo Mains > "$WORK/desktop/sys/AC/type"
check "desktop: not supported" "$(POWER_SUPPLY="$WORK/desktop/sys" CHARGE_LIMIT_ETC="$WORK/desktop/etc" "$SCRIPT" status)" '{"supported": false, "battery": "", "limit": 100, "saved": null}'

# ---- bad input
m=$(machine input 100 - -)
check "a limit under 50" "$(run "$m" set 30)" "The limit goes from 50 to 100 %, not 30."
check "not a number" "$(run "$m" set lots | head -1)" "usage: charge-limit.sh set N   (50 to 100; 100 removes the limit)"

if (( FAILED )); then
    exit 1
fi
echo "charge-limit: 6 machines ok"
