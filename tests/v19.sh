#!/bin/bash
set -euo pipefail

result=${TKL_TEST_RESULT:?}
work=/run/tkl-v19-tests/wireguard
mkdir -p "$work"

systemctl --quiet is-active lighttpd.service
grep -q '\[40wireguard\] successfully completed' /var/log/inithooks.log
curl -kfsS https://127.0.0.1/ | grep -Fq 'TurnKey WireGuard'

# Headless installs intentionally leave the profile unconfigured. Exercise the
# documented server setup and client lifecycle directly.
/usr/lib/inithooks/bin/wireguard-server-init.sh 10.44.0.1/24 localhost
wg show wg0 >/dev/null
wireguard-addclient tkl-v19-client 10.44.0.0/24
test -s /etc/wireguard/clients/tkl-v19-client.conf
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
curl -kfsS "https://127.0.0.1${profile_path}" | \
    grep -Fq 'Wireguard Profile'

wireguard-removeclient tkl-v19-client
test ! -e /etc/wireguard/clients/tkl-v19-client.conf
! wg show wg0 peers | grep -Fxq "$client_key"

version=$(wg --version | awk '{print $2}')
candidate=$(apt-cache policy wireguard-tools | awk '/Candidate:/ {print $2}')
test -n "$candidate" && test "$candidate" != '(none)'

cat >"$result" <<EOF
package_source=Debian Trixie wireguard-tools package and Linux kernel WireGuard
installed_version=$version
runtime_checks=web service, server initialization, interface, client create/config/profile download, restart persistence, and client removal
updater_command=apt-cache policy wireguard-tools
updater_result=APT candidate $candidate found; installed packages unchanged
updater_channel=Debian Trixie signed APT repositories
integrity_evidence=APT candidate metadata accepted from configured signed repositories
EOF
