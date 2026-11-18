#!/usr/bin/env bash
# ~/nikita-shell/scripts/firewall.sh
#
# A firewall for a computer that moves between networks: other computers can't
# start connections to this one, except for what you allow. What this computer
# starts itself (browsing, updates, ssh to elsewhere) is not touched.
#
#   firewall.sh status          JSON, no root: installed, active, what is allowed
#   firewall.sh rules           print the nftables rules it would load, no root
#   firewall.sh install         root: write the rules and the service, start it now
#                               and at every boot. SSH is allowed in if sshd is
#                               enabled, so installing never locks you out.
#   firewall.sh on | off        root: start and enable it / stop and disable it
#   firewall.sh allow WHAT      root: let WHAT in. A name (ssh, kdeconnect,
#   firewall.sh deny WHAT       syncthing) or a port: 8080/tcp, 5000-5010/udp
#   firewall.sh uninstall       root: remove all of it
#
# How it is made:
#   * nftables, in a table of its own (inet nikita_firewall), loaded by its own
#     service (nikita-firewall.service). Stopping it deletes that table and nothing
#     else: Docker's rules, or a ruleset of yours, stay as they are.
#   * Only the `input` hook: this computer isn't a router. Containers and virtual
#     machines on it are trusted (docker0, br-*, virbr*, podman*).
#   * Always let in: answers to what this computer asked for, ping, what IPv6 and
#     DHCP need, names on the local network (mDNS) and answers to device discovery
#     (Chromecast, DLNA).
#   * SSH, when allowed, takes 20 new connections a minute from one address: enough
#     for you, slow for someone guessing passwords. Keys only is still the fix.
#   * Docker publishes container ports around any input rule (it forwards them): a
#     published port is reachable whatever this says.
#   * ufw or firewalld already running? Then this stays out: one firewall at a time.
#
# FIREWALL_ETC, FIREWALL_UNITS and FIREWALL_SSHD point it at a scratch folder
# (tests/firewall.sh loads the rules into a network of its own).

set -uo pipefail

ETC="${FIREWALL_ETC:-/etc/nikita-shell}"
UNIT_DIR="${FIREWALL_UNITS:-/etc/systemd/system}"
SSHD_CONFIG="${FIREWALL_SSHD:-/etc/ssh}"
UNIT=nikita-firewall.service
RULES="$ETC/firewall.nft"
ALLOW="$ETC/firewall.allow"
SIMULATED=${FIREWALL_ETC:+1}

need_root() {
    [ -n "$SIMULATED" ] || [ "$(id -u)" = 0 ] || { echo "firewall.sh $1 needs root: sudo $0 $*" >&2; exit 1; }
}

# The ports sshd listens on: its config's Port lines, 22 without any.
ssh_ports() {
    local ports
    ports=$(cat "$SSHD_CONFIG"/sshd_config "$SSHD_CONFIG"/sshd_config.d/*.conf 2>/dev/null |
        awk 'tolower($1) == "port" && $2 ~ /^[0-9]+$/ { print $2 }' | sort -un | paste -sd, -)
    echo "${ports:-22}"
}

sshd_enabled() {
    systemctl is-enabled --quiet sshd.service 2>/dev/null || systemctl is-enabled --quiet sshd.socket 2>/dev/null ||
        systemctl is-active --quiet sshd.service 2>/dev/null
}

# Another firewall that is running: its name, or nothing.
other_firewall() {
    local name
    for name in ufw firewalld; do
        if systemctl is-active --quiet "$name.service" 2>/dev/null; then
            echo "$name"
            return
        fi
    done
}

allowed() {   # the names and ports let in, one a line
    [ -r "$ALLOW" ] && grep -v '^\s*#' "$ALLOW" | grep -v '^\s*$' || true
}

# WHAT as nftables rules, or false if it isn't a name or a port this knows.
rules_for() {
    local what=$1 ports
    case "$what" in
        ssh)
            ports=$(ssh_ports)
            cat <<EOF
        tcp dport { $ports } ct state new add @ssh_tries4 { ip saddr limit rate over 20/minute burst 20 packets } drop comment "ssh: slow for someone guessing passwords"
        tcp dport { $ports } ct state new add @ssh_tries6 { ip6 saddr limit rate over 20/minute burst 20 packets } drop
        tcp dport { $ports } accept comment "ssh"
EOF
            ;;
        kdeconnect)
            echo '        tcp dport 1714-1764 accept comment "kdeconnect"'
            echo '        udp dport 1714-1764 accept comment "kdeconnect"'
            ;;
        syncthing)
            echo '        tcp dport 22000 accept comment "syncthing"'
            echo '        udp dport { 22000, 21027 } accept comment "syncthing"'
            ;;
        *)
            # 8080/tcp, 5000-5010/udp
            if [[ $what =~ ^([0-9]{1,5})(-([0-9]{1,5}))?/(tcp|udp)$ ]] && (( BASH_REMATCH[1] >= 1 && BASH_REMATCH[1] <= 65535 )) &&
                { [ -z "${BASH_REMATCH[3]}" ] || (( BASH_REMATCH[3] > BASH_REMATCH[1] && BASH_REMATCH[3] <= 65535 )); }; then
                echo "        ${BASH_REMATCH[4]} dport ${what%/*} accept comment \"$what\""
            else
                return 1
            fi
            ;;
    esac
}

rules() {
    local what
    cat <<'EOF'
#!/usr/bin/nft -f
# Written by scripts/firewall.sh (nikita-shell). Change what is allowed
# with `firewall.sh allow|deny`, not here: this file is rewritten.

destroy table inet nikita_firewall

table inet nikita_firewall {
    # Who tried to open an SSH connection in the last minute, and how often.
    set ssh_tries4 { type ipv4_addr; flags dynamic, timeout; timeout 1m; size 65536; }
    set ssh_tries6 { type ipv6_addr; flags dynamic, timeout; timeout 1m; size 65536; }

    chain input {
        type filter hook input priority filter; policy drop;

        ct state invalid drop comment "broken packets"
        ct state { established, related } accept comment "answers to what this computer asked for"
        iif lo accept comment "this computer talking to itself"
        iifname { "docker0", "br-*", "virbr*", "podman*" } accept comment "containers and virtual machines on this computer"

        meta l4proto icmp accept comment "ping and network errors"
        meta l4proto ipv6-icmp accept comment "IPv6 doesn't work without these"
        ip protocol igmp accept comment "multicast groups"
        udp sport 67 udp dport 68 accept comment "DHCP"
        ip6 saddr fe80::/10 udp sport 547 udp dport 546 accept comment "DHCPv6"
        ip daddr 224.0.0.251 udp dport 5353 accept comment "names on the local network (mDNS)"
        ip6 daddr ff02::fb udp dport 5353 accept comment "names on the local network (mDNS)"
        udp sport 1900 udp dport >= 1024 meta pkttype unicast limit rate 4/second burst 20 packets accept comment "answers to device discovery (Chromecast, DLNA)"

        # ---- let in with `firewall.sh allow`
EOF
    while read -r what; do
        rules_for "$what" || echo "        # \"$what\" isn't a name or a port: skipped"
    done < <(allowed)
    cat <<'EOF'

        # Everything else: said no to a few times a second, then just dropped.
        meta pkttype host limit rate 5/second counter reject with icmpx type admin-prohibited
        counter
    }
}
EOF
}

write_rules() {
    mkdir -p "$ETC"
    rules > "$RULES.new" && mv "$RULES.new" "$RULES"
}

write_unit() {
    mkdir -p "$UNIT_DIR"
    cat > "$UNIT_DIR/$UNIT" <<EOF
[Unit]
Description=Firewall (nikita-shell): incoming connections blocked, except what is allowed
Documentation=file://$RULES
DefaultDependencies=no
Wants=network-pre.target
Before=network-pre.target shutdown.target
Conflicts=shutdown.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/nft -f $RULES
ExecReload=/usr/bin/nft -f $RULES
ExecStop=/usr/bin/nft destroy table inet nikita_firewall

[Install]
WantedBy=multi-user.target
EOF
}

reload_if_on() {
    [ -n "$SIMULATED" ] && return 0
    if systemctl is-active --quiet "$UNIT"; then
        nft -f "$RULES" || { echo "nftables refused the new rules: the old ones are still loaded." >&2; return 1; }
    fi
}

json_list() {   # lines -> ["a", "b"]
    local out="" line
    while read -r line; do
        [ -n "$line" ] && out+="${out:+, }\"$line\""
    done
    echo "[$out]"
}

case "${1:-status}" in
status)
    installed=false; active=false; enabled=false; sshd=false
    [ -f "$UNIT_DIR/$UNIT" ] && [ -f "$RULES" ] && installed=true
    systemctl is-active --quiet "$UNIT" 2>/dev/null && active=true
    systemctl is-enabled --quiet "$UNIT" 2>/dev/null && enabled=true
    sshd_enabled && sshd=true
    printf '{"installed": %s, "active": %s, "enabled": %s, "other": "%s", "allowed": %s, "sshd": %s, "sshPorts": "%s"}\n' \
        "$installed" "$active" "$enabled" "$(other_firewall)" "$(allowed | json_list)" "$sshd" "$(ssh_ports)"
    ;;
rules)
    rules
    ;;
install)
    need_root "$@"
    command -v nft >/dev/null || { echo "nftables isn't installed: sudo pacman -S nftables" >&2; exit 1; }
    other=$(other_firewall)
    if [ -n "$other" ]; then
        echo "$other is already this computer's firewall: nothing installed. One at a time." >&2
        exit 1
    fi
    mkdir -p "$ETC"
    if [ ! -f "$ALLOW" ]; then
        {
            echo "# What may connect to this computer, one a line: a name firewall.sh knows"
            echo "# (ssh, kdeconnect, syncthing) or a port (8080/tcp). Change it with"
            echo "# \`firewall.sh allow|deny\`."
            sshd_enabled && echo ssh
        } > "$ALLOW"
    fi
    write_rules
    write_unit
    if [ -z "$SIMULATED" ]; then
        nft -c -f "$RULES" || { echo "nftables doesn't accept the rules: nothing started." >&2; exit 1; }
        systemctl daemon-reload
        systemctl enable --now "$UNIT" || exit 1
        echo "The firewall is on, now and at every boot."
        if allowed | grep -qx ssh; then
            echo "SSH is allowed in (sshd is enabled here), on port $(ssh_ports)."
        else
            echo "Nothing is allowed in. To open something: sudo $0 allow ssh"
        fi
    fi
    ;;
on)
    need_root "$@"
    [ -f "$UNIT_DIR/$UNIT" ] || { echo "The firewall isn't installed: sudo $0 install" >&2; exit 1; }
    write_rules
    [ -n "$SIMULATED" ] || systemctl enable --now "$UNIT"
    ;;
off)
    need_root "$@"
    [ -n "$SIMULATED" ] || systemctl disable --now "$UNIT"
    ;;
allow|deny)
    need_root "$@"
    what=${2:-}
    rules_for "$what" >/dev/null || { echo "\"$what\" isn't something this knows: a name (ssh, kdeconnect, syncthing) or a port like 8080/tcp." >&2; exit 2; }
    mkdir -p "$ETC"
    touch "$ALLOW"
    grep -vxF "$what" "$ALLOW" > "$ALLOW.new" || true
    [ "$1" = allow ] && echo "$what" >> "$ALLOW.new"
    mv "$ALLOW.new" "$ALLOW"
    write_rules
    reload_if_on
    ;;
uninstall)
    need_root "$@"
    if [ -z "$SIMULATED" ]; then
        systemctl disable --now "$UNIT" 2>/dev/null
    fi
    rm -f "$UNIT_DIR/$UNIT" "$RULES" "$ALLOW"
    [ -n "$SIMULATED" ] || systemctl daemon-reload
    ;;
*)
    echo "usage: firewall.sh status | rules | install | on | off | allow WHAT | deny WHAT | uninstall" >&2
    exit 2
    ;;
esac
