#!/bin/bash
set -euo pipefail

result=${TKL_TEST_RESULT:?}
work=/run/tkl-v19-tests/wireguard
mkdir -p "$work"
client_ns=tkl-wireguard-client
client_transport_host=wgtkl-host
client_transport_peer=wgtkl-peer
client_interface=wgtkl0
client_private_file=$work/client.private

cleanup() {
    rm -f -- "$client_private_file"
    if ip netns list | awk '{print $1}' | grep -Fxq "$client_ns"; then
        ip netns delete "$client_ns"
    fi
    if ip link show "$client_transport_host" >/dev/null 2>&1; then
        ip link delete "$client_transport_host"
    fi
}
trap cleanup EXIT

systemctl --quiet is-active lighttpd.service
grep -q '\[40wireguard\] successfully completed' /var/log/inithooks.log
curl -kfsS https://127.0.0.1/ | grep -Fq 'TurnKey WireGuard'
grep -Fxq 'net.ipv4.ip_forward=1' /etc/sysctl.d/40-wireguard.conf
test "$(sysctl -n net.ipv4.ip_forward)" = 1

# Headless installs intentionally leave the profile unconfigured. Exercise the
# documented server setup and client lifecycle directly.
/usr/lib/inithooks/bin/wireguard-server-init.sh 10.44.0.1/24 localhost
systemctl --quiet is-active wg-quick@wg0.service
wg show wg0 >/dev/null
ip -4 address show dev wg0 | grep -Fq 'inet 10.44.0.1/24'
test "$(stat -c '%U:%G:%a' /etc/wireguard/wg0.conf)" = root:root:600
test "$(stat -c '%U:%G:%a' /etc/wireguard/private/server.key)" = root:root:600

# Reinitialization must stop the systemd-owned interface cleanly and bring the
# replacement configuration back under the same active unit.
/usr/lib/inithooks/bin/wireguard-server-init.sh 10.44.0.1/24 localhost
systemctl --quiet is-active wg-quick@wg0.service
wg show wg0 >/dev/null
ip -4 address show dev wg0 | grep -Fq 'inet 10.44.0.1/24'

wireguard-addclient tkl-v19-client 10.44.0.0/24
test -s /etc/wireguard/clients/tkl-v19-client.conf
test "$(stat -c '%U:%G:%a' \
    /etc/wireguard/clients/tkl-v19-client.conf)" = root:root:600
grep -Fq 'Endpoint = localhost:51820' \
    /etc/wireguard/clients/tkl-v19-client.conf
client_key=$(python3 /usr/local/bin/wireguard-client-list.py show tkl-v19-client)
test -n "$client_key"
wg show wg0 peers | grep -Fxq "$client_key"

systemctl restart wg-quick@wg0.service
wg show wg0 peers | grep -Fxq "$client_key"
profile_output=$(/var/www/wireguard/bin/addprofile tkl-v19-client)
profile_path=${profile_output#*https://localhost}
test "$profile_path" != "$profile_output"
profile_conf="/var/www/wireguard/htdocs${profile_path}tkl-v19-client.conf"
profile_dir=${profile_conf%/*}
profile_index=$profile_dir/index.html
test "$(stat -c '%U:%G:%a' "$profile_dir")" = www-data:www-data:750
test "$(stat -c '%U:%G:%a' "$profile_conf")" = www-data:www-data:440
test "$(stat -c '%U:%G:%a' "$profile_index")" = www-data:www-data:440
runuser -u nobody -- test ! -x "$profile_dir"
runuser -u nobody -- test ! -r "$profile_conf"
runuser -u nobody -- test ! -r "$profile_index"
curl -kfsS "https://127.0.0.1${profile_path}" | \
    grep -Fq 'Wireguard Profile'
curl -kfsS \
    "https://127.0.0.1${profile_path}tkl-v19-client.conf" \
    >"$work/downloaded-client.conf"
cmp /etc/wireguard/clients/tkl-v19-client.conf \
    "$work/downloaded-client.conf"

# Exercise the generated profile through an isolated client network namespace.
# Its localhost endpoint is replaced only for the namespace's outer transport;
# the generated private key, assigned address, server key and port are used.
client_address=$(awk -F= '/^Address/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' \
    /etc/wireguard/clients/tkl-v19-client.conf)
client_address=${client_address%%/*}
server_public_key=$(awk -F= '/^PublicKey/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' \
    /etc/wireguard/clients/tkl-v19-client.conf)
server_port=$(awk -F: '/^Endpoint/ {gsub(/[[:space:]]/, "", $NF); print $NF; exit}' \
    /etc/wireguard/clients/tkl-v19-client.conf)
test -n "$client_address"
test -n "$server_public_key"
test -n "$server_port"
(
    umask 077
    awk -F= '/^PrivateKey/ {sub(/^[^=]*=[[:space:]]*/, ""); print; exit}' \
        /etc/wireguard/clients/tkl-v19-client.conf >"$client_private_file"
)
test -s "$client_private_file"
test "$(stat -c '%a' "$client_private_file")" = 600

ip netns add "$client_ns"
ip link add "$client_transport_host" type veth \
    peer name "$client_transport_peer"
ip link set "$client_transport_peer" netns "$client_ns"
ip address add 192.0.2.1/30 dev "$client_transport_host"
ip link set "$client_transport_host" up
ip netns exec "$client_ns" ip link set lo up
ip netns exec "$client_ns" ip address add 192.0.2.2/30 \
    dev "$client_transport_peer"
ip netns exec "$client_ns" ip link set "$client_transport_peer" up
ip netns exec "$client_ns" ip link add "$client_interface" type wireguard
ip netns exec "$client_ns" wg set "$client_interface" \
    private-key "$client_private_file" \
    peer "$server_public_key" \
    endpoint "192.0.2.1:$server_port" \
    allowed-ips 10.44.0.1/32 \
    persistent-keepalive 1
rm -f -- "$client_private_file"
ip netns exec "$client_ns" ip address add "$client_address/32" \
    dev "$client_interface"
ip netns exec "$client_ns" ip link set "$client_interface" up
ip netns exec "$client_ns" ip route add 10.44.0.1/32 \
    dev "$client_interface"

peer_transfer() {
    wg show wg0 transfer | awk -v peer="$client_key" '
        $1 == peer { print $2 + $3; found = 1 }
        END { if (!found) exit 1 }
    '
}

assert_recent_handshake() {
    local handshake now
    handshake=$(wg show wg0 latest-handshakes | \
        awk -v peer="$client_key" '$1 == peer { print $2 }')
    now=$(date +%s)
    test -n "$handshake"
    test "$handshake" -gt 0
    test "$((now - handshake))" -le 30
}

send_tunnel_packet() {
    local attempt
    for attempt in $(seq 1 10); do
        if ip netns exec "$client_ns" ping -c 1 -W 1 10.44.0.1 \
                >"$work/ping.log" 2>&1; then
            return 0
        fi
        sleep 1
    done
    cat "$work/ping.log" >&2
    return 1
}

transfer_before=$(peer_transfer)
send_tunnel_packet
transfer_after=$(peer_transfer)
test "$transfer_after" -gt "$transfer_before"
assert_recent_handshake

systemctl restart wg-quick@wg0.service
wg show wg0 peers | grep -Fxq "$client_key"
transfer_before_restart=$(peer_transfer)
send_tunnel_packet
transfer_after_restart=$(peer_transfer)
test "$transfer_after_restart" -gt "$transfer_before_restart"
assert_recent_handshake

wireguard-removeclient tkl-v19-client
test ! -e /etc/wireguard/clients/tkl-v19-client.conf
! wg show wg0 peers | grep -Fxq "$client_key"
if ip netns exec "$client_ns" ping -c 1 -W 2 10.44.0.1 \
        >"$work/revoked-ping.log" 2>&1; then
    echo 'revoked WireGuard client still passed tunnel traffic' >&2
    exit 1
fi

version=$(wg --version | awk '{print $2}')
candidate=$(apt-cache policy wireguard-tools | awk '/Candidate:/ {print $2}')
test -n "$candidate" && test "$candidate" != '(none)'

cat >"$result" <<EOF
package_source=Debian Trixie wireguard-tools package and Linux kernel WireGuard
installed_version=$version
runtime_checks=web service, IPv4 forwarding configuration and effective state, systemd-owned server initialization and reinitialization, private config permissions, restricted profile and exact config download, isolated client tunnel traffic with recent handshake and transfer counters before and after restart, and traffic denial after client revocation
updater_command=apt-cache policy wireguard-tools
updater_result=APT candidate $candidate found; installed packages unchanged
updater_channel=Debian Trixie signed APT repositories
integrity_evidence=APT candidate metadata accepted from configured signed repositories
EOF
