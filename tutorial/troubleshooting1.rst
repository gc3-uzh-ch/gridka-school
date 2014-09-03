Troubleshooting
===============

Floating IPs
------------

Problem
~~~~~~~

The setup of our testbed is quite irregular, since we are using
private IPs for the floating ip range, and the machines are not
connected to a "real" network, but instead are connected to a virtual
bridge in a physical machine.

Because of that, the current configuration is **not** working as
expected. You will realize this trying to ping `www.google.com` form
within a virtual machine.

Also connecting to a virtual machine from the physical node will not
work.

To debug this, you will need to understand the following commands:
* tcpdump
* iptables
* route
* ip
* ping
* nc

Since these are two different problems, you need to analyze them
separately.

1) First, ping from `www.google.com` from a virtual machine, and check
   what happens to packets coming out from the virtual machine.
2) Then, try to understand what happen when you try to connect to a VM
   (tcp port 22) from a physical machine (`gks-NNN`).

Bonus question: since we are not able to ping google, how can we
resolve its hostname?

troubleshooting the problem
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Let's recap what happens when you assign a floating IP to a VM (doing
it manually or using `auto_assign_floating_ip` is the same)

* The floating IP is assigned to the public interface of the
  network-node (check with `ip addr show`)

* Firewall rules are added to the `nat` table of the network
  node. Specifically:
  - DNAT rule to redirect all traffic to the floating IP towards the
    private IP of the VM
  - SNAT rule to modify all packets originated on the VM and directed
    to the interned, replacing the source address (the private IP)
    with the floating IP

* The packet is then routed on the default gateway.

To debug this, let's ping google from the VM, and then use tcpdump to
see where the packets goes.

* First, run tcpdump on the compute node, to check if it's actually
  coming out::

     root@compute-1:~# tcpdump -i br100 -n icmp
     tcpdump: WARNING: br100: no IPv4 address assigned
     tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
     listening on br100, link-type EN10MB (Ethernet), capture size 65535 bytes
     10:13:31.513718 IP 10.99.0.2 > 173.194.113.145: ICMP echo request, id 56064, seq 90, length 64

  yes, it is.

* Then, check if the packets arrives to the integration network of the
  network-node::

      root@network-node:~# tcpdump -i br100 icmp -n
      tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
      listening on br100, link-type EN10MB (Ethernet), capture size 65535 bytes
      10:14:13.532368 IP 10.99.0.2 > 173.194.113.145: ICMP echo request, id 56064, seq 132, length 64

  Yes!

* The packet should be NAT-ted and routed towards the default gateway,
  which is 10.0.0.1 and is connected to the `eth0` interface::

      root@network-node:~# ip route 
      default via 10.0.0.1 dev eth0 
      10.0.0.0/24 dev eth0  proto kernel  scope link  src 10.0.0.7 
      10.99.0.0/22 dev br100  proto kernel  scope link  src 10.99.0.1 
      172.16.0.0/16 dev eth1  proto kernel  scope link  src 172.16.0.7 

  Let's see what happen on the `eth0` interface::

      root@network-node:~# tcpdump -i eth0 -n icmp
      tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
      listening on eth0, link-type EN10MB (Ethernet), capture size 65535 bytes
      10:15:53.570698 IP 10.99.0.2 > 173.194.113.145: ICMP echo request, id 56064, seq 232, length 64

* Uhm, NAT is not working, let's check the iptables rules::

      root@network-node:~# iptables -L -t nat -v 
      Chain PREROUTING (policy ACCEPT 15 packets, 4523 bytes)
       pkts bytes target     prot opt in     out     source               destination         
         20  3456 nova-network-PREROUTING  all  --  any    any     anywhere             anywhere            
         15  4523 nova-api-metadat-PREROUTING  all  --  any    any     anywhere             anywhere            

      Chain INPUT (policy ACCEPT 21 packets, 4859 bytes)
       pkts bytes target     prot opt in     out     source               destination         

      Chain OUTPUT (policy ACCEPT 74 packets, 7961 bytes)
       pkts bytes target     prot opt in     out     source               destination         
         23  3948 nova-network-OUTPUT  all  --  any    any     anywhere             anywhere            
         74  7961 nova-api-metadat-OUTPUT  all  --  any    any     anywhere             anywhere            

      Chain POSTROUTING (policy ACCEPT 63 packets, 4298 bytes)
       pkts bytes target     prot opt in     out     source               destination         
         24  4032 nova-network-POSTROUTING  all  --  any    any     anywhere             anywhere            
         63  4298 nova-api-metadat-POSTROUTING  all  --  any    any     anywhere             anywhere            
         63  4298 nova-postrouting-bottom  all  --  any    any     anywhere             anywhere            

      Chain nova-api-metadat-OUTPUT (1 references)
       pkts bytes target     prot opt in     out     source               destination         

      Chain nova-api-metadat-POSTROUTING (1 references)
       pkts bytes target     prot opt in     out     source               destination         

      Chain nova-api-metadat-PREROUTING (1 references)
       pkts bytes target     prot opt in     out     source               destination         

      Chain nova-api-metadat-float-snat (1 references)
       pkts bytes target     prot opt in     out     source               destination         

      Chain nova-api-metadat-snat (1 references)
       pkts bytes target     prot opt in     out     source               destination         
         63  4298 nova-api-metadat-float-snat  all  --  any    any     anywhere             anywhere            

      Chain nova-network-OUTPUT (1 references)
       pkts bytes target     prot opt in     out     source               destination         
          0     0 DNAT       all  --  any    any     anywhere             172.16.1.1           to:10.99.0.2

      Chain nova-network-POSTROUTING (1 references)
       pkts bytes target     prot opt in     out     source               destination         
          0     0 ACCEPT     all  --  any    any     10.99.0.0/22         network-node        
         11  3171 ACCEPT     all  --  any    any     10.99.0.0/22         10.99.0.0/22         ! ctstate DNAT
          0     0 SNAT       all  --  any    any     10.99.0.2            anywhere             ctstate DNAT to:172.16.1.1

      Chain nova-network-PREROUTING (1 references)
       pkts bytes target     prot opt in     out     source               destination         
          8   480 DNAT       tcp  --  any    any     anywhere             169.254.169.254      tcp dpt:http to:10.0.0.7:8775
          0     0 DNAT       all  --  any    any     anywhere             172.16.1.1           to:10.99.0.2

      Chain nova-network-float-snat (1 references)
       pkts bytes target     prot opt in     out     source               destination         
          0     0 SNAT       all  --  any    any     10.99.0.2            10.99.0.2            to:172.16.1.1
          0     0 SNAT       all  --  any    eth1    10.99.0.2            anywhere             to:172.16.1.1

      Chain nova-network-snat (1 references)
       pkts bytes target     prot opt in     out     source               destination         
         13   861 nova-network-float-snat  all  --  any    any     anywhere             anywhere            
          0     0 SNAT       all  --  any    eth1    10.99.0.0/22         anywhere             to:10.0.0.7

      Chain nova-postrouting-bottom (1 references)
       pkts bytes target     prot opt in     out     source               destination         
         13   861 nova-network-snat  all  --  any    any     anywhere             anywhere            
         63  4298 nova-api-metadat-snat  all  --  any    any     anywhere             anywhere            


  The relevant rules for us are in ``nova-network-snat``::

          0     0 SNAT       all  --  any    eth1    10.99.0.0/22         anywhere             to:10.0.0.7

  After a while, you realize what's "wrong" with this rule: the packet
  is SNAT-ted only when it's coming out from the `eth1`
  interface. Why? Because the `public network` is on that network, but
  our default gateway is on the `eth0` interface!

* The first think you may try is to set `public_interface`
  configuration option on ``/etc/nova/nova.conf`` to `eth0` and
  restart nova-network (to do it cleanly, also delete the test
  instance and restart it)::

      root@network-node:~# sed -i 's/public_interface.*/public_interface=eth0/' /etc/nova/nova.conf 
      root@network-node:~# service nova-network restart
      nova-network stop/waiting
      nova-network start/running, process 2168

  and after the VM is started::

      root@network-node:~# ip addr show eth0
      2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
          link/ether 52:54:00:61:8e:f1 brd ff:ff:ff:ff:ff:ff
          inet 10.0.0.7/24 brd 10.0.0.255 scope global eth0
             valid_lft forever preferred_lft forever
          inet 172.16.1.1/32 scope global eth0
             valid_lft forever preferred_lft forever

  ping still doesn't work.

* Let's see what happen again on the network node::

      root@network-node:~# tcpdump -i eth0 -n icmp
      tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
      listening on eth0, link-type EN10MB (Ethernet), capture size 65535 bytes
      10:25:17.823400 IP 172.16.1.1 > 173.194.113.148: ICMP echo request, id 52224, seq 14, length 64

  so, the IP is actually coming out from the network node, on the
  "right" interface, and with the *right* IP address. Why don't we see
  the ping replies?

* Let's now check on the physical node::

      [root@gks-061 ~]# tcpdump -i br1 -n icmp
      tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
      listening on br1, link-type EN10MB (Ethernet), capture size 65535 bytes
      10:27:45.694425 IP 10.99.0.2 > 173.194.113.148: ICMP echo request, id 56320, seq 2, length 64
      10:27:45.694504 IP 172.16.1.1 > 173.194.113.148: ICMP echo request, id 56320, seq 2, length 64

  No wonder here: the first packet, coming from 10.99.0.2 is the one
  flowing from the VM to the network node, that we are seeing because
  we use one big bridge for all the interfaces. The second packet is
  the one translated by the network node, and directed to the
  "gateway". You can check this by also viewing the mac addresses::

      [root@gks-061 ~]# tcpdump -i br1 -n icmp -e
      tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
      listening on br1, link-type EN10MB (Ethernet), capture size 65535 bytes
      10:29:25.523369 fa:16:3e:20:5f:65 > 52:54:00:25:67:05, ethertype IPv4 (0x0800), length 98: 10.99.0.2 > 173.194.113.144: ICMP echo request, id 59136, seq 0, length 64
      10:29:25.523446 52:54:00:61:8e:f1 > 00:30:48:d4:5f:99, ethertype IPv4 (0x0800), length 98: 172.16.1.1 > 173.194.113.144: ICMP echo request, id 59136, seq 0, length 64
      [root@gks-061 ~]# ip addr show br1
      4: br1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN 
          link/ether 00:30:48:d4:5f:99 brd ff:ff:ff:ff:ff:ff
          inet 10.0.0.1/24 brd 10.0.0.255 scope global br1
          inet6 fe80::230:48ff:fed4:5f99/64 scope link 
             valid_lft forever preferred_lft forever

  The second packet has destination mac address of the physical node,
  which is correct. The first packet instead has the mac address of
  the network node::

      root@network-node:~# ip addr show br100
      5: br100: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
          link/ether 52:54:00:25:67:05 brd ff:ff:ff:ff:ff:ff
          inet 10.99.0.1/22 brd 10.99.3.255 scope global br100
             valid_lft forever preferred_lft forever

  again correct, because this is the default gateway for the VM.

* What happen on the routing from within the physical node?::

      [root@gks-061 ~]# ip route 
      10.0.0.0/24 dev br1  proto kernel  scope link  src 10.0.0.1 
      141.52.174.0/24 dev eth0  proto kernel  scope link  src 141.52.174.61 
      default via 141.52.174.1 dev eth0 

  Default gateway is `eth0`, but if you check with tcpdump you will
  see that the packet is not forwarded. Looking at iptables rules for
  the `filter` and `nat` tables will make evident that the physical
  node is not forwarding the packets (nor NAT-ting them, since the
  network we are using for public access is not actually public)


You should have realized by now that there are two problems at the
same time:

* routing: ICMP reply packets are not routed to the correct interface,
  because the physical node do not know that 172.16.0.0/16 network is
  behind the `br1` interface
* firewall: the physical node do not allow forwarding of the packets
  (`iptables -L FORWARD`) nor is NAT-ting the packets in order to use
  a *real* public IP address.

There are two way to solve this issue:

1) add a "public" ip to the physical node, to be used as router for the
   openstack nodes (similar to having a *real* router on the public network)::

       [root@gks-061 ~]# ifconfig br1:0 172.16.0.1/16

   enable NAT-ting for those IP addresses::

       [root@gks-061 ~]# iptables -A POSTROUTING -t nat -o eth0 -s 172.16.0.0/16 -j MASQUERADE

   finally, modify the routing on the **network-node**, so that
   packets are sent to the physical machine using the correct network::

       root@network-node:~# route del default gw 10.0.0.1
       root@network-node:~# route add default gw 172.16.0.1 dev eth1

   In this case, the floating IPs are all added to interface `eth1` of
   the network-node, so you need to put `public_interface=eth1` in ``/etc/nova/nova.conf``

2) an alternative approach, that does not modify the network
   configuration of the **network-node**, but instead:

   modify the `public_interface` option in ``/etc/nova/nova.conf`` and
   set it to `eth0`. In this case, packets will go to the physical
   machine on the interface `br1`.

   You also need to tell the physical machine *where* the
   172.16.0.0/16 network lives, by modifying its routing table::

       [root@gks-061 ~]# route add -net 172.16.0.0/16 dev br1

   and, like we did before, add a rule to the firewall to MASQUERADE
   the outgoing traffic, needed because we are using private IPs
   instead of public ones::

       [root@gks-061 ~]# iptables -A POSTROUTING -t nat -o eth0 -s 172.16.0.0/16 -j MASQUERADE


Please note that those changes (especially those in the physical
machine) are only needed because of the specific configuration of the
testbed.

On a production environment, the public IP are actually public, and
your API servers will use this network to access internet, so there is
no need to change the default routing table on the network node, and
there is no need to set any NAT rule since the IP are public and
routing happens on some network device already set up.


cinder <-> glance - Creating volume from image and boot from volume
-------------------------------------------------------------------

Problem
~~~~~~~

On OpenStack, you can create a volume from a Glance image, and then
boot from the volume. You can also decide if the volume shall be
deleted after instance termination or if it has to be a permanent
volume.

However, the current configuration will not work.

You can test the issue booting an instance from the web interface and
choose `boot from image (creates a new volume)`, or from the command
line running the following command::

   root@api-node:~# nova boot \
     --block-device \
     id=7b05a000-dd1b-409a-ba51-a567a9ebec13,source=image,dest=volume,size=1,shutdown=remove,bootindex=0 \
     --key-name gridka-auth-node --flavor m1.tiny test-from-volume

The machine will go in ERROR state, and on the **volume-node**, in
``/var/log/cinder/cinder-api.log`` you will find::

    2014-08-28 16:22:33.743 3966 AUDIT cinder.api.v1.volumes [req-e19de3f2-c09b-46f4-97ac-ca9b21776916 df77e2b579b04b8a81ba0e993a318b19 cacb2edc36a343c4b4747b8a8349371a - - -] Create volume of 1 GB
    2014-08-28 16:22:33.781 3966 ERROR cinder.image.glance [req-e19de3f2-c09b-46f4-97ac-ca9b21776916 df77e2b579b04b8a81ba0e993a318b19 cacb2edc36a343c4b4747b8a8349371a - - -] Error contacting glance server '10.0.0.8:9292' for 'get', done trying.
    2014-08-28 16:22:33.781 3966 TRACE cinder.image.glance Traceback (most recent call last):
    2014-08-28 16:22:33.781 3966 TRACE cinder.image.glance   File "/usr/lib/python2.7/dist-packages/cinder/image/glance.py", line 158, in call
    2014-08-28 16:22:33.781 3966 TRACE cinder.image.glance     return getattr(client.images, method)(*args, **kwargs)
    2014-08-28 16:22:33.781 3966 TRACE cinder.image.glance   File "/usr/lib/python2.7/dist-packages/glanceclient/v1/images.py", line 114, in get
    2014-08-28 16:22:33.781 3966 TRACE cinder.image.glance     % urllib.quote(str(image_id)))
    2014-08-28 16:22:33.781 3966 TRACE cinder.image.glance   File "/usr/lib/python2.7/dist-packages/glanceclient/common/http.py", line 289, in raw_request
    2014-08-28 16:22:33.781 3966 TRACE cinder.image.glance     return self._http_request(url, method, **kwargs)
    2014-08-28 16:22:33.781 3966 TRACE cinder.image.glance   File "/usr/lib/python2.7/dist-packages/glanceclient/common/http.py", line 235, in _http_request
    2014-08-28 16:22:33.781 3966 TRACE cinder.image.glance     raise exc.CommunicationError(message=message)
    2014-08-28 16:22:33.781 3966 TRACE cinder.image.glance CommunicationError: Error communicating with http://10.0.0.8:9292 [Errno 111] ECONNREFUSED
    2014-08-28 16:22:33.781 3966 TRACE cinder.image.glance 
    2014-08-28 16:22:33.787 3966 ERROR cinder.api.middleware.fault [req-e19de3f2-c09b-46f4-97ac-ca9b21776916 df77e2b579b04b8a81ba0e993a318b19 cacb2edc36a343c4b4747b8a8349371a - - -] Caught error: Connection to glance failed: Error communicating with http://10.0.0.8:9292 [Errno 111] ECONNREFUSED


Solution
~~~~~~~~

The problem is that cinder is *assuming* that the glance server is on
localhost (in this case, 10.0.0.8 is the `volume-node`).

In order to fix this, you need to add to ``/etc/cinder/cinder.conf``::

    glance_api_servers=10.0.0.5:9292

A second issue you may find, if you are using qcow2 images, is that
`qemu-img` is not installed on the volume node::

    2014-08-28 16:34:52.760 5192 ERROR oslo.messaging.rpc.dispatcher [req-aac299e3-833c-4b8c-b2ae-09bdbbd615b4 df77e2b579b04b8a81ba0e993a318b19 cacb2edc36a343c4b4747b8a8349371a - - -] Exception during message handling: Image 7b05a000-dd1b-409a-ba51-a567a9ebec13 is unacceptable: qemu-img is not installed and image is of type qcow2.  Only RAW images can be used if qemu-img is not installed.

In this case, just install ``qemu-utils`` package and retry.




Troubleshooting challenge session
---------------------------------

The idea of this session is to try to learn how to debug an OpenStack
installation.

Below there is a list of proposed *sabotages* that you can do on your
machines. The idea is that each one of you will perform one or more of
these *sabotages* and then will switch with someone else.

Then, you will have to check that the installation is working
(actually, find what is *not* working as expected) and try to fix the
problem.


proposed sabotages (but you can be creative!)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

* Remove the "admin" role from one of the "nova", "glance", "cinder"
  users::

    root@auth-node:~# keystone user-role-remove \
      --user-id <user_id> \
      --role-id fafa8117d1564d8c9ec4fe6dbf985c68 \
      --tenant-id cb0e475306cc4c91b2a43b537b1a848b

  and see what does **not** work anymore.

* remove or replace with an invalid IP address the ``rabbit_host``
  configuration option on one of the configuration file and restart
  the service.

* Fill the ``/var/lib/nova/instances`` directory by creating a big
  file using dd, and try to start a virtual machine

* shutdown one of the services at the time and see what does not work
  anymore:

  - rabbitmq
  - mysql
  - nova-api
  - nova-network
  - glance-api
  - glance-registry
  
  try to start virtual machines both with the ``nova`` command line
  tool and via web interface and check if there are differences.

* Set a *wrong* password in ``/etc/nova/nova.conf`` file on the
  **api-node** for the sql connection, restart all the nova services

* Do the same, but for the **glance-api** service

* Do the same, but for the **glance-registry** service

* Do the same, but for the **cinder** service

* Similarly, try to put the wrong *keystone* password on one of the
  main services.

* Try to remove ``iscsi_ip_address` from ``/etc/cinder/cinder.conf``
  (or just replace the address it with an invalid one) and restart the
  cinder services. Then, try to create a volume and attach it to a
  running instance.

* remove all the floating IPs with the ``nova-manage floating
  delete``. Play also with the ``auto_assign_floating_ip`` option of
  the ``/etc/nova/nova.conf`` configuration file. (if you are very
  mean, you can replace the floating IPs with similar but invalid ones)

* change the value of `public_interface` in ``/etc/nova/nova.conf`` on
  the **network-node**

* delete all floating IPs and re-create them adding option
  ``--interface eth0``. Then, start a VM and see what happens to the
  interfaces of the network-node



List of possible checks
~~~~~~~~~~~~~~~~~~~~~~~

* upload an image
* start an instance using ``nova``
* start an instance using the web interface
* create a snapshot (both from web and command line)
* create a volume (both from web and command line)
* attach a volume to a running instance (web/CLI)
* connect to the instance using ssh
* connect to the instance on a port different than 22 (hint: use
  netcat or ssh)
* start an instance using ``euca-start-instances`` (note: we didn't
  tell you how to do it)

.. Notes:
   * missing information about the metadata service
   * missing info about the user-data
   * missing detailed information on the security groups
   * missing info about 
   * FIXME: next time, use images with updated software, to avoid a
     long delay when running apt-get upgrade
   * missing info on the ec2 compatible interface
   * not discussion about multi-node/single-node network

.. elasticluster:
   on the node
   (elasticluster)root@gks-246:[~] $ lsb_release -a
   LSB Version:	:base-4.0-amd64:base-4.0-noarch:core-4.0-amd64:core-4.0-noarch:graphics-4.0-amd64:graphics-4.0-noarch:printing-4.0-amd64:printing-4.0-noarch
   Distributor ID:	Scientific
   Description:	Scientific Linux release 6.4 (Carbon)
   Release:	6.4
   Codename:	Carbon

   (elasticluster)root@gks-246:[~] $ pip install elasticluster

   (elasticluster)root@gks-246:[~] $ elasticluster list-templates
   Traceback (most recent call last):
     File "/root/elasticluster/bin/elasticluster", line 8, in <module>
       load_entry_point('elasticluster==1.0.2', 'console_scripts', 'elasticluster')()
     File "/root/elasticluster/lib/python2.6/site-packages/setuptools-0.6c11-py2.6.egg/pkg_resources.py", line 318, in load_entry_point
     File "/root/elasticluster/lib/python2.6/site-packages/setuptools-0.6c11-py2.6.egg/pkg_resources.py", line 2221, in load_entry_point
     File "/root/elasticluster/lib/python2.6/site-packages/setuptools-0.6c11-py2.6.egg/pkg_resources.py", line 1954, in load
     File "/root/elasticluster/lib/python2.6/site-packages/elasticluster/main.py", line 32, in <module>
       from elasticluster.subcommands import Start, SetupCluster
     File "/root/elasticluster/lib/python2.6/site-packages/elasticluster/subcommands.py", line 27, in <module>
       from elasticluster.conf import Configurator
     File "/root/elasticluster/lib/python2.6/site-packages/elasticluster/conf.py", line 33, in <module>
       from elasticluster.providers.gce import GoogleCloudProvider
     File "/root/elasticluster/lib/python2.6/site-packages/elasticluster/providers/gce.py", line 37, in <module>
       from oauth2client.tools import run
     File "/root/elasticluster/lib/python2.6/site-packages/oauth2client/tools.py", line 27, in <module>
       import argparse
   ImportError: No module named argparse


.. elasticluster:
   still problems with default configuration. Comment all the clusters
   but the needed one. If you change the name of the hobbes cloud you
   get a useless configuration error: "c"

   Also remove the id_dsa.cloud.pub key!

.. elasticluster:
   move the cluster sections just below the cloud section.

.. elasticluster: delete an instance, you will get an error and the vm
   appear "building". Instead, it should be removed and re-created.

.. elasticluster on centos: it seems it is not ignoring the
   known_hosts, even though it's saying so. TO TEST
