'''Create a link to client's profile'''

import os, glob
from subprocess import check_output, CalledProcessError, PIPE
TITLE = "Create profile download page"

def run():
    list = glob.glob("/etc/wireguard/clients/*.conf")
    profiles = []
    for idx, file in enumerate(list):    
        base = os.path.basename(file)
        file = os.path.splitext(base)[0]
        profiles.append((file, str(idx)))
    
    if profiles:
        ret, profile = console.menu(TITLE, "Select profile", profiles) 
        if ret == 'ok':
            console.msgbox(TITLE, check_output(["/var/www/wireguard/bin/addprofile", profile], text=True))

    if not profiles:
        console.msgbox(TITLE, "First create a client via Add client menu.")
