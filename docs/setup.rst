**Important note to TurnKey Hub users**: There is currently a bug_ that means you will need to manually run the firstboot Wireguard config script (aka inithook) interactively; like this::

    /usr/lib/inithooks/bin/wireguard.py

----

In this example configuration we'll describe a situation where
2 computers running on a 192.168.1.0/24 subnet wish to form a
strict server/client tunnel. Where "client" tunnels all of their
traffic through "server". The virtual subnet used by these
computers will be the 10.0.0.0/8 subnet.

Setting up a WireGuard® TurnKey Linux server
============================================

Setting up a WireGuard® TurnKey VPN server is dead simple.

1. In the inithooks, choose ``server`` as your profile.

2. Type in the address of your TurnKey WireGuard® server within your
   virtual subnet when prompted for ``Wireguard Virtual Address`` as per
   this example configuration we put ``10.0.0.0/8`` here.

.. note::
   
   This is in CIDR_ format and is used to describe both your
   VPN server's IP address within the virtual network but also 
   the subnet used by the virtual network.

   Example:

      10.0.0.0/8 - describes a server IP address of 10.0.0.0
         where all 10.X.X.X ip addresses are within the virtual
         subnet.

      10.0.0.0/16 - describes a server IP address of 10.0.0.0
         where all 10.0.X.X ip addresses are within the virtual
         subnet.

      10.0.55.1/24 - describes a server IP address of 10.0.55.1
         where all 10.0.55.X ip addresses are within the virtual
         subnet.

3. Type in the address on which the client and server can ALREADY
   communicate, on our example configuration both computers exist
   on the 192.168.1.0/24 subnet and let's say the server's IP is
   192.168.1.1 for simplities sake. In this case we type in
   ``192.168.1.1``

.. note::
   
   The only bounds for this value is that it's already accessible
   by the client. So if connected to the wider internet you could
   use a public IP address or a fqdn.

Adding Clients
--------------

There are 2 ways to quickly and easily add clients, although
really they are identical, there's a script called
``wireguard-addclient`` which can be called from the commandline
and there's a confconsole plugin labeled "Addclient" under the
advanced menu (which leverages the script behind the scenes).

Each take 2 arguments:

   1. "name" used only to identify the config currently. It
         probably should be unique.

   2. "traffic to route" this is another address in CIDR format
         here though it's used ONLY to determine which of the
         client's traffic should be routed through the VPN. 

         example:

            - 0.0.0.0/0 # will route ALL traffic through the VPN
            - 172.0.0.0/8 # will route traffic to and from
                  the 172.X.X.X subnet through the VPN

Both methods will generate a file
``/etc/wireguard/clients/<name>.conf`` 

Setting up a TurnKey WireGuard® client
======================================

So you've got your server, your client configuration now what?

1. Choose ``client`` profile in the inithooks

2. Copy the client configuration from the server to
   ``/etc/wireguard/wg0.conf``

3. Run ``wg-quick up wg0``

4. DONE!

Important note re WireGuard® trademark
======================================

**Note**: WireGuard® is a registered trademarks of Jason A. Donenfeld.
TurnKey Linux is not affiliated with Jason A. Donenfeld or `WireGuard®`_
Neither this software appliance, or the TurnKey provided, custom
configuration scripts are endorsed by Jason A. Donenfeld or `WireGuard®`_.

.. _CIDR: https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing
.. _WireGuard®: https://www.wireguard.com/
.. _bug: https://github.com/turnkeylinux/tracker/issues/1646
