GridKa School 2013 - Training Session on OpenStack
==================================================

.. class:: small

   This tutorial is licensed ©2013, licensed under a `Creative
   Commons Attribution/Share-Alike (BY-SA) license
   <http://creativecommons.org/licenses/by-sa/3.0/>`__.


Teachers:

* `Antonio Messina <antonio.s.messina@gmail.com>`_
* `Tyanko Aleksiev <tyanko.alexiev@gmail.com>`_
* `Jens-Christian Fischer <jens-christian.fischer@switch.ch>`_

This guide is to be used as reference for the installation of
OpenStack `Grizzly` during the: `GridKa School 2013 - Training Session
on OpenStack`.

Goal of the tutorial is to end up with a small installation of
OpenStack Grizzly on a set of different Ubuntu 12.04 virtual
machines.

Since our focus is to explain the most basic components of OpenStack
to ease a later deployment on a production environment, the various
services will be installed on different machines, that is the most
common setup on production. Moreover, having different services on
different machines will help to better understand the dependencies
among the various services.

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

* ``network-node``: runs the network services:
  *nova-network* and nova-metadata* (not Neutron/Quantum)

* ``volume-node``: runs **cinder**, the volume manager, composed of
  the *cinder-api*, *cinder-scheduler* and *cinder-volume* services

while the other will run 2 VMs hosting the **compute nodes** for your
stack:

* ``compute-1``: runs *nova-compute*
* ``compute-2``: runs *nova-compute*

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
| team 01 | gks-125          | gks-126       |
+---------+------------------+---------------+
| team 02 | gks-127          | gks-128       |
+---------+------------------+---------------+
| team 03 | gks-129          | gks-130       |
+---------+------------------+---------------+
| team 04 | gks-131          | gks-132       |
+---------+------------------+---------------+
| team 05 | gks-137          | gks-138       |
+---------+------------------+---------------+
| team 06 | gks-140          | gks-141       |
+---------+------------------+---------------+
| team 07 | gks-142          | gks-143       |
+---------+------------------+---------------+
| team 08 | gks-242          | gks-243       |
+---------+------------------+---------------+
| team 09 | gks-244          | gks-245       |
+---------+------------------+---------------+
| team 10 | gks-246          | gks-247       |
+---------+------------------+---------------+


Virtual Machines
++++++++++++++++

The physical nodes already have the KVM virtual machines we will use
for the tutorial. These are Ubuntu 12.04 LTS machines with very basic
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

Access the Virtual Machines
~~~~~~~~~~~~~~~~~~~~~~~~~~~

You can connect to them from each one of the physical machines (the
**gks-NNN** ones) using **ssh** or by starting the ``virt-manager``
program on the physical node hosting the virtual machine and then
connecting to the console.

In order to connect using **ssh** please do::

     ssh root@hostname 

where **hostname** is one of those listed above. All the Virtual
Machines have the same password: **user@gridka**

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



OpenStack overview
------------------

This tutorial will show how to install the main components of
OpenStack, specifically:

.. image:: ../images/openstack-conceptual-arch.small.png


MySQL
    MySQL database is used together with the RabbitMQ messaging system
    for storing and sharing information about the status of the
    cloud. Alternatively the PostgreSQL software can be also used as
    database backend. We will use default one: MySQL.

RabbitMQ
    Messaging service used for inter-process communication among
    various OpenStack components. Alternatives to RabbitMQ are the
    Qpid and ZeroMQ softwares, in this tutorial we will again use the
    default one: RabbitMQ.

Keystone
    OpenStack service which provides the authentication service and
    works as a catalog of the various services available on the
    cloud. Different backends can be used: in our setup we will store
    login, password and tokens in a MySQL db. 

nova
    OpenStack *orchestrator*: it works as a main API endpoint for
    Horizon and for command line tools, schedule the requests,
    talks to the other OpenStack components to provide the requested
    resources, setup and run the OpenStack instances. It is thus 
    composed of multiple services: **nova-api**, **nova-scheduler**,
    **nova-conductor**, **nova-cert**, ect.

nova-network
    OpenStack service used to configure the network of the instances
    and to optionally provide the so-called *Floating IPs*. IPs that
    can be *attached* and *detached* from an instance while it is
    already running. Those IPs are usually used for accessing the
    instances from outside world.

nova-compute
    OpenStack service which runs on the compute node and is
    responsible of actual managing the OpenStack instances. It 
    supports different hypervisors. The complete list bellow can be found `here
    <http://docs.openstack.org/trunk/openstack-compute/admin/content/selecting-a-hypervisor.html>`_.
    The commonly used one is KVM but due to limitation in our setup we
    will use qemu.

glance
    OpenStack imaging service. It is used to store virtual disks
    used to start the instances. It is split in two different
    services: **glance-api** and **glance-registry**

cinder
    OpenStack volume service. It is used to create persistent volumes which
    can be attached to a running instances later on. It is split
    in three different services: **cinder-api**, **cinder-scheduler**
    and **cinder-volume**

Horizon
    OpenStack Web Interface.


``db-node``
-----------

OpenStack components use both MySQL and RabbitMQ to share information
about the current status of the cloud and to communicate to each
other. Since the architecture is higly distributed, a request done on
an API service (for instance, to start a virtual instance), will
trigger a series of tasks possible executed by different services on
different machines. The server that receive the requests then write on
the database some information related to the request and communicate
with the other services via RabbitMQ.

cloud repository and ntp package
++++++++++++++++++++++++++++++++

The following steps need to be done on all the machines. We are going
execute them step by step on the **db-node** only, and then we will automate
the process on the other nodes. Please login to the db-node and:

Connect to the **db-node**::

    root@gks-NNN:[~] $ ssh root@db-node

Add the OpenStack Grizzly repository::

    root@db-nodes:# apt-get install -y ubuntu-cloud-keyring
    root@db-nodes:# echo deb http://ubuntu-cloud.archive.canonical.com/ubuntu precise-updates/grizzly main > /etc/apt/sources.list.d/grizzly.list

Update the system (can take a while...)::
 
    root@db-nodes:# apt-get update -y
    root@db-nodes:# aptitude upgrade -y

Install the NTP service::

    root@db-nodes:# apt-get install -y ntp


all nodes installation
~~~~~~~~~~~~~~~~~~~~~~

Since those boring steps have to be completed on all the other nodes, we
can run the following script in order to automate this process. This way
the rest of the VMs will have all those steps already done by the time we are
going to work on them. The following command has to run on the **physical machine**::

    root@gks-NNN:[~] $ for host in auth-node image-node api-node \
        network-node volume-node compute-1 compute-2
    do
    ssh -n root@$host "(apt-get install -y ubuntu-cloud-keyring; echo deb http://ubuntu-cloud.archive.canonical.com/ubuntu precise-updates/grizzly main > /etc/apt/sources.list.d/grizzly.list; apt-get update -y; apt-get upgrade -y; apt-get install -y ntp) >& /dev/null &"
    done


MySQL installation
++++++++++++++++++

We are going to install both MySQL and RabbitMQ on the same server,
but on a production environment you may want to have them installed on
different servers and/or in HA. The following instructions are
intended to be used for both scenarios.

Now please move on the db-node where we have to install the MySQL server.
In order to do that please execute::

    root@db-node # apt-get install mysql-server python-mysqldb

you will be prompted for a password, it is safe to specify a good one,
since the MySQL server will be accessible also via internet, so please
pick a password and remember it (e.g. "mysql").

For security reasons the MySQL daemon listens on localhost only,
port 3306. This has to be changed in order to make the server
accessible from the all the OpenStack services. Edit the
``/etc/mysql/my.cnf`` file and ensure that it contains the following line::

    bind-address            = 10.0.0.3

This will make the MySQL daemon listen only on the *private*
interface. Please note that in this way you will not be able to
contact it using the *public* interface (172.16.0.3), which is usually
what you want in a production environment.

After changing this line you have to restart the MySQL server::

    root@db-node # service mysql restart

Check that MySQL is actually running and listening on all the interfaces
using the ``netstat`` command::

    root@db-node:~# netstat -nlp|grep 3306
    tcp        0     10 0.0.0.3:3306            0.0.0.0:*               LISTEN      21926/mysqld    


RabbitMQ
++++++++

RabbitMQ is an implementation of the AMQP (Advanced Message Queuing
Protocol), a networking protocol that enables conforming client
applications to communicate with conforming messaging middleware
brokers.

Install RabbitMQ from the ubuntu repository::

    root@db-node:~# apt-get install -y rabbitmq-server
        
RabbitMQ does not need any specific configuration. On a production
environment, however, you might need to create a specific user for
OpenStack services; in order to do that please check the `RabbitMQ official
documentation <http://www.rabbitmq.com/documentation.html>`_.

To check if the RabbitMQ server is running use the ``rabbitmqctl``
command::

    root@db-node:~# rabbitmqctl status
    Status of node 'rabbit@db-node' ...
    [{pid,22806},
     {running_applications,[{rabbit,"RabbitMQ","2.7.1"},
                            {mnesia,"MNESIA  CXC 138 12","4.5"},
                            {os_mon,"CPO  CXC 138 46","2.2.7"},
                            {sasl,"SASL  CXC 138 11","2.1.10"},
                            {stdlib,"ERTS  CXC 138 10","1.17.5"},
                            {kernel,"ERTS  CXC 138 10","2.14.5"}]},
     {os,{unix,linux}},
     {erlang_version,"Erlang R14B04 (erts-5.8.5) [source] [64-bit] [rq:1] [async-threads:30] [kernel-poll:true]\n"},
     {memory,[{total,24098760},
              {processes,9740136},
              {processes_used,9735768},
              {system,14358624},
              {atom,1124433},
              {atom_used,1120213},
              {binary,103368},
              {code,11134393},
              {ets,708784}]},
     {vm_memory_high_watermark,0.39999999980957235},
     {vm_memory_limit,840214118}]
    ...done.

Please keep the connection to the db-node open as we will need to
operate on it briefly.


``auth-node``
-------------

The **auth-node** will run *keystone*, also known *identity service*.

Keystone performs two main tasks:

* stores information about Authentication and Authorizations (*users*,
  *passwords*, *authorization tokens*, *projects* (also known as
  *tenants*) and *roles*
* stores information about available *services* and the URI of the
  *endpoints*.

Every OpenStack client and service need to access keystone, first to
discover other services, and then to authenticate and authorize each
request. It is thus the main endpoint of an OpenStack installation, so
that by giving the URL of the keystone service a client can get all
the information it needs to operate on that specific cloud.

Before starting we can quickly check if the remote ssh execution of
the commands done in the `all nodes installation`_ section worked
without problems::

    root@auth-node:~# dpkg -l ntp
    Desired=Unknown/Install/Remove/Purge/Hold
    | Status=Not/Inst/Conf-files/Unpacked/halF-conf/Half-inst/trig-aWait/Trig-pend
    |/ Err?=(none)/Reinst-required (Status,Err: uppercase=bad)
    ||/ Name                          Version                       Description
    +++-=============================-=============================-==========================================================================
    ii  ntp                           1:4.2.6.p3+dfsg-1ubuntu3.1    Network Time Protocol daemon and utility programs

which confirmed ntp is installed as required.

Keystone
++++++++

On the **db-node** you need to create a database and a pair of user
and password for the keystone service::

    root@db-node:~# mysql -u root -p
    mysql> CREATE DATABASE keystone;
    mysql> GRANT ALL ON keystone.* TO 'keystoneUser'@'%' IDENTIFIED BY 'keystonePass';

Please note that almost every OpenStack service will need a private
database, which means that we are going to run commands similar to the
previous one a lot of times.

Go to the **auth-node** and install the keystone package::

    root@auth-node:~# apt-get install keystone python-mysqldb -y
        
Update the value of the ``connection`` option in the
``/etc/keystone/keystone.conf`` file, in order to match the hostname,
database name, user and password you've just created. The syntax of this
option is::

    connection = <protocol>://<user>:<password>@<host>/<db_name>

so in our case you need to replace the default option with::

    connection = mysql://keystoneUser:keystonePass@10.0.0.3/keystone

Now you are ready to bootstrap the keystone database using the
following command::

    root@auth-node:~# keystone-manage db_sync

Restart of the keystone service is again required::

    root@auth-node:~# service keystone restart


Note on keystone authentication
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

In order to create users, projects or roles in keystone you need to
access it using an administrative user (which is not automatically
created at the beginning), or you can also use the "*admin token*", a
shared secret that is stored in the keystone configuration file and
can be used to create the initial administrator password.

The default admin token is ``ADMIN``, but you can (and you **should**,
in a production environment) update it by changing the ``admin_token``
option in the ``/etc/keystone/keystone.conf`` file.

Keystone listens on two different ports, one (5000) is for public access,
while the other (35357) is for administrative access. You will usually access
the public one but when using the admin token you can only use the
administrative one.

To specify the admin token and endpoint (or user, password and
endpoint) you can either use the keystone command line options or set
some environment variables. Please note that this behavior is common
to all OpenStack command line tools, although the syntax and the
command line options may change.

In our case, since we don't have an admin user yet and we need to use
the admin token, we will set the following environment variables::

    root@auth-node:~# export SERVICE_TOKEN=ADMIN
    root@auth-node:~# export SERVICE_ENDPOINT=http://auth-node.example.org:35357/v2.0


Creation of the admin user
~~~~~~~~~~~~~~~~~~~~~~~~~~

In order to work with keystone we have to create an admin user and
a few basic projects and roles.

Please note that we will sometimes use the word ``tenant`` instead of
``project``, since the latter is actually the new name of the former,
and while the web interface uses ``project`` most of the commands
still use ``tenant``.

We will now create two tenants: **admin** and **service**. The first
one is used for the admin user, while the second one is used for the
users we will create for the various services (image, volume, nova
etc...). The following commands will work assuming you already set the
correct environment variables::

    root@auth-node:~# keystone tenant-create --name=admin
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |                                  |
    |   enabled   |               True               |
    |      id     | 1ce38185a0c941f1b09605c7bfb15a31 |
    |     name    |              admin               |
    +-------------+----------------------------------+

    root@auth-node:~# keystone tenant-create --name=service
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |                                  |
    |   enabled   |               True               |
    |      id     | cb0e475306cc4c91b2a43b537b1a848b |
    |     name    |             service              |
    +-------------+----------------------------------+

Create the **admin** user::

    root@auth-node:~# keystone user-create --name=admin --pass=keystoneAdmin
    +----------+----------------------------------+
    | Property |              Value               |
    +----------+----------------------------------+
    |  email   |                                  |
    | enabled  |               True               |
    |    id    | 9e8ec4fa52004fd2afa121e2eb0d15b0 |
    |   name   |              admin               |
    | tenantId |                                  |
    +----------+----------------------------------+

Go on by creating the different roles::

    root@auth-node:~# keystone role-create --name=admin
    +----------+----------------------------------+
    | Property |              Value               |
    +----------+----------------------------------+
    |    id    | fafa8117d1564d8c9ec4fe6dbf985c68 |
    |   name   |              admin               |
    +----------+----------------------------------+
    root@auth-node:~# keystone role-create --name=KeystoneAdmin
    +----------+----------------------------------+
    | Property |              Value               |
    +----------+----------------------------------+
    |    id    | a0bf13dda5814865a487c3717ffcd2dc |
    |   name   |          KeystoneAdmin           |
    +----------+----------------------------------+
    root@auth-node:~# keystone role-create --name=KeystoneServiceAdmin
    +----------+----------------------------------+
    | Property |              Value               |
    +----------+----------------------------------+
    |    id    | faf84767d48e466abdc72626ace70e04 |
    |   name   |       KeystoneServiceAdmin       |
    +----------+----------------------------------+
    root@auth-node:~# keystone role-create --name=Member
    +----------+----------------------------------+
    | Property |              Value               |
    +----------+----------------------------------+
    |    id    | 0e0c6303551b4afcbfbc084a9ea917c1 |
    |   name   |              Member              |
    +----------+----------------------------------+

These roles are checked by different services. It is not really easy
to know which service checks for which role, but on a very basic
installation you can just live with ``Member`` (to be used for all the
standard users) and ``admin`` (to be used for the OpenStack
administrators).

Roles are assigned to an user **per-tenant**. However, if you have the
admin role on just one tenant **you actually are the administrator of
the whole OpenStack installation!**

Assign administrative roles to the admin user::

    root@auth-node:~# keystone user-role-add --user admin --role admin --tenant admin
    root@auth-node:~# keystone user-role-add --user admin --role KeystoneAdmin --tenant admin
    root@auth-node:~# keystone user-role-add --user admin --role KeystoneServiceAdmin --tenant admin

Creation of the endpoint
~~~~~~~~~~~~~~~~~~~~~~~~

Keystone is not only used to store information about users, passwords
and projects, but also to store a catalog of the available services
the OpenStack cloud is offering. To each service is then assigned an
*endpoint* which basically consists of a set of three urls (public,
internal, administrative) and a region.

Of course keystone itself is a service ("identity") so it needs its
own service and endpoint.

The "**identity**" service is created with the following command::

    root@auth-node:~# keystone service-create --name keystone --type identity \
        --description 'Keystone Identity Service'
    WARNING: Bypassing authentication using a token & endpoint (authentication credentials are being ignored).
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |    Keystone Identity Service     |
    |      id     | 28b2812e31334d4494a8a434d3e6fc65 |
    |     name    |             keystone             |
    |     type    |             identity             |
    +-------------+----------------------------------+

The output will print the **id** associated with this service. This is
needed by the next command, and is passed as argument of the
``--service-id`` option.

The following command will create an endpoint associated to this
service::

    root@auth-node:~# keystone endpoint-create --region RegionOne \
        --publicurl 'http://auth-node.example.org:5000/v2.0' \
        --adminurl 'http://auth-node.example.org:35357/v2.0' \
        --internalurl 'http://10.0.0.4:5000/v2.0' \
        --service-id 28b2812e31334d4494a8a434d3e6fc65
    WARNING: Bypassing authentication using a token & endpoint (authentication credentials are being ignored).
    +-------------+-----------------------------------------+
    |   Property  |                  Value                  |
    +-------------+-----------------------------------------+
    |   adminurl  | http://auth-node.example.org:35357/v2.0 |
    |      id     |     945edccaa68747698f61bf123228e882    |
    | internalurl |        http://10.0.0.4:5000/v2.0        |
    |  publicurl  |  http://auth-node.example.org:5000/v2.0 |
    |    region   |                RegionOne                |
    |  service_id |     28b2812e31334d4494a8a434d3e6fc65    |
    +-------------+-----------------------------------------+

The argument of the ``--region`` option is the region name. For
simplicity we will always use the name ``RegionOne`` since we are
doing a very simple installation with one availability region only.

To get a listing of the available services the command is::

    root@auth-node:~# keystone service-list
    WARNING: Bypassing authentication using a token & endpoint (authentication credentials are being ignored).
    +----------------------------------+----------+----------+---------------------------+
    |                id                |   name   |   type   |        description        |
    +----------------------------------+----------+----------+---------------------------+
    | 28b2812e31334d4494a8a434d3e6fc65 | keystone | identity | Keystone Identity Service |
    +----------------------------------+----------+----------+---------------------------+

while a list of endpoints is shown by the command::

    root@auth-node:~# keystone endpoint-list
    WARNING: Bypassing authentication using a token & endpoint (authentication credentials are being ignored).
    +----------------------------------+-----------+----------------------------------------+---------------------------+-----------------------------------------+----------------------------------+
    |                id                |   region  |               publicurl                |        internalurl        |                 adminurl                |            service_id            |
    +----------------------------------+-----------+----------------------------------------+---------------------------+-----------------------------------------+----------------------------------+
    | 945edccaa68747698f61bf123228e882 | RegionOne | http://auth-node.example.org:5000/v2.0 | http://10.0.0.4:5000/v2.0 | http://auth-node.example.org:35357/v2.0 | 28b2812e31334d4494a8a434d3e6fc65 |
    +----------------------------------+-----------+----------------------------------------+---------------------------+-----------------------------------------+----------------------------------+

From now on, you can access keystone using the admin user either by
using the following command line options::

    root@any-host:~# keystone --os-user admin --os-tenant-name admin \
                    --os-password keystoneAdmin --os-auth-url http://auth-node.example.org:5000/v2.0 \
                    <subcommand> 

or by setting the following environment variables and run keystone
without the previous options::

    root@any-host:~# export OS_USERNAME=admin
    root@any-host:~# export OS_PASSWORD=keystoneAdmin
    root@any-host:~# export OS_TENANT_NAME=admin
    root@any-host:~# export OS_AUTH_URL=http://auth-node.example.org:5000/v2.0
    
If you are going to use the last option it is usually a good practice
to insert those environment variables in the root's .bashrc file so
that they are loaded each time you open a new shell.

Please keep the connection to the auth-node open as we will need to
operate on it briefly.

Further information about the keystone service can be found at in the
`official documentation <http://docs.openstack.org/grizzly/openstack-compute/install/apt/content/ch_installing-openstack-identity-service.html>`_

``image-node``
--------------

As we did for the auth node before staring it is good to quickly check if the
remote ssh execution of the commands done in the `all nodes installation`_ section 
worked without problems. You can again verify it by checking the ntp installation.

Glance
++++++

**Glance** is the name of the image service of OpenStack. It is
responsible for storing the images that will be used as templates to
start the instances. We will use the default configuration and
only do the minimal changes to match our configuration.

Glance is actually composed of two different services:

* **glance-api** accepts API calls for dicovering the available
  images, their metadata and is used also to retrieve them. It
  supports two protocol versions: v1 and v2; when using v1, it does
  not directly access the database but instead it talks to the
  **glance-registry** service

* **glance-registry** used by **glance-api** to actually retrieve image
  metadata when using the old v1 protocol.

Very good explanation about what glance does is available on `this
blogpost <http://bcwaldon.cc/2012/11/06/openstack-image-service-grizzly.html>`_

glance database and keystone setup
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Similarly to what we did for the keystone service, also for the glance
service we need to create a database and a pair of user and password
for it.

On the **db-node** create the database and the MySQL user::

    root@db-node:~# mysql -u root -p
    mysql> CREATE DATABASE glance;
    mysql> GRANT ALL ON glance.* TO 'glanceUser'@'%' IDENTIFIED BY 'glancePass';

On the **auth-node** instead we need to create an **image** service
and an endpoint associated with it. The following commands assume you
already set the environment variables needed to run keystone without
specifying login, password and endpoint all the times.

First of all, we need to get the **id** of the **service** tenant::

    root@auth-node:~# keystone tenant-get service
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |                                  |
    |   enabled   |               True               |
    |      id     | cb0e475306cc4c91b2a43b537b1a848b |
    |     name    |             service              |
    +-------------+----------------------------------+

then we need to create a keystone user for the glance service,
associated with the **service** tenant::

    root@auth-node:~# keystone user-create --name=glance --pass=glanceServ \
      --tenant-id cb0e475306cc4c91b2a43b537b1a848b
    +----------+----------------------------------+
    | Property |              Value               |
    +----------+----------------------------------+
    |  email   |                                  |
    | enabled  |               True               |
    |    id    | c938866a0a3c4266a25dc95fbfcc6718 |
    |   name   |              glance              |
    | tenantId | cb0e475306cc4c91b2a43b537b1a848b |
    +----------+----------------------------------+

..
   FIXME: is this really needed??? Yes! Otherwise, you will get::

       root@image-node:~# glance image-list
       Request returned failure status.
       Invalid OpenStack Identity credentials.

   and in the keystone.log file::

       2013-08-16 16:34:19  WARNING [keystone.common.wsgi] Authorization failed. The request you have made requires authentication. from 10.0.0.5

Then we need to give admin permissions to it::

    root@auth-node:~# keystone user-role-add --tenant service --user glance --role admin

Please note that we could have created only one user for all the services, 
but this is a cleaner solution.

We need then to create the **image** service::

    root@auth-node:~# keystone service-create --name glance --type image \
      --description 'Glance Image Service'
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |       Glance Image Service       |
    |      id     | 6cb0cf7a81bc4489a344858398d40222 |
    |     name    |              glance              |
    |     type    |              image               |
    +-------------+----------------------------------+

and the related endpoint::

    root@auth-node:~# keystone endpoint-create --region RegionOne \
        --publicurl 'http://image-node.example.org:9292/v2' \
        --adminurl 'http://image-node.example.org:9292/v2' \
        --internalurl 'http://10.0.0.5:9292/v2' \
        --service-id 6cb0cf7a81bc4489a344858398d40222
    +-------------+---------------------------------------+
    |   Property  |                 Value                 |
    +-------------+---------------------------------------+
    |   adminurl  | http://image-node.example.org:9292/v2 |
    |      id     |    e1080682380d4f90bfa7016916c40d91   |
    | internalurl |        http://10.0.0.5:9292/v2        |
    |  publicurl  | http://image-node.example.org:9292/v2 |
    |    region   |               RegionOne               |
    |  service_id |    6cb0cf7a81bc4489a344858398d40222   |
    +-------------+---------------------------------------+

glance installation and configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

On the **image-node** install the **glance** package::

    root@image-node:~# apt-get install glance python-mysqldb

To configure the glance service we need to edit a few files in ``/etc/glance``:

In the ``/etc/glance/glance-api-paste.ini`` file, we need to adjust
the **filter:authtoken** section so that it matches the values we used
when we created the keystone **glance** user::

    [filter:authtoken]
    paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
    delay_auth_decision = true
    auth_host = 10.0.0.4
    auth_port = 35357
    auth_protocol = http
    admin_tenant_name = service
    admin_user = glance
    admin_password = glanceServ

Similar changes have to be done on the ``/etc/glance/glance-registry-paste.ini`` file::

    [filter:authtoken]
    paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
    auth_host = 10.0.0.4
    auth_port = 35357
    auth_protocol = http
    admin_tenant_name = service
    admin_user = glance
    admin_password = glanceServ

.. Very interesting: we misspelled the password here, but we only get
   errors when getting the list of VM from horizon. Booting VM from
   nova actually worked!!! 
   
   Found the following explanation here: http://bcwaldon.cc/
   
   glance-registry vs glance-api
   The v1 and v2 Images APIs were implemented with seperate paths to
   the Glance database. The first of which proxies queries through a subsequent
   HTTP service (glance-registry) while the second talks directly to the database. 
   As these two APIs should be talking to an equivalent system, we will be realigning
   their internal paths to talk through the service layer (created with the domain object model)
   directly to the database, effectively deprecating the glance-registry service.


Information on how to connect to the MySQL database are stored in the
``/etc/glance/glance-api.conf`` file. The syntax is similar to the one
used in the ``/etc/keystone/keystone.conf`` file,  but the name of the
option is ``sql_connection`` instead::

    sql_connection = mysql://glanceUser:glancePass@10.0.0.3/glance

On this file, we also need to specify the RabbitMQ host (default is
``localhost``). The other rabbit parameters should be fine::

    rabbit_host = 10.0.0.3

Finally, we need to specify which paste pipeline we are using. We are not
entering into details here, just check that the following option is present::

    [paste_deploy]
    flavor = keystone

Similar changes need to be done in the
``/etc/glance/glance-registry.conf``, both for the MySQL connection::

    sql_connection = mysql://glanceUser:glancePass@10.0.0.3/glance

and for the paste pipeline::

    [paste_deploy]
    flavor = keystone

Like we did with keystone, we need to populate the glance database::

    root@image-node:~# glance-manage db_sync

Now we are ready to restart the glance services::

    root@image-node:~# service glance-api restart
    root@image-node:~# service glance-registry restart

As we did for keystone, we can set environment variables in order to
access glance::

    root@image-node:~# export OS_USERNAME=admin
    root@image-node:~# export OS_PASSWORD=keystoneAdmin
    root@image-node:~# export OS_TENANT_NAME=admin
    root@image-node:~# export OS_AUTH_URL=http://auth-node.example.org:5000/v2.0

Testing glance
~~~~~~~~~~~~~~

First of all, let's download a very small test image::

    root@image-node:~# wget https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img

The command line tool to manage images is ``glance``. Uploading an image is easy::

    root@image-node:~# glance image-create --name cirros-0.3.0 --is-public=true \
      --container-format=bare --disk-format=qcow2 --file cirros-0.3.0-x86_64-disk.img 
    +------------------+--------------------------------------+
    | Property         | Value                                |
    +------------------+--------------------------------------+
    | checksum         | 50bdc35edb03a38d91b1b071afb20a3c     |
    | container_format | bare                                 |
    | created_at       | 2013-08-16T14:38:12                  |
    | deleted          | False                                |
    | deleted_at       | None                                 |
    | disk_format      | qcow2                                |
    | id               | 79af6953-6bde-463d-8c02-f10aca227ef4 |
    | is_public        | True                                 |
    | min_disk         | 0                                    |
    | min_ram          | 0                                    |
    | name             | cirros-0.3.0                         |
    | owner            | 1ce38185a0c941f1b09605c7bfb15a31     |
    | protected        | False                                |
    | size             | 9761280                              |
    | status           | active                               |
    | updated_at       | 2013-08-16T14:38:12                  |
    +------------------+--------------------------------------+

Using ``glance`` command you can also list the images currently
uploaded on the image store::

    root@image-node:~# glance image-list
    +--------------------------------------+--------------+-------------+------------------+---------+--------+
    | ID                                   | Name         | Disk Format | Container Format | Size    | Status |
    +--------------------------------------+--------------+-------------+------------------+---------+--------+
    | 79af6953-6bde-463d-8c02-f10aca227ef4 | cirros-0.3.0 | qcow2       | bare             | 9761280 | active |
    +--------------------------------------+--------------+-------------+------------------+---------+--------+

You can easily find ready-to-use images on the web. An image for the
`Ubuntu Server 12.04 "Precise" (amd64)
<http://cloud-images.ubuntu.com/precise/current/precise-server-cloudimg-amd64-disk1.img>`_
can be found at the `Ubuntu Cloud Images archive
<http://cloud-images.ubuntu.com/>`_, you can download it and upload
using glance as we did before.

Further improvements
~~~~~~~~~~~~~~~~~~~~

By default glance will store all the images as files in
``/var/lib/glance/images``, but other options are available. You can
store the images on a s3 or swift object storage, for instance, or on
a RDB (gluster) storage. This is changed by the option
``default_store`` in the ``/etc/glance/glance-api.conf`` configuration
file, and depending on the type of store you will have various other
options, like the path for the *filesystem* store, or the access and
secret keys for the s3 store, or rdb configuration options.

Please refer to the official documentation to change these values.

The cirros image we uploaded before, having an image id of
``79af6953-6bde-463d-8c02-f10aca227ef4``, will be found in::

    root@image-node:~# ls -l /var/lib/glance/images/79af6953-6bde-463d-8c02-f10aca227ef4 
    -rw-r----- 1 glance glance 9761280 Aug 16 16:38 /var/lib/glance/images/79af6953-6bde-463d-8c02-f10aca227ef4


``volume-node``
+++++++++++++++

As we did for the image node before staring it is good to quickly check if the
remote ssh execution of the commands done in the `all nodes installation`_ section 
worked without problems. You can again verify it by checking the ntp installation.

Cinder
++++++

**Cinder** is the name of the OpenStack block storage service. It
allows manipulation of volumes, volume types (similar to compute
flavors) and volume snapshots.

Note that a volume may only be attached to one instance at a
time. This is not a *shared storage* solution like a SAN of NFS on
which multiple servers can attach to.

Volumes created by cinder are served via iSCSI to the compute node,
which will provide them to the VM as regular sata disk. These volumes
can be stored on different backends: LVM (the default one), Ceph,
GlusterFS, NFS or various appliances from IBM, NetApp etc.

Cinder is actually composed of different services:

**cinder-api** 

    The cinder-api service is a WSGI app that authenticates and routes
    requests throughout the Block Storage system. It can be used
    directly (via API or via ``cinder`` command line tool) but it is
    also accessed by the ``nova`` service and the horizon web
    interface.

**cinder-scheduler** 

    The cinder-scheduler is responsible for scheduling/routing
    requests to the appropriate volume service. As of Grizzly;
    depending upon your configuration this may be simple round-robin
    scheduling to the running volume services, or it can be more
    sophisticated through the use of the Filter Scheduler. The Filter
    Scheduler is the default in Grizzly and enables filter on things
    like Capacity, Availability Zone, Volume Types and Capabilities as
    well as custom filters.

**cinder-volume** 

    The cinder-volume service is responsible for managing Block
    Storage devices, specifically the back-end devices themselves.

In our setup, we will run all the cinder services on the same machine,
although you can, in principle, spread them over multiple servers.

The **volume-node** has one more disk (``/dev/vdb``) which will use to
create a LVM volume group to store the logical volumes created by cinder.

cinder database and keystone setup
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

As usual, we need to create a database on the **db-node** and an user
in keystone.

On the **db-node** create the database and the MySQL user::

    root@db-node:~# mysql -u root -p
    mysql> CREATE DATABASE cinder;
    mysql> GRANT ALL ON cinder.* TO 'cinderUser'@'%' IDENTIFIED BY 'cinderPass';

On the **auth-node** create a keystone user, a "volume" service and
its endpoint, like we did for the *glance* service. The following
commands assume you already set the environment variables needed to
run keystone without specifying login, password and endpoint all the
times.

First of all, we need to get the **id** of the **service** tenant::

    root@auth-node:~# keystone tenant-get service
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |                                  |
    |   enabled   |               True               |
    |      id     | cb0e475306cc4c91b2a43b537b1a848b |
    |     name    |             service              |
    +-------------+----------------------------------+

then we need to create a keystone user for the cinder service, 
associated with the **service** tenant::

    root@auth-node:~# keystone user-create --name=cinder --pass=cinderServ --tenant-id cb0e475306cc4c91b2a43b537b1a848b
    +----------+----------------------------------+
    | Property |              Value               |
    +----------+----------------------------------+
    |  email   |                                  |
    | enabled  |               True               |
    |    id    | 68b76e9a95674646b09c37d36f13838f |
    |   name   |              cinder              |
    | tenantId | cb0e475306cc4c91b2a43b537b1a848b |
    +----------+----------------------------------+

Then we need to give admin permissions to it::

       root@auth-node:~# keystone user-role-add --tenant service --user cinder --role admin

We need then to create the **volume** service::

    root@auth-node:~# keystone service-create --name cinder --type volume \
      --description 'Volume Service of OpenStack'
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |   Volume Service of OpenStack    |
    |      id     | 2561a51dd7494651862a44e34d637e1e |
    |     name    |              cinder              |
    |     type    |              volume              |
    +-------------+----------------------------------+

and the related endpoint, using the service id we just got::
        
    root@auth-node:~# keystone endpoint-create --region RegionOne \
      --publicurl 'http://volume-node.example.org:8776/v1/$(tenant_id)s' \
      --adminurl 'http://volume-node.example.org:8776/v1/$(tenant_id)s' \
      --internalurl 'http://10.0.0.8:8776/v1/$(tenant_id)s' \
      --service-id 2561a51dd7494651862a44e34d637e1e \

    +-------------+------------------------------------------------------+
    |   Property  |                        Value                         |
    +-------------+------------------------------------------------------+
    |   adminurl  | http://volume-node.example.org:8776/v1/$(tenant_id)s |
    |      id     |           3f77c8eca16e436c86bf1935e1e7d334           |
    | internalurl |        http://10.0.0.8:8776/v1/$(tenant_id)s         |
    |  publicurl  | http://volume-node.example.org:8776/v1/$(tenant_id)s |
    |    region   |                      RegionOne                       |
    |  service_id |           2561a51dd7494651862a44e34d637e1e           |
    +-------------+------------------------------------------------------+

Please note that the URLs need to be quoted using the (') character
(single quote) otherwise the shell will interpret the dollar sign ($)
present in the url.

We should now have three endpoints on keystone::

    root@auth-node:~# keystone endpoint-list
    +----------------------------------+-----------+------------------------------------------------------+---------------------------------------+------------------------------------------------------+----------------------------------+
    |                id                |   region  |                      publicurl                       |              internalurl              |                       adminurl                       |            service_id            |
    +----------------------------------+-----------+------------------------------------------------------+---------------------------------------+------------------------------------------------------+----------------------------------+
    | 3f77c8eca16e436c86bf1935e1e7d334 | RegionOne | http://volume-node.example.org:8776/v1/$(tenant_id)s | http://10.0.0.8:8776/v1/$(tenant_id)s | http://volume-node.example.org:8776/v1/$(tenant_id)s | 2561a51dd7494651862a44e34d637e1e |
    | 945edccaa68747698f61bf123228e882 | RegionOne |        http://auth-node.example.org:5000/v2.0        |       http://10.0.0.4:5000/v2.0       |       http://auth-node.example.org:35357/v2.0        | 28b2812e31334d4494a8a434d3e6fc65 |
    | e1080682380d4f90bfa7016916c40d91 | RegionOne |        http://image-node.example.org:9292/v2         |        http://10.0.0.5:9292/v2        |        http://image-node.example.org:9292/v2         | 6cb0cf7a81bc4489a344858398d40222 |
    +----------------------------------+-----------+------------------------------------------------------+---------------------------------------+------------------------------------------------------+----------------------------------+


basic configuration
~~~~~~~~~~~~~~~~~~~

Let's now go back to the  **volume-node** and install the cinder
packages::

    root@volume-node:~# apt-get install -y cinder-api cinder-scheduler cinder-volume \
      open-iscsi python-mysqldb  python-cinderclient

Ensure that the iscsi services are running::

    root@volume-node:~# service open-iscsi start

We will configure cinder in order to create volumes using LVM, but in
order to do that we have to provide a volume group called
``cinder-volume`` (you can use a different name, but you have to
update the cinder configuration file).

The **volume-node** machine has one more disk (``/dev/vdb``) which
we will use for LVM. You can either partition this disk and use those
partitions to create the volume group, or use the whole disk. In our
setup, to keep things simple, we will use the whole disk, so we are
going to:

Create a physical device on the ``/dev/vdb`` disk::

    root@volume-node:~# pvcreate /dev/vdb
      Physical volume "/dev/vdb" successfully created

create a volume group called **cinder-volume** on it::

    root@volume-node:~# vgcreate cinder-volumes /dev/vdb
      Volume group "cinder-volume" successfully created

check that the volume group has been created::

    root@volume-node:~# vgdisplay
      --- Volume group ---
      VG Name               cinder-volumes
      System ID             
      Format                lvm2
      Metadata Areas        1
      Metadata Sequence No  1
      VG Access             read/write
      VG Status             resizable
      MAX LV                0
      Cur LV                0
      Open LV               0
      Max PV                0
      Cur PV                1
      Act PV                1
      VG Size               1.95 GiB
      PE Size               4.00 MiB
      Total PE              499
      Alloc PE / Size       0 / 0   
      Free  PE / Size       499 / 1.95 GiB
      VG UUID               NGrgtl-thWL-4icP-r42k-vLnk-PjDV-mHmEkR

cinder configuration
~~~~~~~~~~~~~~~~~~~~

In file ``/etc/cinder/api-paste.ini`` edit the **filter:authtoken**
section and ensure that information about the keystone user and
endpoint are correct, specifically the options ``service_host``,
``admin_tenant_name``, ``admin_user`` and ``admin_password``::

    [filter:authtoken]
    paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
    service_protocol = http
    service_host = 10.0.0.4
    service_port = 5000
    auth_host = 10.0.0.4
    auth_port = 35357
    auth_protocol = http
    admin_tenant_name = service
    admin_user = cinder
    admin_password = cinderServ
    signing_dir = /var/lib/cinder

The  ``/etc/cinder/cinder.conf`` file contains instead information
about the MySQL and RabbitMQ host, and information about the iscsi and
LVM configuration. A minimal configuration file will contain::

    [DEFAULT]
    rootwrap_config=/etc/cinder/rootwrap.conf
    api_paste_config = /etc/cinder/api-paste.ini
    iscsi_helper=tgtadm
    volume_name_template = volume-%s
    volume_group = cinder-volumes
    verbose = True
    auth_strategy = keystone
    state_path = /var/lib/cinder
    lock_path = /var/lock/cinder
    volumes_dir = /var/lib/cinder/volumes
    sql_connection = mysql://cinderUser:cinderPass@10.0.0.3/cinder
    rabbit_host=10.0.0.3
    iscsi_ip_address=10.0.0.8

.. iscsi_ip_address is needed otherwise, in our case, it will try to
   connect using 192.168. network which is not reachable from the
   OpenStack VMs.

it should differ from the standard one only for the options
``sql_connection``, ``rabbit_host``, ``iscsi_ip_address`` and
``iscsi_helper``.

Populate the cinder database::

    root@volume-node:~# cinder-manage db sync

Restart cinder services::

    root@volume-node:~# service cinder-api restart
    cinder-api start/running, process 1625

    root@volume-node:~# service cinder-volume restart
    cinder-volume start/running, process 1636

    root@volume-node:~# service cinder-scheduler restart
    cinder-scheduler start/running, process 1655

            
Testing cinder
~~~~~~~~~~~~~~

Cinder command line tool also allow you to pass user, password, tenant
name and authentication URL both via command line options or
environment variables. In order to make the commands easier to read we
are going to set the environment variables and run cinder without
options::

    root@volume-node:~# export OS_USERNAME=admin
    root@volume-node:~# export OS_PASSWORD=keystoneAdmin
    root@volume-node:~# export OS_TENANT_NAME=admin
    root@volume-node:~# export OS_AUTH_URL=http://auth-node.example.org:5000/v2.0

Test cinder by creating a volume::

    root@volume-node:~# cinder create --display-name test 1
    +---------------------+--------------------------------------+
    |       Property      |                Value                 |
    +---------------------+--------------------------------------+
    |     attachments     |                  []                  |
    |  availability_zone  |                 nova                 |
    |       bootable      |                false                 |
    |      created_at     |      2013-08-15T11:48:13.409780      |
    | display_description |                 None                 |
    |     display_name    |                 test                 |
    |          id         | 1d1a75eb-1493-4fda-8eba-fa851cfd5040 |
    |       metadata      |                  {}                  |
    |         size        |                  1                   |
    |     snapshot_id     |                 None                 |
    |     source_volid    |                 None                 |
    |        status       |               creating               |
    |     volume_type     |                 None                 |
    +---------------------+--------------------------------------+

Shortly after, a ``cinder list`` command should show you the newly
created volume::

    root@volume-node:~# cinder list
    +--------------------------------------+-----------+--------------+------+-------------+----------+-------------+
    |                  ID                  |   Status  | Display Name | Size | Volume Type | Bootable | Attached to |
    +--------------------------------------+-----------+--------------+------+-------------+----------+-------------+
    | 1d1a75eb-1493-4fda-8eba-fa851cfd5040 | available |     test     |  1   |     None    |  false   |             |
    +--------------------------------------+-----------+--------------+------+-------------+----------+-------------+

You can easily check that a new LVM volume has been created::

    root@volume-node:~# lvdisplay 
      --- Logical volume ---
      LV Name                /dev/cinder-volume/volume-1d1a75eb-1493-4fda-8eba-fa851cfd5040
      VG Name                cinder-volume
      LV UUID                RRGmob-jMZC-4Mdm-kTBv-Qc6M-xVsC-gEGhOg
      LV Write Access        read/write
      LV Status              available
      # open                 1
      LV Size                1.00 GiB
      Current LE             256
      Segments               1
      Allocation             inherit
      Read ahead sectors     auto
      - currently set to     256
      Block device           252:0

To show if the volume is actually served via iscsi you can run::

   root@volume-node:~# tgtadm  --lld iscsi --op show --mode target
   Target 1: iqn.2010-10.org.openstack:volume-1d1a75eb-1493-4fda-8eba-fa851cfd5040
       System information:
           Driver: iscsi
           State: ready
       I_T nexus information:
       LUN information:
           LUN: 0
               Type: controller
               SCSI ID: IET     00010000
               SCSI SN: beaf10
               Size: 0 MB, Block size: 1
               Online: Yes
               Removable media: No
               Readonly: No
               Backing store type: null
               Backing store path: None
               Backing store flags: 
           LUN: 1
               Type: disk
               SCSI ID: IET     00010001
               SCSI SN: beaf11
               Size: 1074 MB, Block size: 512
               Online: Yes
               Removable media: No
               Readonly: No
               Backing store type: rdwr
               Backing store path: /dev/cinder-volumes/volume-1d1a75eb-1493-4fda-8eba-fa851cfd5040
               Backing store flags: 
       Account information:
       ACL information:
           ALL


Since the volume is not used by any VM, we can delete it with the ``cinder delete`` command::

    root@volume-node:~# cinder delete 1d1a75eb-1493-4fda-8eba-fa851cfd5040

Deleting the volume can take some time::

    root@volume-node:~# cinder list
    +--------------------------------------+----------+--------------+------+-------------+----------+-------------+
    |                  ID                  |  Status  | Display Name | Size | Volume Type | Bootable | Attached to |
    +--------------------------------------+----------+--------------+------+-------------+----------+-------------+
    | 1d1a75eb-1493-4fda-8eba-fa851cfd5040 | deleting |     test     |  1   |     None    |  false   |             |
    +--------------------------------------+----------+--------------+------+-------------+----------+-------------+

After a while the volume is deleted, removed from iscsi and LVM::

    root@volume-node:~# cinder list

    root@volume-node:~# tgtadm  --lld iscsi --op show --mode target
    root@volume-node:~# lvdisplay 
    root@volume-node:~#


``api-node``
------------

As we did for the glance node before staring it is good to quickly check if the
remote ssh execution of the commands done in the `all nodes installation`_ section 
worked without problems. You can again verify it by checking the ntp installation.

Nova
++++

Nova is composed to a variety of services

Now that he have installed a lot of infrastructure, it is time to actually get the 
compute part of our cloud up and running - otherwise, what good would it be?

In this section we are going to install and configure
the OpenStack nova services. 

db and keystone configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

First move to the **db-node** and create the database::

    root@db-node:~# mysql -u root -p
    
    mysql> CREATE DATABASE nova;
    mysql> GRANT ALL ON nova.* TO 'novaUser'@'%' IDENTIFIED BY 'novaPass';


As we did before, on the **auth-node** we have to create a pair of
user and password for nova, but in this case we need to create two
different services and endpoints:

compute
    allows you to manage OpenStack instances

ec2
    compatibility layer on top of the nova service, which allows you
    to use the same APIs you would use with Amazon EC2

First of all, we need to get the **id** of the **service** tenant::

    root@auth-node:~# keystone tenant-get service
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |                                  |
    |   enabled   |               True               |
    |      id     | cb0e475306cc4c91b2a43b537b1a848b |
    |     name    |             service              |
    +-------------+----------------------------------+

then we need to create a keystone user for the nova service, 
associated with the **service** tenant::

    root@auth-node:~# keystone user-create --name=nova --pass=novaServ --tenant-id cb0e475306cc4c91b2a43b537b1a848b
    +----------+----------------------------------+
    | Property |              Value               |
    +----------+----------------------------------+
    |  email   |                                  |
    | enabled  |               True               |
    |    id    | 813c0bb78ddd41d48b129787443b895a |
    |   name   |               nova               |
    | tenantId | cb0e475306cc4c91b2a43b537b1a848b |
    +----------+----------------------------------+

Then we need to give admin permissions to it::
        
    root@auth-node:~# keystone user-role-add --tenant service --user nova --role admin

We need to create first the **compute** service::

    root@auth-node:~# keystone service-create --name nova --type compute \
      --description 'Compute Service of OpenStack'
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |   Compute Service of OpenStack   |
    |      id     | 338d7b7ec7f14622a1fc1a99bd9004bf |
    |     name    |               nova               |
    |     type    |             compute              |
    +-------------+----------------------------------+

and its endpoint::

    root@auth-node:~# keystone endpoint-create --region RegionOne \
      --publicurl 'http://api-node.example.org:8774/v2/$(tenant_id)s' \
      --adminurl 'http://api-node.example.org:8774/v2/$(tenant_id)s' \
      --internalurl 'http://10.0.0.6:8774/v2/$(tenant_id)s' \
      --service-id 338d7b7ec7f14622a1fc1a99bd9004bf
    +-------------+---------------------------------------------------+
    |   Property  |                       Value                       |
    +-------------+---------------------------------------------------+
    |   adminurl  | http://api-node.example.org:8774/v2/$(tenant_id)s |
    |      id     |          50f0260b221a4ea889aa03dc0532d55f         |
    | internalurl |       http://10.0.0.6:8774/v2/$(tenant_id)s       |
    |  publicurl  | http://api-node.example.org:8774/v2/$(tenant_id)s |
    |    region   |                     RegionOne                     |
    |  service_id |          338d7b7ec7f14622a1fc1a99bd9004bf         |
    +-------------+---------------------------------------------------+

then the **ec2** service::

    root@auth-node:~# keystone service-create --name ec2 --type ec2 \
      --description 'EC2 service of OpenStack'
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |     EC2 service of OpenStack     |
    |      id     | a17a1f1d605a4ad58993c6d9a803b2af |
    |     name    |               ec2                |
    |     type    |               ec2                |
    +-------------+----------------------------------+

and its endpoint::

    root@auth-node:~# keystone endpoint-create --region RegionOne \
      --publicurl 'http://api-node.example.org:8773/services/Cloud' \
      --adminurl 'http://api-node.example.org:8773/services/Admin' \
      --internalurl 'http://10.0.0.6:8773/services/Cloud' \
      --service-id a17a1f1d605a4ad58993c6d9a803b2af
    +-------------+-------------------------------------------------+
    |   Property  |                      Value                      |
    +-------------+-------------------------------------------------+
    |   adminurl  | http://api-node.example.org:8773/services/Admin |
    |      id     |         c3194c76b046426eaa2eef73b537298e        |
    | internalurl |       http://10.0.0.6:8773/services/Cloud       |
    |  publicurl  | http://api-node.example.org:8773/services/Cloud |
    |    region   |                    RegionOne                    |
    |  service_id |         a17a1f1d605a4ad58993c6d9a803b2af        |
    +-------------+-------------------------------------------------+

nova installation and configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Now we can continue the installation on the **api-node**::

    root@api-node:~# apt-get install -y nova-api nova-cert novnc \
    nova-consoleauth nova-scheduler nova-novncproxy nova-doc nova-conductor 

The file ``/etc/nova/api-paste.ini`` is similar to what we have seen
for cinder and glance. Check that the **[filter:authtoken]** section
is correct::

    [filter:authtoken]
    paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
    auth_host = 10.0.0.4
    auth_port = 35357
    auth_protocol = http
    admin_tenant_name = service
    admin_user = nova
    admin_password = novaServ
    #signing_dir = /tmp/keystone-signing
    # Workaround for https://bugs.launchpad.net/nova/+bug/1154809
    auth_version = v2.0


The main configuration file for nova is  ``/etc/nova/nova.conf``. It
accepts *a lot* of different options to control the behavior of
OpenStack. However, we are only going to change what is
needed. Complete reference for the ``nova.conf`` file can be found on
the `Openstack Compute Administration Guide`_, section 5: `List of
configuration options <http://docs.openstack.org/trunk/openstack-compute/admin/content/list-of-compute-config-options.html>`_

::

    [DEFAULT]
    dhcpbridge_flagfile=/etc/nova/nova.conf
    dhcpbridge=/usr/bin/nova-dhcpbridge
    logdir=/var/log/nova
    state_path=/var/lib/nova
    lock_path=/var/lock/nova
    force_dhcp_release=True
    iscsi_helper=tgtadm
    libvirt_use_virtio_for_bridges=True
    connection_type=libvirt
    root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf
    verbose=True
    ec2_private_dns_show_ip=True
    api_paste_config=/etc/nova/api-paste.ini
    volumes_path=/var/lib/nova/volumes
    enabled_apis=ec2,osapi_compute,metadata

    # compute_scheduler_driver=nova.scheduler.simple.SimpleScheduler
    rabbit_host=10.0.0.3
    nova_url=http://10.0.0.6:8774/v1.1/
    sql_connection=mysql://novaUser:novaPass@10.0.0.3/nova

    # Auth
    use_deprecated_auth=false
    auth_strategy=keystone

    # Imaging service
    glance_api_servers=10.0.0.5:9292
    image_service=nova.image.glance.GlanceImageService

    # Vnc configuration
    novnc_enabled=true
    novncproxy_base_url=http://10.0.0.6:6080/vnc_auto.html
    novncproxy_port=6080
    vncserver_proxyclient_address=10.0.0.6
    vncserver_listen=0.0.0.0

    # Compute #
    compute_driver=libvirt.LibvirtDriver

    # Cinder #
    volume_api_class=nova.volume.cinder.API
    osapi_volume_listen_port=5900

Sync the nova database::

    root@api-node:~# nova-manage db sync

Restart all the nova services::

    root@api-node:~# service nova-api restart
    nova-api stop/waiting
    nova-api start/running, process 26273

    root@api-node:~# service nova-conductor restart
    nova-conductor stop/waiting
    nova-conductor start/running, process 26296

    root@api-node:~# service nova-scheduler restart
    nova-scheduler stop/waiting
    nova-scheduler start/running, process 26311

    root@api-node:~# service nova-novncproxy restart
    nova-novncproxy stop/waiting
    nova-novncproxy start/running, process 26326

    root@api-node:~# service nova-cert restart
    nova-cert stop/waiting
    nova-cert start/running, process 26376

These service should be in ``:-)`` state when running::

    root@api-node:~# nova-manage service list
    Binary           Host                                 Zone             Status     State Updated_At
    nova-conductor   api-node                             internal         enabled    :-)   2013-08-16 16:18:53
    nova-scheduler   api-node                             internal         enabled    :-)   2013-08-16 16:18:48
    nova-cert        api-node                             internal         enabled    :-)   2013-08-16 16:18:52

Testing nova
~~~~~~~~~~~~

So far we cannot run an instance yet, but we can check if nova
is able to talk to the services already installed. As usual, you can
set the environment variables to use the ``nova`` command line
without having to specify the credentials via command line options::

    root@api-node:~# export OS_USERNAME=admin
    root@api-node:~# export OS_PASSWORD=keystoneAdmin
    root@api-node:~# export OS_TENANT_NAME=admin
    root@api-node:~# export OS_AUTH_URL=http://auth-node.example.org:5000/v2.0

you can check the status of the nova service::

    root@api-node:~# nova service-list
    +----------------+----------+----------+---------+-------+----------------------------+
    | Binary         | Host     | Zone     | Status  | State | Updated_at                 |
    +----------------+----------+----------+---------+-------+----------------------------+
    | nova-cert      | api-node | internal | enabled | up    | 2013-08-16T16:24:14.000000 |
    | nova-conductor | api-node | internal | enabled | up    | 2013-08-16T16:24:15.000000 |
    | nova-scheduler | api-node | internal | enabled | up    | 2013-08-16T16:24:20.000000 |
    +----------------+----------+----------+---------+-------+----------------------------+

but you can also work with glance images::

    root@api-node:~# nova image-list
    +--------------------------------------+--------------+--------+--------+
    | ID                                   | Name         | Status | Server |
    +--------------------------------------+--------------+--------+--------+
    | 79af6953-6bde-463d-8c02-f10aca227ef4 | cirros-0.3.0 | ACTIVE |        |
    +--------------------------------------+--------------+--------+--------+

or create and manage cinder volumes::

    root@api-node:~# nova volume-create --display-name test2 1
    +---------------------+--------------------------------------+
    | Property            | Value                                |
    +---------------------+--------------------------------------+
    | status              | creating                             |
    | display_name        | test2                                |
    | attachments         | []                                   |
    | availability_zone   | nova                                 |
    | bootable            | false                                |
    | created_at          | 2013-08-16T16:26:19.627854           |
    | display_description | None                                 |
    | volume_type         | None                                 |
    | snapshot_id         | None                                 |
    | source_volid        | None                                 |
    | size                | 1                                    |
    | id                  | 180a081a-065b-497e-998d-aa32c7c295cc |
    | metadata            | {}                                   |
    +---------------------+--------------------------------------+
    root@api-node:~# nova volume-list
    +--------------------------------------+-----------+--------------+------+-------------+-------------+
    | ID                                   | Status    | Display Name | Size | Volume Type | Attached to |
    +--------------------------------------+-----------+--------------+------+-------------+-------------+
    | 180a081a-065b-497e-998d-aa32c7c295cc | available | test2        | 1    | None        |             |
    +--------------------------------------+-----------+--------------+------+-------------+-------------+

The ``nova`` command line tool also allow you to run instances, but we
need to complete the OpenStack installation in order to test it.


``network-node``
----------------

As we did for the api node before staring it is good to quickly check if the
remote ssh execution of the commands done in the `all nodes installation`_ section 
worked without problems. You can again verify it by checking the ntp installation.

nova-network
++++++++++++

Networking in OpenStack is quite complex, you have multiple options
and you currently have two different, incompatible implementations.

The newer, feature rich but still unstable is called **Neutron**
(previously known as **Quantum**, they renamed it because of Trademark
issues). We are not going to implement this solution because it is:

1) very complex
2) quite unstable
3) not actually needed for a basic setup

The old, stable, very well working solution is **nova-network**, which
is the solution we are going to implement.

Let's just recap how the networking works in OpenStack

OpenStack networking
~~~~~~~~~~~~~~~~~~~~

The nova-network is providing the networkig service in OpenStack and enables
the communication between the instances and:

* the rest of the stack services 
* the outside world. 

There are currently three kind of networks implemented by three "Network Manager" types:

* Flat DHCP Network Manager: the implementation we are going to use in the tutorial. 
  OpenStack starts a DHCP server (dnsmasq) to pass out IP addresses to VM instances
  from the specified subnet in addition to manually configuring the networking bridge. 
  IP addresses for VM instances are grabbed from a subnet specified by the network administrator.
  
* Flat Network Manager: a network administrator specifies a subnet where 
  IP addresses for VM instances are grabbed from the subnet, and then injected into
  the image on launch. This means the system adminstrator has to implement a method 
  for the IP assigment: external DHCP or other means.
  
* VLAN Network Manager: In this mode, Compute creates a VLAN and bridge for each project.
  For multiple machine installation, the VLAN Network Mode requires a switch that supports VLAN 
  tagging (IEEE 802.1Q)


..
   FIXME: during the tutorial, it's probably better to install the
   package first, and then, during the installation, explain how
   nova-network works.

``nova-network`` configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Please note that nova-network service will use the same user and MySQL
database we used for the ``api-node`` node, and since the old
``nova-network`` service does not have any specific API we don't have
to create a keystone service and endpoint for it.

Let's start by installing the needed software::

    root@network-node:~# apt-get install -y nova-network ebtables nova-api-metadata


.. Please note that if ebtables is not present, you will get a quite
   hard to understand error. The only way to understand that the
   ebtables command is needed is by using strace on the nova-network
   service!

.. nova-api-metadata is needed since nova-network is not installed on
   the same node as the nova-api, and the node running nova-api is not
   connected to the internal network of the VMs.

Network configuration on the **network-node** will look like:

+-------+------------------+-----------------------------------------------------+
| iface | network          | usage                                               |
+=======+==================+=====================================================+
| eth0  | 192.168.122.0/24 | ip assigned by kvm, to access the internet          |
+-------+------------------+-----------------------------------------------------+
| eth1  | 10.0.0.0/24      | internal network                                    |
+-------+------------------+-----------------------------------------------------+
| eth2  | 172.16.0.0/24    | public network                                      |
+-------+------------------+-----------------------------------------------------+
| eth3  | 0.0.0.0          | slave network of the br100 bridge                   |
+-------+------------------+-----------------------------------------------------+
| br100 | 10.99.0.0/22     | bridge connected to the internal network of the VMs |
+-------+------------------+-----------------------------------------------------+

The last interface (eth3) is managed by **nova-network** itself, so we
only have to create a bridge and attach eth3 to it. This is done on
ubuntu by editing the ``/etc/network/interface`` file and ensuring
that it contains::

    auto br100
    iface br100 inet static
        address      0.0.0.0
        pre-up ifconfig eth3 0.0.0.0 
        bridge-ports eth3
        bridge_stp   off
        bridge_fd    0

This will ensure that the interface will be brought up after
networking initialization, but if you want to bring it up right now
you can just run::

    root@network-node:~# ifup br100

    Waiting for br100 to get ready (MAXWAIT is 2 seconds).
    ssh stop/waiting
    ssh start/running, process 1751

..
   In order get the issues working you have to install also the
   "ebtables" software package which administrates the ethernet bridge
   frame table::

       root@network-node:~# apt-get install ebtables 

The network node acts as gateway for the VMs, so we need to enable IP
forwarding. This is done by ensuring that the following line is
present in ``/etc/sysctl.conf`` file::

    net.ipv4.ip_forward=1

This file is read during the startup, but it is not read
afterwards. To force Linux to re-read the file you can run::

    root@network-node:~# sysctl -p /etc/sysctl.conf
    net.ipv4.ip_forward = 1

Update the configuration file ``/etc/nova/nova.conf`` and ensure the
following options are defined::

    network_manager=nova.network.manager.FlatDHCPManager
    force_dhcp_release=True
    firewall_driver=nova.virt.libvirt.firewall.IptablesFirewallDriver

    rabbit_host=10.0.0.3
    sql_connection=mysql://novaUser:novaPass@10.0.0.3/nova

    flat_network_bridge=br100
    fixed_range=10.99.0.0/22    
    flat_network_dhcp_start=10.99.0.10
    network_size=1022
    
    # Floating IPs
    auto_assign_floating_ip=true
    default_floating_pool=public
    public_interface=eth2

..
   FIXME: ``auto_assign_floating_ip`` will only work if floating IPs are
   configured and there are floating IPs free!

..
       # Not sure it's needed
       # libvirt_use_virtio_for_bridges=True
       vlan_interface=eth2
       flat_interface=eth2

Restart the nova-network service and the nova-api-metadata service with::

    root@network-node:~# service nova-network restart
    root@network-node:~# service nova-api-metadata restart


Nova network creation
~~~~~~~~~~~~~~~~~~~~~

You have to create manually a private internal network on the main
node. This is the internal network used by the instances within
OpenStack, and usually is a completely separated network. On the
compute nodes and on the network node this is available through the
``br100`` bridge (although compute nodes does not have an IP address
on this network), while other service nodes does not have any
interface on that network. As a consequence, the internal IP address
of the instances is only reachable by either the network node
or another instance.

The command to create the internal network **10.99.0.0/22**, which we
are going to call "**net1**" is::

    root@network-node:~# nova-manage network create --fixed_range_v4 10.99.0.0/22 \
      --num_networks 1 --network_size 1022 --bridge br100 net1

..
   FIXME: TOCHECK: ``eth2`` is the interface **ON THE COMPUTE NODE**.

In order to allow the instances to be reachable from the
internet too (during this school, due to hardware limitations, this
only means reachable by the physical nodes) we need to create a range
of public IPs. These IP can be either automatically assigned when an
instance is started (using the option
``auto_assign_floating_ip=true`` in ``/etc/nova/nova.conf`` on the
``nova-network`` node, like we did), and/or assigned and removed from
an instance while it is up&running.

Create a floating public network::

    root@network-node:~# nova-manage floating create --ip_range 172.16.1.0/24 --pool=public

..
   FIXME: TOCHECK: ``eth2`` is the interface **ON THE COMPUTE NODE**.

We are going to use all the IP address of type **172.16.1.x** for the
public IP of the VMs. Please note that this does not have to be a
*real* network: the argument of the ``--ip_range`` option is used to
allow passing multiple IP addresses at once, so that the previous
commands has exactly the same effect of running::

    root@network-node:~# for i in {1..254}
    do
    nova-manage floating create --ip_range 172.16.1.$i --pool=public
    done

(but the latter it's quite slower!)

A list of floating IPs defined in the network nova can be shown using
``nova-manage``::

    root@network-node:~# nova-manage floating list
    None    172.16.1.1      None    public  eth2
    None    172.16.1.2      None    public  eth2
    ...
    None    172.16.1.254    None    public  eth2


The default security group does not have any rule associated with it,
so you may want to add default rules to at least allow ping and ssh
connections::

    root@network-node:~# nova --os-user admin --os-tenant-name admin \
      --os-password keystoneAdmin --os-auth-url http://auth-node.example.org:5000/v2.0 \
      secgroup-add-rule default icmp -1 -1 0.0.0.0/0
    +-------------+-----------+---------+-----------+--------------+
    | IP Protocol | From Port | To Port | IP Range  | Source Group |
    +-------------+-----------+---------+-----------+--------------+
    | icmp        | -1        | -1      | 0.0.0.0/0 |              |
    +-------------+-----------+---------+-----------+--------------+

    root@network-node:~# nova --os-user admin --os-tenant-name admin \
      --os-password keystoneAdmin  --os-auth-url http://auth-node.example.org:5000/v2.0 \
      secgroup-add-rule default tcp 22 22 0.0.0.0/0
    +-------------+-----------+---------+-----------+--------------+
    | IP Protocol | From Port | To Port | IP Range  | Source Group |
    +-------------+-----------+---------+-----------+--------------+
    | tcp         | 22        | 22      | 0.0.0.0/0 |              |
    +-------------+-----------+---------+-----------+--------------+


``compute-1`` and ``compute-2``
-------------------------------

As we did for the network node before staring it is good to quickly check if the
remote ssh execution of the commands done in the `all nodes installation`_ section 
worked without problems. You can again verify it by checking the ntp installation.

Nova-compute
++++++++++++

In the next few rows we try to briefly explain what happens behind the scene when a new request 
for starting an OpenStack instance is done. Note that this is very high level description. 

1) Authentication is performed either by the web interface **horizon**
   or **nova** command line tool:

   a) keystone is contacted and authentication is performed
   b) a *token* is saved in the database and returned to the client
      (horizon or nova cli) to be used with later interactions with
      OpenStack services for this request.

2) **nova-api** is contacted and a new request is created:

   a) it checks via *keystone* the validity of the token
   b) checks the authorization of the user
   c) validates parameters and create a new request in the database
   d) calls the scheduler via queue

3) **nova-scheduler** find an appropriate host

   a) reads the request
   b) find an appropriate host via filtering and weighting
   c) calls the choosen *nova-compute* host via queue

4) **nova-compute** read the request and start an instance:

   a) generates a proper configuration for the hypervisor 
   b) get image URI via image id
   c) download the image
   d) request to allocate network via queue

5) **nova-network** configure the network

   a) allocates a valid private ip
   b) if requested, it allocates a floating ip
   c) configures the operating system as needed (in our case: dnsmasq
      and iptables are configured)
   d) updates the request status

6) **nova-api** contacts *cinder* to provision the volume

   a) gets connection parameters from cinder
   b) uses iscsi to make the volume available on the local machine
   c) asks the hypervisor to provision the local volume as virtual
      volume of the specified virtual machine

7) **horizon** or **nova** poll the status of the request by
   contacting **nova-api** until it is ready.


Software installation
~~~~~~~~~~~~~~~~~~~~~

Since we cannot use KVM because our compute nodes are virtualized and
the host node does not support *nested virtualization*, we install
**qemu** instead of **kvm**::

    root@compute-1 # apt-get install -y nova-compute-qemu

This will also install the **nova-compute** package and all its
dependencies.


Network configuration
~~~~~~~~~~~~~~~~~~~~~

We need to configure an internal bridge. The bridge will be used by
libvirt daemon to connect the network interface of a virtual machine
to a physical network, in our case, **eth2** on the compute node.

In our setup, this is the same layer-2 network as the **eth1** network
used for the internal network of OpenStack services; however, in
production, you will probably want to separate the two network, either
by using physically separated networks or by use of VLANs.

Please note that (using the naming convention of our setup) the
**eth3** interface on the **network-node** must be in the same L2 network as
**eth2** in the **compute-node**

Update the ``/etc/network/interfaces`` file and configure a new
bridge, called **br100** attached to the network interface ``eth2``::

    auto br100
    iface br100 inet static
        address      0.0.0.0
        pre-up ifconfig eth2 0.0.0.0 
        bridge-ports eth2
        bridge_stp   off
        bridge_fd    0

Start the bridge::

    root@compute-1 # ifup br100

The **br100** interface should now be up&running::

    root@compute-1 # ifconfig br100
    br100     Link encap:Ethernet  HWaddr 52:54:00:c7:1a:7b  
              inet6 addr: fe80::5054:ff:fec7:1a7b/64 Scope:Link
              UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
              RX packets:6 errors:0 dropped:0 overruns:0 frame:0
              TX packets:6 errors:0 dropped:0 overruns:0 carrier:0
              collisions:0 txqueuelen:0 
              RX bytes:272 (272.0 B)  TX bytes:468 (468.0 B)

The following command will show you the physical interfaces associated
to the **br100** bridge::

    root@compute-1 # brctl show
    bridge name bridge id       STP enabled interfaces
    br100       8000.525400c71a7b   no      eth2


nova configuration
~~~~~~~~~~~~~~~~~~

The **nova-compute** daemon must be able to connect to the RabbitMQ
and MySQL servers. The minimum information you have to provide in the
``/etc/nova/nova.conf`` file are::

    [DEFAULT]
    logdir=/var/log/nova
    state_path=/var/lib/nova
    lock_path=/run/lock/nova
    verbose=True
    # api_paste_config=/etc/nova/api-paste.ini
    # compute_scheduler_driver=nova.scheduler.simple.SimpleScheduler
    rabbit_host=10.0.0.3
    # nova_url=http://10.0.0.6:8774/v1.1/
    sql_connection=mysql://novaUser:novaPass@10.0.0.3/nova
    root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf

    # Auth
    use_deprecated_auth=false
    auth_strategy=keystone

    # Imaging service
    glance_api_servers=10.0.0.5:9292
    image_service=nova.image.glance.GlanceImageService

    # Vnc configuration
    novnc_enabled=true
    novncproxy_base_url=http://10.0.0.6:6080/vnc_auto.html
    novncproxy_port=6080
    vncserver_proxyclient_address=10.0.0.20
    vncserver_listen=0.0.0.0

    # Compute #
    compute_driver=libvirt.LibvirtDriver

You can just replace the ``/etc/nova/nova.conf`` file with the content
displayed above.

..
   On the ``/etc/nova/api-paste.conf`` we have to put the information
   on how to access the keystone authentication service. Ensure then that
   the following information are present in this file::
   TA: I don't think it is needed as api-paste.conf file is not even present.

       [filter:authtoken]
       paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
       auth_host = 10.0.0.4
       auth_port = 35357
       auth_protocol = http
       admin_tenant_name = service
       admin_user = nova
       admin_password = novaServ


nova-compute configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~

Ensure that the the ``/etc/nova/nova-compute.conf`` has the correct
libvirt type. For our setup this file should only contain::

    [DEFAULT]
    libvirt_type=qemu
    libvirt_cpu_mode=none

Please note that these are the lines needed on *our* setup because we
have virtualized compute nodes without support for nested
virtualization. On a production environment, using physical machines
with full support for virtualization you would probably need to set::

    [DEFAULT]
    libvirt_type=kvm

..
  Not needed:

   * Edit the qemu.conf with the needed options as specified in the tutorial (uncomment cgrout, ... )
   * Edit libvirt.conf (follow the tutorial)
   * Edit libvirt-bin.conf (follow the tutorial)
   * Modify l'API in api-paste.ini in order to abilitate access to keystone.


Final check
~~~~~~~~~~~

After restarting the **nova-compute** service::

    root@compute-1 # service nova-compute restart

you should be able to see the compute node from the **api-node**::

    root@api-node:~# nova-manage service list
    Binary           Host                                 Zone             Status     State Updated_At
    nova-cert        api-node                             internal         enabled    :-)   2013-08-13 13:43:35
    nova-conductor   api-node                             internal         enabled    :-)   2013-08-13 13:43:31
    nova-consoleauth api-node                             internal         enabled    :-)   2013-08-13 13:43:35
    nova-scheduler   api-node                             internal         enabled    :-)   2013-08-13 13:43:35
    nova-network     network-node                         internal         enabled    :-)   2013-08-19 09:28:42
    nova-compute     compute-1                            nova             enabled    :-)   None      



Testing OpenStack
-----------------

We will test OpenStack first from the **api-node** using the command
line interface, and then from the physical node connecting to the web
interface.


The first thing we need to do is to create a ssh keypair and upload
the public key on OpenStack so that we can connect to the instance.
The command to create a ssh keypair is ``ssh-keygen``::

    root@api-node:~# ssh-keygen -t rsa -f ~/.ssh/id_rsa
    Generating public/private rsa key pair.
    Enter passphrase (empty for no passphrase): 
    Enter same passphrase again: 
    Your identification has been saved in /root/.ssh/id_rsa.
    Your public key has been saved in /root/.ssh/id_rsa.pub.
    The key fingerprint is:
    fa:86:74:77:a2:55:29:d8:e7:06:4a:13:f7:ca:cb:12 root@api-node
    The key's randomart image is:
    +--[ RSA 2048]----+
    |                 |
    |        . .      |
    |         = . .   |
    |        + + =    |
    |       .S+ B     |
    |      ..E * +    |
    |     ..o * =     |
    |      ..+ o      |
    |       ...       |
    +-----------------+

Then we have to create an OpenStack keypair and upload our *public*
key. This is done using ``nova keypair-add`` command::

    root@api-node:~# nova keypair-add gridka-api-node --pub-key ~/.ssh/id_rsa.pub

you can check that the keypair has been created with::

    root@api-node:~# nova keypair-list
    +-----------------+-------------------------------------------------+
    | Name            | Fingerprint                                     |
    +-----------------+-------------------------------------------------+
    | gridka-api-node | fa:86:74:77:a2:55:29:d8:e7:06:4a:13:f7:ca:cb:12 |
    +-----------------+-------------------------------------------------+

Let's get the ID of the available images, flavors and security
groups::

    root@api-node:~# nova image-list
    +--------------------------------------+--------------+--------+--------+
    | ID                                   | Name         | Status | Server |
    +--------------------------------------+--------------+--------+--------+
    | 79af6953-6bde-463d-8c02-f10aca227ef4 | cirros-0.3.0 | ACTIVE |        |
    +--------------------------------------+--------------+--------+--------+

    root@api-node:~# nova flavor-list
    +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+-------------+
    | ID | Name      | Memory_MB | Disk | Ephemeral | Swap | VCPUs | RXTX_Factor | Is_Public | extra_specs |
    +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+-------------+
    | 1  | m1.tiny   | 512       | 0    | 0         |      | 1     | 1.0         | True      | {}          |
    | 2  | m1.small  | 2048      | 20   | 0         |      | 1     | 1.0         | True      | {}          |
    | 3  | m1.medium | 4096      | 40   | 0         |      | 2     | 1.0         | True      | {}          |
    | 4  | m1.large  | 8192      | 80   | 0         |      | 4     | 1.0         | True      | {}          |
    | 5  | m1.xlarge | 16384     | 160  | 0         |      | 8     | 1.0         | True      | {}          |
    +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+-------------+

    root@api-node:~# nova secgroup-list
    +---------+-------------+
    | Name    | Description |
    +---------+-------------+
    | default | default     |
    +---------+-------------+

Now we are ready to start our first instance::

    root@api-node:~# nova boot --image 79af6953-6bde-463d-8c02-f10aca227ef4 \
      --security-group default --flavor m1.tiny --key_name gridka-api-node server-1
    +-------------------------------------+--------------------------------------+
    | Property                            | Value                                |
    +-------------------------------------+--------------------------------------+
    | OS-EXT-STS:task_state               | scheduling                           |
    | image                               | cirros-0.3.0                         |
    | OS-EXT-STS:vm_state                 | building                             |
    | OS-EXT-SRV-ATTR:instance_name       | instance-00000001                    |
    | flavor                              | m1.tiny                              |
    | id                                  | 8e680a03-34ac-4292-a23c-d476b209aa62 |
    | security_groups                     | [{u'name': u'default'}]              |
    | user_id                             | 9e8ec4fa52004fd2afa121e2eb0d15b0     |
    | OS-DCF:diskConfig                   | MANUAL                               |
    | accessIPv4                          |                                      |
    | accessIPv6                          |                                      |
    | progress                            | 0                                    |
    | OS-EXT-STS:power_state              | 0                                    |
    | OS-EXT-AZ:availability_zone         | nova                                 |
    | config_drive                        |                                      |
    | status                              | BUILD                                |
    | updated                             | 2013-08-19T09:37:34Z                 |
    | hostId                              |                                      |
    | OS-EXT-SRV-ATTR:host                | None                                 |
    | key_name                            | gridka-api-node                      |
    | OS-EXT-SRV-ATTR:hypervisor_hostname | None                                 |
    | name                                | server-1                             |
    | adminPass                           | k7cT4nnC6sJU                         |
    | tenant_id                           | 1ce38185a0c941f1b09605c7bfb15a31     |
    | created                             | 2013-08-19T09:37:34Z                 |
    | metadata                            | {}                                   |
    +-------------------------------------+--------------------------------------+

This command returns immediately, even if the OpenStack instance is
not yet started::

    root@api-node:~# nova list
    +--------------------------------------+----------+--------+----------+
    | ID                                   | Name     | Status | Networks |
    +--------------------------------------+----------+--------+----------+
    | 8e680a03-34ac-4292-a23c-d476b209aa62 | server-1 | BUILD  |          |
    +--------------------------------------+----------+--------+----------+

    root@api-node:~# nova list
    +--------------------------------------+----------+--------+----------------------------+
    | ID                                   | Name     | Status | Networks                   |
    +--------------------------------------+----------+--------+----------------------------+
    | d2ef7cbf-c506-4c67-a6b6-7bd9fecbe820 | server-1 | BUILD  | net1=10.99.0.2, 172.16.1.1 |
    +--------------------------------------+----------+--------+----------------------------+

    root@api-node:~# nova list
    +--------------------------------------+----------+--------+----------------------------+
    | ID                                   | Name     | Status | Networks                   |
    +--------------------------------------+----------+--------+----------------------------+
    | d2ef7cbf-c506-4c67-a6b6-7bd9fecbe820 | server-1 | ACTIVE | net1=10.99.0.2, 172.16.1.1 |
    +--------------------------------------+----------+--------+----------------------------+

When the instance is in ``ACTIVE`` state it means that it is now
running on a compute node. However, the boot process
can take some time, so don't worry if the following command will fail
a few times before you can actually connect to the instance::

    root@api-node:~# ssh 172.16.1.1
    The authenticity of host '172.16.1.1 (172.16.1.1)' can't be established.
    RSA key fingerprint is 38:d2:4c:ee:31:11:c1:1a:0f:b6:3b:dc:f2:d2:46:8f.
    Are you sure you want to continue connecting (yes/no)? yes
    Warning: Permanently added '172.16.1.1' (RSA) to the list of known hosts.
    # uname -a
    Linux cirros 3.0.0-12-virtual #20-Ubuntu SMP Fri Oct 7 18:19:02 UTC 2011 x86_64 GNU/Linux

Testing cinder
++++++++++++++

You can attach a volume to a running instance easily::

    root@api-node:~# nova volume-list
    +--------------------------------------+-----------+--------------+------+-------------+-------------+
    | ID                                   | Status    | Display Name | Size | Volume Type | Attached to |
    +--------------------------------------+-----------+--------------+------+-------------+-------------+
    | 180a081a-065b-497e-998d-aa32c7c295cc | available | test2        | 1    | None        |             |
    +--------------------------------------+-----------+--------------+------+-------------+-------------+

    root@api-node:~# nova volume-attach server-1 180a081a-065b-497e-998d-aa32c7c295cc /dev/vdb
    +----------+--------------------------------------+
    | Property | Value                                |
    +----------+--------------------------------------+
    | device   | /dev/vdb                             |
    | serverId | d2ef7cbf-c506-4c67-a6b6-7bd9fecbe820 |
    | id       | 180a081a-065b-497e-998d-aa32c7c295cc |
    | volumeId | 180a081a-065b-497e-998d-aa32c7c295cc |
    +----------+--------------------------------------+

Inside the instnace, a new disk named ``/dev/vdb`` will appear. This
disk is *persistent*, which means that if you terminate the instance
and then you attach the disk to a new instance, the content of the
volume is persisted.


Horizon
-------

On the **api-node**::

    root@api-node:# apt-get install openstack-dashboard

Edit the file ``/etc/openstack-dashboard/local_settings.py`` and
update the ``OPENSTACK_HOST`` variable::

    OPENSTACK_HOST = "auth-node.example.org"

From the **physical node** you can connect to the api-node node by
opening the URL ``http://172.16.0.6/horizon`` on your web browser


..
   Keystone is then checking on what the users/tenants are "supposed" to
   see (in terms of images, quotes, etc). Working nodes are periodically
   writing their status in the nova-database. When a new request arrives
   it is processed by the nova-scheduler which writes in the
   nova-database when a matchmaking with a free resource has been
   accomplished. On the next poll when the resource reads the
   nova-database it "realizes" that it is supposed to start a
   new VM. nova-compute writes then the status inside the nova database.

   Different scheduling policy and options can be set in the nova's configuration file.


Notes on EC2 compatible interface
---------------------------------

The EC2 compatibility layer in nova is provided by the **nova-api**
service together with the native interface. There also is a
**nova-api-ec2** service which is used *as a replacement* of
**nova-api** if you only need the EC2 API and you don't want the
native apis, although in our case we need both.

The EC2 compatibility layer, however, need one more configuration
option we didn't define. 

Edit ``/etc/nova/nova.conf`` on the **api-node** and add the following
option::

    keystone_ec2_url=http://auth-node.example.org:5000/v2.0/ec2tokens

Please note that this is an url pointing to the keystone service, but
with an additional ``ec2tokens``. This is used by the **nova-api**
service to validate ec2-style tokens, and by default points to
localhost.

working with the EC2 interface
++++++++++++++++++++++++++++++

To access an EC2 endpoint you need to get an **access key** and a
**secret key**. These are temporary tokens you can create and delete,
so that you don't have to use your login and password all the time,
and you can actually *lend* them to other people to allow them to run
virtual machines on your behalf without having to give them your login
and password. You can delete them whenever you want.

To create a new pair of ec2 credentials you can run::

    root@api-node:~# keystone ec2-credentials-create
    +-----------+----------------------------------+
    |  Property |              Value               |
    +-----------+----------------------------------+
    |   access  | c22f5770ee924f25b4c7b091f521b15f |
    |   secret  | 78b92ddde8134b46a05dbd91023e27db |
    | tenant_id | acdbdb11d3334ed987869316d0039856 |
    |  user_id  | 13ff2976843649669c4911ec156eaa3f |
    +-----------+----------------------------------+

You can later on delete a pair of ec2 credentials with ``keystone
ec2-credentials-delete --access <access_key>``

If you want to test the EC2 interface the easiest way is to install
the **euca2ools** tool::

    root@api-node:~# apt-get install euca2ools

and then run, for instance, the command::

    root@api-node:~# euca-describe-images \
      --access-key c22f5770ee924f25b4c7b091f521b15f \
      --secret-key 78b92ddde8134b46a05dbd91023e27db \
      -U http://api-node.example.org:8773/services/Cloud
    IMAGE	ami-00000001	None (Cirros-0.3.0-x86_64)	0aacc603e6dd425caa51db0d07957412	available	private			machine				instance-store

There are two things to note about this command:

* the URL we are using this time is *not* the keystone url. This
  because the service providing the EC2 compatibility layer is
  **nova-api** instead, so we have to use the URL we used as endpoint
  for the **ec2** service

* the image id returned by the previous command is *not* directly
  related to the image id used in glance. Instead, it is an ``ami-*``
  id (similar to the IDs used by amazon images). Actually, there is no
  easy way to get the ami id knowing the glance id, so you have to
  use the image name whenever it is possible to identify the right
  image.

Also for the euca2ools and for most of the EC2 libraries, setting the
following environment variables allows you to avoid explicitly specify
access/secret keys and endpoint url::

    root@api-node:~# export EC2_ACCESS_KEY=445f486efe1a4eeea2c924d0252ff269
    root@api-node:~# export EC2_SECRET_KEY=ff98e8529e2543aebf6f001c74d65b17
    root@api-node:~# export EC2_URL=http://api-node.example.org:8773/services/Cloud

Start a virtual machine using euca2ools
+++++++++++++++++++++++++++++++++++++++

The command is similar to ``nova boot``::

    root@api-node:~# euca-run-instances \
      --access-key 445f486efe1a4eeea2c924d0252ff269 \
      --secret-key ff98e8529e2543aebf6f001c74d65b17 \
      -U http://api-node.example.org:8773/services/Cloud \
      ami-00000001 -k gridka-api-node
    RESERVATION	r-e9cq9p1o	acdbdb11d3334ed987869316d0039856	default
    INSTANCE	i-00000007	ami-00000001			pending	gridka-api-node (acdbdb11d3334ed987869316d0039856, None)	0	m1.small	2013-08-29T07:55:15.000Z	nova				monitoring-disabled					instance-store	

Instances created by euca2ools are, of course, visible with nova as
well::

    root@api-node:~# nova list
    +--------------------------------------+---------------------------------------------+--------+----------------------------+
    | ID                                   | Name                                        | Status | Networks                   |
    +--------------------------------------+---------------------------------------------+--------+----------------------------+
    | ec1e58e4-57f4-4429-8423-a44891a098e3 | Server ec1e58e4-57f4-4429-8423-a44891a098e3 | BUILD  | net1=10.99.0.3, 172.16.1.2 |
    +--------------------------------------+---------------------------------------------+--------+----------------------------+

Working with Flavors
--------------------

We have already seen, that there are a number of predefined flavors available
that provide certain classes of compute nodes and define number of vCPUs, RAM and disk.::

    root@api-node:~# nova flavor-list
    +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+-------------+
    | ID | Name      | Memory_MB | Disk | Ephemeral | Swap | VCPUs | RXTX_Factor | Is_Public | extra_specs |
    +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+-------------+
    | 1  | m1.tiny   | 512       | 0    | 0         |      | 1     | 1.0         | True      | {}          |
    | 2  | m1.small  | 2048      | 20   | 0         |      | 1     | 1.0         | True      | {}          |
    | 3  | m1.medium | 4096      | 40   | 0         |      | 2     | 1.0         | True      | {}          |
    | 4  | m1.large  | 8192      | 80   | 0         |      | 4     | 1.0         | True      | {}          |
    | 5  | m1.xlarge | 16384     | 160  | 0         |      | 8     | 1.0         | True      | {}          |
    +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+-------------+

In order to create a new flavor, use the CLI like so::

    root@api-node:~# nova flavor-create --is-public true x1.tiny 6 256 2 1
    +----+---------+-----------+------+-----------+------+-------+-------------+-----------+-------------+
    | ID | Name    | Memory_MB | Disk | Ephemeral | Swap | VCPUs | RXTX_Factor | Is_Public | extra_specs |
    +----+---------+-----------+------+-----------+------+-------+-------------+-----------+-------------+
    | 6  | x1.tiny | 256       | 2    | 0         |      | 1     | 1.0         | True      | {}          |
    +----+---------+-----------+------+-----------+------+-------+-------------+-----------+-------------+

Where the parameters are like this::

    --is-public: controls if the image can be seen by all users
    --ephemeral: size of ephemeral disk in GB (default 0)
    --swap: size of swap in MB (default 0) 
    --rxtx-factor: network throughput factor (use to limit network usage) (default 1)
    x1.tiny:  the name of the flavor
    6:   the unique id of the flavor (check flavor list to see the next free flavor)
    256: Amount of RAM in MB
    2:   Size of disk in GB
    1:   Number of vCPUs

If we check the list again, we will see, that the flavor has been created::

    root@api-node:~# nova flavor-list
    +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+-------------+
    | ID | Name      | Memory_MB | Disk | Ephemeral | Swap | VCPUs | RXTX_Factor | Is_Public | extra_specs |
    +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+-------------+
    | 1  | m1.tiny   | 512       | 0    | 0         |      | 1     | 1.0         | True      | {}          |
    | 2  | m1.small  | 2048      | 20   | 0         |      | 1     | 1.0         | True      | {}          |
    | 3  | m1.medium | 4096      | 40   | 0         |      | 2     | 1.0         | True      | {}          |
    | 4  | m1.large  | 8192      | 80   | 0         |      | 4     | 1.0         | True      | {}          |
    | 5  | m1.xlarge | 16384     | 160  | 0         |      | 8     | 1.0         | True      | {}          |
    | 6  | x1.tiny   | 256       | 2    | 0         |      | 1     | 1.0         | True      | {}          |
    +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+-------------+

Change the flavor of an existing VM
+++++++++++++++++++++++++++++++++++

NOTE: This might or might not work on our test setup.

You can change the flavor of an existing VM (effectively resizing it) by running the following 
command.

First lets find a running instance::

    root@api-node:~# nova list --all-tenants
    +--------------------------------------+---------+--------+----------------------------+
    | ID                                   | Name    | Status | Networks                   |
    +--------------------------------------+---------+--------+----------------------------+
    | bf619ff4-303a-417c-9631-d7147dd50585 | server1 | ACTIVE | net1=10.99.0.2, 172.16.1.1 |
    +--------------------------------------+---------+--------+----------------------------+

and see what flavor it has::

    root@api-node:~# nova show bf619ff4-303a-417c-9631-d7147dd50585
    +-------------------------------------+------------------------------------------------------------+
    | Property                            | Value                                                      |
    +-------------------------------------+------------------------------------------------------------+
    | status                              | ACTIVE                                                     |
    | updated                             | 2013-08-29T10:24:26Z                                       |
    | OS-EXT-STS:task_state               | None                                                       |
    | OS-EXT-SRV-ATTR:host                | compute-1                                                  |
    | key_name                            | antonio                                                    |
    | image                               | Cirros-0.3.0-x86_64 (a6d81f9c-8789-49da-a689-503b40bcd23c) |
    | hostId                              | ccc0c0738aea619c49a17654f911a9e2419848aece435cb7f117f666   |
    | OS-EXT-STS:vm_state                 | active                                                     |
    | OS-EXT-SRV-ATTR:instance_name       | instance-00000012                                          |
    | OS-EXT-SRV-ATTR:hypervisor_hostname | compute-1                                                  |
    | flavor                              | m1.tiny (1)                                                |
    | id                                  | bf619ff4-303a-417c-9631-d7147dd50585                       |
    | security_groups                     | [{u'name': u'default'}]                                    |
    | user_id                             | 13ff2976843649669c4911ec156eaa3f                           |
    | name                                | server1                                                    |
    | created                             | 2013-08-29T10:24:15Z                                       |
    | tenant_id                           | acdbdb11d3334ed987869316d0039856                           |
    | OS-DCF:diskConfig                   | MANUAL                                                     |
    | metadata                            | {}                                                         |
    | accessIPv4                          |                                                            |
    | accessIPv6                          |                                                            |
    | net1 network                        | 10.99.0.2, 172.16.1.1                                      |
    | progress                            | 0                                                          |
    | OS-EXT-STS:power_state              | 1                                                          |
    | OS-EXT-AZ:availability_zone         | nova                                                       |
    | config_drive                        |                                                            |
    +-------------------------------------+------------------------------------------------------------+

Now resisze the VM by specifying the new flavor ID::

    root@api-node:~# nova resize bf619ff4-303a-417c-9631-d7147dd50585 6

While the server is resizing, its status will be RESIZING::
    
    root@api-node:~# nova list --all-tenants

Once the resize operation is done, the status will change to VERIFY_RESIZE and you will have to confirm
that the resize operation worked::

    root@api-node:~# nova resize-confirm bf619ff4-303a-417c-9631-d7147dd50585

or, if things went wrong, revert the resize::

    root@api-node:~# nova resize-revert bf619ff4-303a-417c-9631-d7147dd50585 

The status of the server will now be back to ACTIVE.


References
----------

As starting reference has been used the following `tutorial
<https://github.com/mseknibilel/OpenStack-Grizzly-Install-Guide/blob/master/OpenStack_Grizzly_Install_Guide.rst>`_.

We adapted the tutorial above with what we considered necessary for
our purposes and for installing OpenStack on 6 hosts.

The `official Grizzly tutorial <http://docs.openstack.org/grizzly/openstack-compute/install/apt/content/>`_.

.. _`Openstack Compute Administration Guide`: http://docs.openstack.org/trunk/openstack-compute/admin/content/index.html

For a very good explanation about the FlatDHCP netowrk configuration, also cfr. http://www.mirantis.com/blog/openstack-networking-flatmanager-and-flatdhcpmanager/


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
