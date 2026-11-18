#!/usr/bin/env bash
# ~/nikita-shell/scripts/charge-limit.sh
#
# Stop charging the laptop's battery below full (80 %, say): a battery kept under
# 100 % lasts more years. For any laptop whose driver has the kernel's standard
# switch for it, /sys/class/power_supply/BAT*/charge_control_end_threshold
# (ThinkPad, Dell, ASUS, Huawei, LG, Framework, System76...); elsewhere it says
# "not supported" and Settings → Power doesn't offer it.
#
#   charge-limit.sh status      JSON, no root: {"supported", "battery", "limit",
#                               "saved"}. `limit` is what is in force (100 = none).
#   charge-limit.sh set N       root (Settings runs it with pkexec). N from 50 to
#                               100; 100 removes the limit. Kept across restarts:
#                               N is saved and a small service puts it back at boot,
#                               since some laptops forget it.
#   charge-limit.sh apply       root: what that service runs.
#
# How drivers differ, all handled here:
#   * a start threshold too (ThinkPad, Dell): set 5 below the limit, written in the
#     order that never leaves start above end;
#   * `charge_types` with "Custom" (Dell): the thresholds only count in that mode,
#     so a limit selects it, and removing the limit goes back to "Standard".
#
# POWER_SUPPLY, CHARGE_LIMIT_ETC and CHARGE_LIMIT_LIB point it at a simulated
# machine (tests/charge-limit.sh).

set -uo pipefail

SYS="${POWER_SUPPLY:-/sys/class/power_supply}"
ETC="${CHARGE_LIMIT_ETC:-/etc/nikita-shell}"
LIB="${CHARGE_LIMIT_LIB:-/usr/local/lib/nikita-shell}"
UNIT_DIR="${CHARGE_LIMIT_UNITS:-/etc/systemd/system}"
UNIT=nikita-charge-limit.service
SIMULATED=${POWER_SUPPLY:+1}

# The first battery that has the switch.
battery() {
    local dir
    for dir in "$SYS"/*/; do
        [ "$(cat "$dir/type" 2>/dev/null)" = Battery ] || continue
        [ -e "$dir/charge_control_end_threshold" ] || continue
        echo "${dir%/}"
        return 0
    done
    return 1
}

# "Trickle [Standard] Custom" -> Standard
mode_now() { sed -n 's/.*\[\(.*\)\].*/\1/p' "$1/charge_types" 2>/dev/null; }
has_mode() { tr -d '[]' < "$1/charge_types" 2>/dev/null | tr ' ' '\n' | grep -qx "$2"; }

# What is in force: the end threshold, unless a mode other than Custom overrides it.
limit_now() {
    local bat=$1 end
    end=$(cat "$bat/charge_control_end_threshold" 2>/dev/null) || end=100
    if [ -e "$bat/charge_types" ] && has_mode "$bat" Custom && [ "$(mode_now "$bat")" != Custom ]; then
        end=100
    fi
    echo "${end:-100}"
}

write() {   # write <file> <value>: false if the driver refuses
    echo "$2" > "$1" 2>/dev/null
}

apply() {   # apply <battery> <limit>
    local bat=$1 limit=$2 start
    if [ -e "$bat/charge_control_start_threshold" ]; then
        start=$(( limit >= 100 ? 95 : limit - 5 ))
        # Raising: the end first, so start never passes it. Lowering: start first.
        if [ "$limit" -ge "$(cat "$bat/charge_control_end_threshold" 2>/dev/null || echo 100)" ]; then
            write "$bat/charge_control_end_threshold" "$limit"
            write "$bat/charge_control_start_threshold" "$start"
        else
            write "$bat/charge_control_start_threshold" "$start"
            write "$bat/charge_control_end_threshold" "$limit"
        fi
    else
        write "$bat/charge_control_end_threshold" "$limit"
    fi
    if [ -e "$bat/charge_types" ] && has_mode "$bat" Custom; then
        if [ "$limit" -lt 100 ]; then
            write "$bat/charge_types" Custom
        elif [ "$(mode_now "$bat")" = Custom ]; then
            if has_mode "$bat" Standard; then write "$bat/charge_types" Standard
            elif has_mode "$bat" Adaptive; then write "$bat/charge_types" Adaptive
            fi
        fi
    fi
    # A plain file takes anything; the real one may have refused. Say what stuck.
    if [ -z "$SIMULATED" ] || [ -n "${CHARGE_LIMIT_VERIFY:-}" ]; then
        [ "$(limit_now "$bat")" = "$limit" ] ||
            { echo "The battery didn't take $limit %: it reads $(limit_now "$bat") % (its firmware may only allow some values)." >&2; return 1; }
    fi
}

need_root() {
    [ -n "$SIMULATED" ] || [ "$(id -u)" = 0 ] || { echo "charge-limit.sh $1 needs root: sudo $0 $*" >&2; exit 1; }
}

case "${1:-status}" in
status)
    saved=null
    [ -r "$ETC/charge-limit" ] && saved=$(tr -cd '0-9' < "$ETC/charge-limit")
    if bat=$(battery); then
        printf '{"supported": true, "battery": "%s", "limit": %s, "saved": %s}\n' "$(basename "$bat")" "$(limit_now "$bat")" "${saved:-null}"
    else
        printf '{"supported": false, "battery": "", "limit": 100, "saved": %s}\n' "${saved:-null}"
    fi
    ;;
set)
    need_root "$@"
    limit=${2:-}
    case "$limit" in
        ''|*[!0-9]*) echo "usage: charge-limit.sh set N   (50 to 100; 100 removes the limit)" >&2; exit 2 ;;
    esac
    { [ "$limit" -ge 50 ] && [ "$limit" -le 100 ]; } || { echo "The limit goes from 50 to 100 %, not $limit." >&2; exit 2; }
    bat=$(battery) || { echo "This computer's battery has no charge limit the kernel can set." >&2; exit 1; }
    apply "$bat" "$limit" || exit 1
    if [ "$limit" -lt 100 ]; then
        mkdir -p "$ETC" "$LIB" "$UNIT_DIR"
        echo "$limit" > "$ETC/charge-limit"
        # The service runs a copy root owns, not a file in someone's home.
        install -m755 "$0" "$LIB/charge-limit.sh"
        cat > "$UNIT_DIR/$UNIT" <<EOF
[Unit]
Description=Battery charge limit (nikita-shell): put it back at boot
After=sysinit.target

[Service]
Type=oneshot
ExecStart=$LIB/charge-limit.sh apply

[Install]
WantedBy=multi-user.target
EOF
        [ -n "$SIMULATED" ] || { systemctl daemon-reload && systemctl enable --quiet "$UNIT"; }
    else
        [ -n "$SIMULATED" ] || systemctl disable --quiet "$UNIT" 2>/dev/null
        rm -f "$ETC/charge-limit" "$UNIT_DIR/$UNIT" "$LIB/charge-limit.sh"
        [ -n "$SIMULATED" ] || systemctl daemon-reload
    fi
    ;;
apply)
    need_root "$@"
    [ -r "$ETC/charge-limit" ] || exit 0
    limit=$(tr -cd '0-9' < "$ETC/charge-limit")
    bat=$(battery) || exit 0
    [ -n "$limit" ] && apply "$bat" "$limit"
    ;;
*)
    echo "usage: charge-limit.sh status | set N | apply" >&2
    exit 2
    ;;
esac
