from os.path import isfile
from argparse import ArgumentParser
import subprocess
import json
import sys

CLIENT_LIST = '/etc/wireguard/clients.json'

def fatal(msg):
    print(msg, file=sys.stderr)
    sys.exit(1)

def gen_name(names):
    i = 1
    while True:
        name = f'unnamed{i}'
        if not name in names:
            return name
        i += 1

def list_wg_peers():
    pubkeys = []
    for line in subprocess.run(['wg', 'show', 'wg0', 'peers'],
            text=True, capture_output=True).stdout.splitlines():
        if line:
            pubkeys.append(line.strip())
    return pubkeys

def read_conf():
    if isfile(CLIENT_LIST):
        with open(CLIENT_LIST, 'r') as fob:
            return json.load(fob)
    else:
        return {}

def write_conf(clients):
    with open(CLIENT_LIST, 'w') as fob:
        json.dump(clients, fob)

def sync():
    conf = read_conf()
    pubkeys = list_wg_peers()

    removed = []
    for name, pubkey in conf.items():
        if not pubkey in pubkeys:
            removed.append(name)

    for name in removed:
        del conf[name]

    new = []
    for pubkey in pubkeys:
        if not pubkey in conf.values():
            new.append(pubkey)

    for pubkey in new:
        names = list(conf.keys())
        conf[gen_name(names)] = pubkey

    print(f'Removed {len(removed)} named clients')
    print(f'Added {len(new)} clients with default names')

    write_conf(conf)

def add(name, pubkey):
    conf = read_conf()
    if name in conf.keys():
        fatal(f'{name!r} already exists')
    elif pubkey in conf.values():
        fatal(f'{pubkey!r} key already in use!')
    conf[name] = pubkey
    write_conf(conf)

def show(name):
    conf = read_conf()
    if name in conf:
        print(conf[name])
    else:
        fatal(f'No such client {name!r}')

def list_clients():
    conf = read_conf()
    for name, key in conf.items():
        print(f'{name}: {key}')

if __name__ == '__main__':
    parser = ArgumentParser()
    subparsers = parser.add_subparsers(dest='cmd')

    sync_parser = subparsers.add_parser('sync')
    list_parser = subparsers.add_parser('list')

    add_parser = subparsers.add_parser('add')
    add_parser.add_argument('name')
    add_parser.add_argument('pubkey')

    show_parser = subparsers.add_parser('show')
    show_parser.add_argument('name')

    args = parser.parse_args()
    if args.cmd == 'sync':
        sync()
    elif args.cmd == 'add':
        add(args.name, args.pubkey)
    elif args.cmd == 'show':
        show(args.name)
    elif args.cmd == 'list':
        list_clients()
