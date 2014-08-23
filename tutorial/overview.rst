Tutorial overview
-----------------

For this tutorial we will work in teams. Each team is composed of 2
people and will have assigned two physical machines to work with.

One of the nodes will run the 6 VMs hosting the **central services**. 
They are called as follows:

* ``db-node``:  runs *MySQL* and *RabbitMQ*

* ``auth-node``: runs *keystone*, the identity and authentication
  service

* ``image-node``: runs **glance**, the image storage, composed of the
  *glance-api* and glance-registry* services

* ``api-node``: runs most of the **nova** service: *nova-api*,
  *horizon*, *nova-scheduler*, *nova-conductor* and *nova-console*.

* ``network-node``: runs the legacy network services:
  *nova-network* and *nova-metadata*.

* ``volume-node``: runs **cinder**, the volume manager, composed of
  the *cinder-api*, *cinder-scheduler* and *cinder-volume* services


The other node will run 3 VMs hosting the **compute nodes** and the
**neutron-node** for your stack.

* ``compute-1``: runs *nova-compute*
* ``compute-2``: runs *nova-compute*
* ``neutron-node``: runs **neutron**, the NaaS manager. 

The legacy ``nova-network`` service is going to be deprecated although 
it isn't clear exactly when. Thus, on the last day we will install the 
service which will become its de facto substitute. 

How to access the physical nodes
++++++++++++++++++++++++++++++++

In order to access the different virtual machines and start working on
the configuration of OpenStack services listed above you will have to
first login on one of the nodes assigned to your group by doing::

        ssh root@gks-NNN.scc.kit.edu -p 24 -X

where NNN is one of the numbers assigned to you.

Physical machines are assigned as follow:

+---------+------------------+---------------+
| team    | central services | compute nodes |
+=========+==================+===============+
| team 01 | gks-NNN          | gks-NNN       |
+---------+------------------+---------------+
| team 02 | gks-NNN          | gks-NNN       |
+---------+------------------+---------------+
| team 03 | gks-NNN          | gks-NNN       |
+---------+------------------+---------------+
| team 04 | gks-NNN          | gks-NNN       |
+---------+------------------+---------------+
| team 05 | gks-NNN          | gks-NNN       |
+---------+------------------+---------------+
| team 06 | gks-NNN          | gks-NNN       |
+---------+------------------+---------------+
| team 07 | gks-NNN          | gks-NNN       |
+---------+------------------+---------------+
| team 08 | gks-NNN          | gks-NNN       |
+---------+------------------+---------------+
| team 09 | gks-NNN          | gks-NNN       |
+---------+------------------+---------------+
| team 10 | gks-NNN          | gks-NNN       |
+---------+------------------+---------------+


Virtual Machines
++++++++++++++++

The physical nodes already have the KVM virtual machines we will use
for the tutorial. These are Ubuntu 14.04 LTS machines with very basic
configuration, including the IP configuration and the correct hostname.

Start the Virtual Machines
~~~~~~~~~~~~~~~~~~~~~~~~~~

You can start and stop the VMs using the ``virt-manager`` graphical
interface or the ``virsh`` command line tool.

All the VMs are initially stopped so the first exercise
you have to do will be to start them all. Connect to both
of the physical nodes and run::

    virt-manager

Please note that each VM has its golden clone, called  **hostname-golden**. 
They can be used to easily recreate a particular service or compute VM
from scratch. Please **keep them OFF** and start the rest of the VMs. 

However, if you prefer to use the ``virsh`` command line interface,
run on one of the physical nodes the following commands::

    root@gks-001:[~] $ virsh start db-node
    root@gks-001:[~] $ virsh start auth-node
    root@gks-001:[~] $ virsh start image-node
    root@gks-001:[~] $ virsh start volume-node
    root@gks-001:[~] $ virsh start api-node
    root@gks-001:[~] $ virsh start network-node

and on the *other* physical node::

    root@gks-002:[~] $ virsh start compute-1
    root@gks-002:[~] $ virsh start compute-2
    root@gks-002:[~] $ virsh start neutron-node

Access the Virtual Machines
~~~~~~~~~~~~~~~~~~~~~~~~~~~

You can connect to them from each one of the physical machines (the
**gks-NNN** ones) using **ssh** or by starting the ``virt-manager``
program on the physical node hosting the virtual machine and then
connecting to the console.

In order to connect using **ssh** please do::

     ssh root@hostname 

where **hostname** is one of those listed above. We recommed to use the
**ssh** mode for accessing the hosts because it will easy your interaction
with the VM and provide more suitable interface in case you want to
copy/paste some of the commands in the tutorial. 

All the Virtual Machines have the same password: **user@gridka**

Network Setup
+++++++++++++

Each virtual machine has 3 network interfaces, with the exception of the
**network-node** that have 4. Some of these interfaces have been already
configured, so that you can already connect to them using either the
"*public*" or the private ip address.

These are the networks we are going to use:

+------+-----------------------+------------------+
| eth0 | internal KVM network  | 192.168.122.0/24 |
+------+-----------------------+------------------+
| eth1 | internal network      | 10.0.0.0/24      |
+------+-----------------------+------------------+
| eth2 | public network        | 172.16.0.0/16    |
+------+-----------------------+------------------+
| eth3 | Openstack private     |                  |
|      | network (present only |                  |
|      | on the network-node)  |                  |
+------+-----------------------+------------------+

The *internal KVM network* is a network needed because our virtual
machines does not have real public IP addresses, therefore we need to
allow them to communicate through the physical node. The libvirt
daemon will automatically assign an IP address to this interface and
set the needed iptables rules in order to configure the NAT and allow
the machine to connect to the internet. On a production environment,
you will not have this interface.

The *internal network* is a trusted network used by all the OpenStack
services to communicate to each other. Usually, you wouldn't setup a
strict firewall on this ip address.

The *public network* is the network exposed to the Internet. In our
case we are using a non-routable IP range because of the constraints
imposed by the tutorial setup, but on a production environment you
will use public ip addresses instead and will setup a firewall in
order to only allow connection on specific ports.

The *OpenStack private network* is the internal network of the
OpenStack virtual machines. The virtual machines need to communicate
with the network node, (unless a "multinode setup is used") and among
them, therefore this network is configured only on the network node
(that also need to have an IP address in it) and the compute nodes,
which only need to have an interface on this network attached to a
bridge the virtual machines will be attached to. On a production
environment you would probably use a separated L2 network for this,
either by using VLANs or using a second physical interface.

The following diagram shows both the network layout of the physical
machines and of the virtual machines running in it:

.. image:: ../images/network_diagram.png

The IP addresses of these machines are:

+--------------+--------------+-----------+--------------------------+------------+
| host         | private      | private   | public hostname          | public     |
|              | hostname     | IP        |                          | IP         |
+==============+==============+===========+==========================+============+
| db node      | db-node      | 10.0.0.3  | db-node.example.org      | 172.16.0.3 |
+--------------+--------------+-----------+--------------------------+------------+
| auth node    | auth-node    | 10.0.0.4  | auth-node.example.org    | 172.16.0.4 |
+--------------+--------------+-----------+--------------------------+------------+
| image node   | image-node   | 10.0.0.5  | image-node.example.org   | 172.16.0.5 |
+--------------+--------------+-----------+--------------------------+------------+
| api node     | api-node     | 10.0.0.6  | api-node.example.org     | 172.16.0.6 |
+--------------+--------------+-----------+--------------------------+------------+
| network node | network-node | 10.0.0.7  | network-node.example.org | 172.16.0.7 |
+--------------+--------------+-----------+--------------------------+------------+
| volume node  | volume-node  | 10.0.0.8  | volume-node.example.org  | 172.16.0.8 |
+--------------+--------------+-----------+--------------------------+------------+
| compute-1    | compute-1    | 10.0.0.20 |                          |            |
+--------------+--------------+-----------+--------------------------+------------+
| compute-2    | compute-2    | 10.0.0.21 |                          |            |
+--------------+--------------+-----------+--------------------------+------------+

Both private and public hostnames are present in the ``/etc/hosts`` of
the physical machines, in order to allow you to connect to them using
the hostname instead of the IP addresses.

Please note that the network node needs one more network interface
that will be completely managed by the **nova-network** service, and
is thus left unconfigured at the beginning.

On the compute node, moreover, we will need to manually create a
*bridge* which will allow the OpenStack virtual machines to access the
network which connects the two physical nodes.

The *internal KVM network* is only needed because we are using virtual
machines, but on a production environment you are likely to have only
2 network cards for each of the nodes, and 3 on the network node.


..
   Installation:
   -------------

   We will install the following services in sequence, on different
   virtual machines.

   * ``all nodes installation``: Common tasks for all the nodes
   * ``db-node``: MySQL + RabbitMQ,
   * ``auth-node``: keystone,
   * ``image-node``: glance,
   * ``api-node``: nova-api, nova-scheduler,
   * ``network-node``: nova-network,
   * ``volume-node``: cinder,
   * ``compute-1``: nova-compute,
   * ``compute-2``: nova-compute,

