'''Create wireguard client(peer)'''

import os
from subprocess import Popen, CalledProcessError, PIPE, check_output

TITLE = "Add client"

def run():
    while True:
        rty, name = console.inputbox(TITLE, "Enter name")
        if rty == 'cancel': break

        rte, traffic_cidr = console.inputbox(TITLE, "Enter traffic CIDR to route into VPN")
        if rte == 'ok' and rty == 'ok':
            proc = Popen(["wireguard-addclient", name, traffic_cidr],
                stderr=PIPE, stdout=PIPE, text=True)
            out, err = proc.communicate()
            returncode = proc.returncode
            if returncode == 0:
                out = console.yesno(f'{out}\nGenerate download link for conf?',
                                    autosize=True)
                if out == 'ok':
                    console.msgbox(TITLE, check_output([
                        '/var/www/wireguard/bin/addprofile', name
                    ], text=True))
                break
            else:
                console.msgbox(TITLE, f'{err}')
            break
        else:
           break
