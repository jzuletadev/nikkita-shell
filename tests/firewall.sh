#!/usr/bin/env bash
# ~/nikita-shell/tests/firewall.sh
#
# scripts/firewall.sh for real, without touching this computer's network: the
# rules it writes are loaded into a network of their own (namespaces, no root
# needed) with two ends: "here", the computer with the firewall, and "there",
# another computer on the same network. Then it tries what an outsider would:
# reach an allowed port, reach a closed one, ping, hammer SSH. Run with
# tests/run.sh, or alone after `firewall.sh install` to see it holds.
#
# It needs the kernel's nftables modules (nft_ct, nft_limit, nft_reject). They
# load by themselves, except right after a kernel update, until the restart: the
# old kernel's modules are gone from disk. Then this says so and checks what it
# can (the rules' syntax, and everything in them that needs no module).

set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO/scripts/firewall.sh"

if [ -z "${NIKITA_FW_INSIDE:-}" ]; then
    for tool in nft ip unshare nsenter python3 ping; do
        command -v "$tool" >/dev/null || { echo "skipped: $tool isn't installed"; exit 0; }
    done
    WORK=$(mktemp -d)
    mkdir -p "$WORK/etc" "$WORK/units" "$WORK/ssh"
    export WORK NIKITA_FW_INSIDE=1 FIREWALL_ETC="$WORK/etc" FIREWALL_UNITS="$WORK/units" FIREWALL_SSHD="$WORK/ssh"
    if [ "$(id -u)" = 0 ]; then
        unshare -n "$0"
    else
        unshare -Urn true 2>/dev/null || { echo "skipped: this kernel doesn't let users make namespaces"; rm -rf "$WORK"; exit 0; }
        unshare -Urn "$0"
    fi
    rc=$?
    rm -rf "$WORK"
    exit $rc
fi

# ---------------------------------------------------------------- inside
FAILED=0
CHECKS=0
PIDS=()
trap 'kill "${PIDS[@]}" 2>/dev/null' EXIT

serve() {   # serve <port>: accept TCP connections on it, IPv4 and IPv6, and say hello
    python3 -I -c '
import socket, sys
s = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
s.bind(("::", int(sys.argv[1]))); s.listen(64)
while True:
    c, _ = s.accept(); c.sendall(b"hello\n"); c.close()
' "$1" &
    PIDS+=("$!")
}
reaches() {   # reaches <host> <port>: true if a connection gets its hello
    python3 -I -c '
import socket, sys
try:
    s = socket.create_connection((sys.argv[1], int(sys.argv[2])), timeout=1.5)
    sys.exit(0 if s.recv(16) else 1)
except OSError:
    sys.exit(1)
' "$1" "$2"
}
check() {   # check <what> <yes|no> <command...>: the command must succeed (yes) or fail (no)
    local what=$1 want=$2 got=no
    shift 2
    "$@" >/dev/null 2>&1 && got=yes
    CHECKS=$((CHECKS + 1))
    if [ "$got" != "$want" ]; then
        echo "FAIL $what: expected $want, got $got"
        FAILED=1
    fi
}

# Why the kernel can't load a module now, in words.
why_no_modules() {
    local running
    running=$(uname -r)
    if [ ! -d "/lib/modules/$running" ]; then
        echo "the kernel was updated and this computer hasn't restarted since (it runs $running, whose modules are gone from disk)"
    else
        echo "the kernel modules this needs ($1) aren't loaded, and a user can't load them: run this once as root, or after \`firewall.sh install\`"
    fi
}

# ---- the rules as `firewall.sh install` writes them, with SSH allowed
echo ssh > "$FIREWALL_ETC/firewall.allow"
"$SCRIPT" install || { echo "FAIL firewall.sh install (simulated)"; exit 1; }
check "the service file runs nft on the rules" yes grep -q "ExecStart=/usr/bin/nft -f $FIREWALL_ETC/firewall.nft" "$FIREWALL_UNITS/nikita-firewall.service"
check "stopping it deletes only its own table" yes grep -q "ExecStop=/usr/bin/nft destroy table inet nikita_firewall" "$FIREWALL_UNITS/nikita-firewall.service"
check "a name it doesn't know is refused" no "$SCRIPT" allow everything
check "a port out of range is refused" no "$SCRIPT" allow 70000/tcp
"$SCRIPT" allow 5000-5010/udp
check "a port range is written as one rule" yes grep -q 'udp dport 5000-5010 accept comment "5000-5010/udp"' "$FIREWALL_ETC/firewall.nft"
"$SCRIPT" deny 5000-5010/udp
check "deny takes it out again" no grep -q '5000-5010' "$FIREWALL_ETC/firewall.nft"

# Do they load? Checked in this private network, before building the rest of it.
LOADS=yes
if ! err=$(nft -f "$FIREWALL_ETC/firewall.nft" 2>&1); then
    LOADS=no
    if echo "$err" | grep -q "syntax error\|unexpected"; then
        echo "FAIL the rules have a syntax error:"
        echo "$err" | head -6
        exit 1
    fi
    if ! echo "$err" | grep -q "No such file or directory"; then
        echo "FAIL nft refused the rules:"
        echo "$err" | head -6
        exit 1
    fi
    # Everything in the rules that needs no extra kernel module must still load.
    grep -v 'ct state\|limit rate\|reject with\|add @' "$FIREWALL_ETC/firewall.nft" > "$WORK/plain.nft"
    if ! nft -f "$WORK/plain.nft" 2>"$WORK/plain.err"; then
        echo "FAIL even without the parts that need a kernel module, the rules don't load:"
        head -6 "$WORK/plain.err"
        exit 1
    fi
    CHECKS=$((CHECKS + 1))
    nft destroy table inet nikita_firewall
fi
if [ "$LOADS" = no ]; then
    echo "firewall: $CHECKS checks ok, the rest skipped: $(why_no_modules "nft_ct, nft_limit, nft_reject"). The rules' syntax is right, and what needs no module loads."
    exit $FAILED
fi
nft destroy table inet nikita_firewall

# ---- a network of two: here (with the firewall) and there
ip link set lo up
unshare -n sleep 600 &
peer=$!
PIDS+=("$peer")
sleep 0.3
there() { nsenter -t "$peer" -n "$@"; }
if ! ip link add here type veth peer name there netns "$peer" 2>/dev/null; then
    echo "firewall: $CHECKS checks ok, the rest skipped: $(why_no_modules veth). The rules load."
    exit $FAILED
fi
ip addr add 10.99.0.1/24 dev here
ip -6 addr add fd99::1/64 dev here nodad
ip link set here up
there ip addr add 10.99.0.2/24 dev there
there ip -6 addr add fd99::2/64 dev there nodad
there ip link set there up
there ip link set lo up

serve 22
serve 8080
# Started with nsenter itself, not the `there` function: a function in the
# background is a subshell, and $! would be its PID, not the server's.
{ nsenter -t "$peer" -n python3 -I -c '
import socket
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("0.0.0.0", 7000)); s.listen(8)
while True:
    c, _ = s.accept(); c.sendall(b"hello\n"); c.close()
' & PIDS+=("$!"); }
sleep 0.5

# The test network itself works, before any rule.
check "no firewall yet: there reaches here's 8080" yes there python3 -I -c 'import socket; socket.create_connection(("10.99.0.1", 8080), timeout=1.5)'

nft -f "$FIREWALL_ETC/firewall.nft" || { echo "FAIL the rules stopped loading"; exit 1; }

# ---- what an outsider can and can't do
check "SSH is let in" yes there python3 -I -c 'import socket; s = socket.create_connection(("10.99.0.1", 22), timeout=1.5); assert s.recv(16)'
check "another port is closed" no there python3 -I -c 'import socket; socket.create_connection(("10.99.0.1", 8080), timeout=1.5)'
check "the same over IPv6: SSH in" yes there python3 -I -c 'import socket; s = socket.create_connection(("fd99::1", 22), timeout=1.5); assert s.recv(16)'
check "the same over IPv6: another port closed" no there python3 -I -c 'import socket; socket.create_connection(("fd99::1", 8080), timeout=1.5)'
check "ping answers" yes there ping -c1 -W1 10.99.0.1
check "ping answers over IPv6" yes there ping -c1 -W1 fd99::1
check "this computer still reaches others" yes reaches 10.99.0.2 7000

# ---- opening and closing a port
"$SCRIPT" allow 8080/tcp && nft -f "$FIREWALL_ETC/firewall.nft"
check "allow 8080/tcp opens it" yes there python3 -I -c 'import socket; socket.create_connection(("10.99.0.1", 8080), timeout=1.5)'
"$SCRIPT" deny 8080/tcp && nft -f "$FIREWALL_ETC/firewall.nft"
check "deny 8080/tcp closes it" no there python3 -I -c 'import socket; socket.create_connection(("10.99.0.1", 8080), timeout=1.5)'

# ---- SSH: 20 new connections a minute from one address, then it stops answering
opened=$(there python3 -I -c '
import socket
n = 0
for i in range(40):
    try:
        socket.create_connection(("10.99.0.1", 22), timeout=0.4).close(); n += 1
    except OSError:
        pass
print(n)')
CHECKS=$((CHECKS + 1))
# The burst is 20 (one was used above). The tries take a few seconds, and at 20 a
# minute the limit gets a token back every 3 s: a couple more get in (measured: 22).
if [ "$opened" -lt 15 ] || [ "$opened" -gt 24 ]; then
    echo "FAIL SSH guessing: 40 quick tries opened $opened connections, expected about 20"
    FAILED=1
fi

# ---- off: its table goes, nothing else
nft destroy table inet nikita_firewall
check "off: the port is reachable again" yes there python3 -I -c 'import socket; socket.create_connection(("10.99.0.1", 8080), timeout=1.5)'

(( FAILED )) && exit 1
echo "firewall: $CHECKS checks ok"
