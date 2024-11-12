#!/usr/bin/python3
"""Initialize Wireguard server keys and configuration

Options:

    --profile=          profile to use (server or client)

Server profile options:

    --virtual-subnet=   IP address of server and range of virtual subnet
                        in CIDR notation
    --domain=           domain (or ip) which will be given to the client
                        to use as the wireguard endpoint.
"""

import os
import sys
import getopt

from libinithooks import inithooks_cache
from libinithooks.dialog_wrapper import Dialog
import subprocess


def fatal(e):
    print('Error:', e, file=sys.stderr)
    sys.exit(1)


def usage(e=None):
    if e:
        print('Error:', e, file=sys.stderr)
    print(f"Syntax: {sys.argv[0]} [options]", file=sys.stderr)
    print(__doc__, file=sys.stderr)
    sys.exit(1)


def main():
    try:
        opts, args = getopt.gnu_getopt(
                sys.argv[1:], "h", ['help', 'virtual-subnet=', 'domain=',
                'profile='])
    except getopt.GetoptError as e:
        usage(e)

    profile = ""
    virtual_subnet = ""
    domain = ""

    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()
        elif opt == '--profile':
            profile = val
        elif opt == '--virtual-subnet':
            virtual_subnet = val
        elif opt == '--domain':
            domain = val

    dialog = Dialog("TurnKey Linux - First boot configuration")

    if not profile:
        profile = dialog.menu(
                "Wireguard Profile",
                "Choose a profile for this server.\n\n"
                "* Server: clients will route traffic through the VPN.",
                [
                    ('server', 'Accept VPN connections from clients*'),
                    ('client', 'Initiate VPN connections to a server')
                ])

    if profile not in ('server', 'client'):
        fatal(f'invalid profile: {profile!r}')

    if profile == 'client':
        return

    if not virtual_subnet:
        virtual_subnet = dialog.get_input(
                "Wireguard Virtual Address",
                "Enter IP address in CIDR of server reachable by clients",
                "10.0.0.0/8")

    if not domain:
        domain = dialog.get_input(
                "Wireguard Public Address",
                "Used in client configuration as wireguard endpoint",
                "www.example.com")

    inithooks_cache.write('APP_DOMAIN', domain)

    cmd = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       'wireguard-server-init.sh')
    proc = subprocess.run([cmd, virtual_subnet, domain],
                          capture_output=True,
                          text=True)
    if proc.returncode != 0:
        fatal(f"command {' '.join(cmd)} failed:"
              f"\n{sys.stderr}")


if __name__ == '__main__':
    main()
