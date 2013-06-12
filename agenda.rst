Agenda for the OpenStack Training
=================================

Availables computers
--------------------

+----+-------------------------+-------+------+-------+
|nr. | cpu model               | cores | ram  | disk  |
+----+-------------------------+-------+------+-------+
| 16 |Xeon E5345 CPU @ 2.33GHz | 8     | 16GB | 250GB |
+----+-------------------------+-------+------+-------+

Teams
-----

Either:

a) 8 teams of 2 people, each one with 2 nodes
b) 16 "teams" of 1 people, each one with just 1 node.

Networking
----------

The following networks are defined:

| name       | range        | goal                                  |
+------------+--------------+---------------------------------------+
| GS-Private |              | physical nodes interconnection        |
| GS-Public  |              | used to connect to the physical nodes |
| OS-Private | 10.0.0.0/16  | OS services internal network          |
| OS-Public  |              | OS public endpoint and floating IPs   |

Ask to Pavel:

* is there a way to create a L2-separation among the nodes dedicated
  to different teams? Can we just use crossover cables for the
  GS-Private (and thus OS-Private) network ?
* Can you give us in advance the IP addresses of the GS-Public/Private networks?

TODO: Create a diagram of the network

Setup (8 teams of 2 people)
---------------------------

* 1 node will run 8 VM with the central servers:
  - mysql + rabbitmq
  - keystone
  - glance
  - nova-api + horizon
  - nova-network
  - cinder

* 1 node as compute node (bare metal) will run 2 VM
  - nova-compute
  - nova-compute

Each physical machine will have an IP address also on the same network
used for the VMs, so that from the physical node you can ssh on the
VMs.

Preconfiguration:

1) Setup /etc/hosts on all the machines::

   192.168.1.1    db-node      (mysql+rabbitmq)
   192.168.1.2    auth-node    (keystone)
   192.168.1.3    image-node   (glance)
   192.168.1.4    api-node     (nova-api + horizon)
   192.168.1.5    network-node (nova-network)
   192.168.1.6    volume-node  (cinder)
   192.168.1.11   compute-1    (nova-compute)
   192.168.1.12   compute-2    (nova-compute
   192.168.1.21   physical-node-1
   192.168.1.22   physical-node-2

2) KVM machines with Ubuntu 12.04 LTS

The teams will use virt-manager to connect to the VMs running on the
physical nodes.



Agenda
------

* Presentation of the course, material, teams. (AM)

* "the big picture" (JCF)
  a tell of a VM: what happen when you decide to start a VM on
  OpenStack: describe all the services and how they interact by
  telling what happen when you start a vm.

* mysql + rabbitmq installation
* keystone installation
* glance installation
* nova-api + horizon installation
* nova-network installation
* cinder installation
* nova-compute installation
* test!

