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

Floating IPs
++++++++++++

Floating IPs do not work currently. The problem is that the default
gateway of the network node is **not** in the correct network.

For instance, you can't ping google from within the VM, and you can't
access the public IP of the VM from the physical node.

To fix this, we need to:

1) give an IP address on the br1 interface on the physical node
   (emulating the router of the public network)
2) add a SNAT rule for IPs in the 172.16.0.0/16 network
2) update the default gateway on the network node.


On the physical node::

    [root@gks-061 ~]# ifconfig br1:0 172.16.0.1/16
    [root@gks-061 ~]# iptables -A POSTROUTING -t nat -s 172.16.0.0/16 -j MASQUERADE

on the network node::

    root@network-node:~# route -n
    Kernel IP routing table
    Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
    0.0.0.0         10.0.0.1        0.0.0.0         UG    0      0        0 eth0
    10.0.0.0        0.0.0.0         255.255.255.0   U     0      0        0 eth0
    10.99.0.0       0.0.0.0         255.255.252.0   U     0      0        0 br100
    172.16.0.0      0.0.0.0         255.255.0.0     U     0      0        0 eth1
    root@network-node:~# route del default gw 10.0.0.1
    root@network-node:~# route add default gw 172.16.0.1 dev eth1
    root@network-node:~# 

Please note that those changes (especially those in the physical
machine) are only needed because of the specific configuration of the
testbed.

On a production environment, the public IP are actually public, and
your API servers will use this network to access internet, so there is
no need to change the default routing table on the network node, and
there is no need to set any NAT rule since the IP are public and
routing happens on some network device already set up.


proposed sabotages (but you can be creative!)
+++++++++++++++++++++++++++++++++++++++++++++

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

cinder <-> glance
-----------------

In the default configuration, if you try to `boot from image (creates
a new volume)` it will fail.

On the volume-node, ``/var/log/cinder/cinder-api.log`` you will find::

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

The problem is that cinder is *assuming* that the glance server is on
localhost (in this case, 10.0.0.8 is the `volume-node`).

In order to fix this, you need to add to ``/etc/cinder/cinder.conf``::

    glance_api_servers=10.0.0.5:9292

A second issue you may find, if you are using qcow2 images, is that
`qemu-img` is not installed on the volume node::

    2014-08-28 16:34:52.760 5192 ERROR oslo.messaging.rpc.dispatcher [req-aac299e3-833c-4b8c-b2ae-09bdbbd615b4 df77e2b579b04b8a81ba0e993a318b19 cacb2edc36a343c4b4747b8a8349371a - - -] Exception during message handling: Image 7b05a000-dd1b-409a-ba51-a567a9ebec13 is unacceptable: qemu-img is not installed and image is of type qcow2.  Only RAW images can be used if qemu-img is not installed.

In this case, just install ``qemu-utils`` package and retry.

test with::

    root@api-node:~# nova boot --block-device id=7b05a000-dd1b-409a-ba51-a567a9ebec13,source=image,dest=volume,size=1,shutdown=remove,bootindex=0 --key-name gridka-auth-node --flavor m1.tiny test-from-volume




List of possible checks
+++++++++++++++++++++++

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
