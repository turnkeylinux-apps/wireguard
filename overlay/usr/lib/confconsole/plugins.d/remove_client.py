'''Remove wireguard client(peer)'''

import os
import glob
import subprocess
TITLE = "Remove client"


def run():
    while True:
        list = glob.glob("/etc/wireguard/clients/*.conf")
        profiles = []
        for idx, file in enumerate(list):
            base = os.path.basename(file)
            file = os.path.splitext(base)[0]
            profiles.append((file, str(idx)))

        if profiles:
            ret, profile = console.menu(TITLE, "Select profile", profiles)
            if ret == 'ok':
                proc = subprocess.run([
                    'wireguard-removeclient', profile,
                ], capture_output=True, text=True)
                if proc.returncode:
                    console.msgbox(TITLE, proc.stderr)
                else:
                    console.msgbox(TITLE, proc.stdout)
            else:
                break

        if not profiles:
            console.msgbox(TITLE, "Clients list is empty.")
            break
