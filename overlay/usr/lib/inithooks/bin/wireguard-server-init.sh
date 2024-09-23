#!/bin/bash -eu

fatal() { echo "FATAL [$(basename "$0")]: $*" 1>&2; exit 1; }
info() { echo "INFO [$(basename "$0")]: $*"; }

usage() {
    cat << EOF
Syntax: $0 virtual-subnet
Initialize Wireguard server keys and configuration

Arguments:
    virtual-subnet  CIDR subnet address pool to allocate to clients
    domain          server domain (used in client configuration)
EOF
    exit 1
}

if [[ "$#" != "2" ]]; then
    usage
fi

virtual_subnet="$1"
domain="$2"

WIREGUARD=/etc/wireguard

for interface in $(wg show interfaces); do
    wg-quick down "$interface"
done
rm -rf /etc/wireguard/*

(
    umask 077
    mkdir $WIREGUARD/private
    wg genkey | tee $WIREGUARD/private/server.key | wg pubkey > $WIREGUARD/server.pub
)

cat > $WIREGUARD/wg0.conf <<EOF
[Interface]
Address = $virtual_subnet
PrivateKey = $(cat $WIREGUARD/private/server.key)
ListenPort = 51820
SaveConfig = true
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE;
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE;
EOF
wg-quick up wg0
systemctl enable wg-quick@wg0.service

echo "$domain" > /etc/wireguard/domain.txt

echo 
echo "Generated: /etc/wireguard/wg0.conf"
