Welcome to the gridka-school wiki!
==================================

This quide is to be used as reference for the installation of
OpenStack `Grizzly` during the `GridKa School 2013 - Training Session on
OpenStack`. 

As starting reference has been used the following `tutorial
<https://github.com/mseknibilel/OpenStack-Grizzly-Install-Guide/blob/master/OpenStack_Grizzly_Install_Guide.rst>`_.

We adapated the tutorial above with what we cosidered necessary for our purpouses and for installing OpenStack on
6 hosts.

The official Grizzly tutorial can be found `here
<http://docs.openstack.org/grizzly/openstack-compute/install/apt/content/>`_.


OpenStack overview
------------------

This tutorial will show how to install the main components of
OpenStack, specifically:

MySQL
    mysql databased is used for the saving services' related information.

RabbitMQ
    Messaging service used for the communication between two nova components.

Keystone
    OpenStack service which provides authentication. In our setup we
    will store login, password and tokens in the MySQL db.

nova-api
    OpenStack API endpoint. It is used by the web interface, command line
    tools and API clients.

nova-scheduler
    OpenStack scheduler service which decide how and where 
    to dispatch volume and compute requests.

nova-network
    OpenStack service used to configure the network of the VMs and to
    optionally provide the so-called *Floating IPs*. IPs that can be
    *attached* and *detached* from a virtual machine while it is
    already running.

nova-compute
    OpenStack service which runs on the compute node. It performs all the
    needed operations from starting the VM to its termination.

glance
    OpenStack imaging service. It is used to store virtual disk *templates*
    for the virtual machines.

cinder
    OpenStack volume service. It is used to create persistent volumes which
    can be attached to a running virtual machine later on.

Horizon
    OpenStack Web Interface to nova-api.


Tutorial overview
-----------------

Each team will have two physical machines to work with.

One of the nodes will run 6 VMs running the various central services. 
They are called as follows:

* ``db-node``:  runs *mysql+rabbitmq*  
* ``auth-node``: runs *keystone*
* ``image-node``: runs *glance*
* ``api-node``: runs *nova-api+horizon+nova-scheduler*
* ``network-node``: runs *nova-network*
* ``volume-node``: runs *cinder*

while the other will run 2 VMs hosting the compute nodes for your stack:

* ``compute-1``: runs *nova-compute*
* ``compute-2``: runs *nova-compute*


**FIXME: how to assign the machines to the teams?**

How to access the physical nodes
++++++++++++++++++++++++++++++++

In order to access the different virtual machines and start working on the 
configuration of OpenStack services listed above you will have to first login 
on one of the nodes assigned to your group by doing::

        ssh user@gks-NNN.scc.kit.edu -p 24

where NNN is one of the numbers assigned to you.

Virtual Machines
++++++++++++++++

The physical nodes already have the KVM virtual machines we will use
for the tutorial. These are Ubuntu 12.04 LTS machines with very basic
configuration, including the internal IP address and the correct
hostname.

You can connect to them from each one of the physical machines (the
**gks-NNN** ones) using **ssh**, or start the ``virt-manager`` program
on the physical node hosting the virtual machine. The name of the
virtual machine matches the hostname, as described in the *Tutorial
overview* section:

* **db-node**
* **auth-node**
* **api-node**
* **network-node**
* **image-node**
* **volume-node**
* **compute-1-node**
* **compute-2-node**

You can start and stop them using the ``virt-manager`` graphical
interface or the ``virsh`` command line tool.

Network Setup
+++++++++++++

Each virtual machine is already configured with two network
interfaces. One (eth0) is a private interface with a dynamic ip
address automatically assigned by KVM in the range 192.168.122.0/24,
and it is only accessible from whitin the same physical node, while
the other (eth1) is the *"public"* interface in the range 10.0.0.0/24
and it is accessible from both physical nodes.

The network node, however, needs one more network interface which will
be completely managed by the **nova-network** service and is thus left
unconfigured at the beginning.

On the compute node, moreover, we will need to manually create a
*bridge* which will allow the OpenStack virtual machines to access the
network which connects the two physical nodes.


Installation:
-------------

We will install the following services in sequence, on different
virtual machines.

* ``all nodes installation``: Common tasks for all the nodes
* ``db-node``: MySQL + RabbitMQ,
* ``auth-node``: keystone,
* ``image-node``: glance,
* ``api-node``: noda-api, nova-scheduler,
* ``network-node``: nova-network,
* ``volume-node``: cinder,
* ``compute-1``: nova-compute,
* ``compute-2``: nova-compute,


all nodes installation
--------------------------

Repositories, NTP, system update
++++++++++++++++++++++++++++++++

Before starting you have to perform some common operation on all the hosts. This is
useful as it can easily identify problems on some of the nodes, e.g.: missing connectivity 
or a host being down. 

* Go in sudo mode on all the nodes

::

    root@all-nodes # sudo su - 


* Add the OpenStack Grizzly repository::

    root@all-nodes # apt-get install -y ubuntu-cloud-keyring
    root@all-nodes # echo deb http://ubuntu-cloud.archive.canonical.com/ubuntu precise-updates/grizzly main > /etc/apt/sources.list.d/grizzly.list


* Update the system::
 
    root@all-nodes # apt-get update -y
    root@all-nodes # apt-get upgrade -y 
    root@all-nodes # apt-get dist-upgrade -y    

* Install the NTP service::

    root@all-nodes # apt-get install -y ntp 


``db-node``
-----------


MySQL installation
++++++++++++++++++

Now please move on the db-node where we have to install the MySQL server.
In oder to do that please execute::

    root@all-nodes # apt-get install mysql-server python-mysqldb 


you will be promped for a password, use: **mysql**. This will help us
in debugging issues in the future.

mysqld listens on the 3306 but the IP is set to 127.0.0.1. This has to
be changes in order to make the server accessible from nodes on the
public network (10.0.0.0/24)::

    root@all-nodes # sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf
    root@all-nodes # service mysql restart


RabbitMQ
++++++++

Install the RabbitMQ software::

    root@db-node:~# apt-get install -y rabbitmq-server
        

RabbitMQ does not need any specific configuration. Please keep the
connection to the db-node open as we will need to operate on it
briefly.


``auth-node``
-------------

*(Remember to add the cloud repository and to install the **ntp** package.)*

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
database name, user and password you just created. The syntax of this
option is::

    connection = <protocol>://<user>:<password>@<host>/<db_name>

so in our case you need to replace the default option with::

    connection = mysql://keystoneUser:keystonePass@10.0.0.3/keystone

Now you are ready to bootstrap the keystone database using the
following command::

    root@auth-node:~# keystone-manage db_sync

Now we can restart the keystone service::

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

    root@auth-node:~# export SERVICE_TOKEN="ADMIN"
    root@auth-node:~# export SERVICE_ENDPOINT="http://10.0.0.4:35357/v2.0"

Creation of the admin user
~~~~~~~~~~~~~~~~~~~~~~~~~~

In order to work with keystone we will need to create an admin user
and to create a few basic projects and roles.

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
    root@auth-node:~# keystone tenant-create --name=service

Create the **admin** user::

    root@auth-node:~# keystone user-create --name=admin --pass=keystoneAdmin

Go on by creating the different roles::

    root@auth-node:~# keystone role-create --name=admin
    root@auth-node:~# keystone role-create --name=KeystoneAdmin
    root@auth-node:~# keystone role-create --name=KeystoneServiceAdmin
    root@auth-node:~# keystone role-create --name=Member

This roles are checked by different services. It is not really easy
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

From now on, you can access keystone using the admin user either by
using the following command line options::

    root@any-host:~# keystone --os-user admin --os-tenant-name admin --os-password keystoneAdmin --os-auth-url http://10.0.0.4:5000/v2.0

or by setting the following environment variables and run keystone
without the previous options::

    root@any-host:~# export OS_USERNAME=admin
    root@any-host:~# export OS_PASSWORD=keystoneAdmin
    root@any-host:~# export OS_TENANT_NAME=admin
    root@any-host:~# export OS_AUTH_URL=http://10.0.0.4:5000/v2.0


Creation of the endpoint
~~~~~~~~~~~~~~~~~~~~~~~~

Keystone is not only used to store information about users, passwords
and projects, but also to store a catalog of the availables services
the OpenStack cloud is offering. To each service is then assigned an
*endpoint* which basically consists of a set of three urls (public,
internal, administrative) and a region.

Of course keystone itself is a service ("identity") so it needs its
own service and endpoint.

The "**identity**" service is created with the following command::

    root@auth-node:~# keystone service-create --name keystone --type identity --description 'Keystone Identity Service'

    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |        OpenStack Identity        |
    |      id     | a92e4230026d4e0a9f16c538781f85a4 |
    |     name    |             keystone             |
    |     type    |             identity             |
    +-------------+----------------------------------+

The output will print the **id** associated with this service. This is
needed by the next command, and is passed as argument of the
``--service-id`` option.

The following command will create an endpoint associated to this
service::

    root@auth-node:~# keystone endpoint-create --region RegionOne --service-id a92e4230026d4e0a9f16c538781f85a4
        --publicurl 'http://10.0.0.4:5000/v2.0' --adminurl 'http://10.0.0.4:35357/v2.0'
        --internalurl 'http://10.0.0.4:5000/v2.0'

    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    |   adminurl  |    http://10.0.0.4:35357/v2.0    |
    |      id     | 597a9a3db82148bdbb56a9f43360a95f |
    | internalurl |    http://10.0.0.4:5000/v2.0     |
    |  publicurl  |    http://10.0.0.4:5000/v2.0     |
    |    region   |            RegionOne             |
    |  service_id | a92e4230026d4e0a9f16c538781f85a4 |
    +-------------+----------------------------------+

The argument of the ``--region`` option is the region name. For
semplicity we will always use the name ``RegionOne`` since we are
doing a very simple installation with one availability region only.

To get a listing of the available services the command is::

    root@auth-node:~# keystone service-list
    +----------------------------------+----------+--------------+------------------------------+
    |                id                |   name   |     type     |         description          |
    +----------------------------------+----------+--------------+------------------------------+
    | a92e4230026d4e0a9f16c538781f85a4 | keystone |   identity   |  Keystone Identity Service   |
    +----------------------------------+----------+--------------+------------------------------+

while a list of endpoints is shown by the command::

    root@auth-node:~# keystone endpoint-list
    +----------------------------------+-----------+------------------------------------+------------------------------------+------------------------------------+
    |                id                |   region  |             publicurl              |            internalurl             |              adminurl              |
    +----------------------------------+-----------+------------------------------------+------------------------------------+------------------------------------+
    | 597a9a3db82148bdbb56a9f43360a95f | RegionOne |     http://10.0.0.4:5000/v2.0      |     http://10.0.0.4:5000/v2.0      |     http://10.0.0.4:35357/v2.0     |
    +----------------------------------+-----------+------------------------------------+------------------------------------+------------------------------------+


``image-node``
--------------

*(Remember to add the cloud repository and to install the **ntp** package.)*

Glance
++++++

**Glance** is the name of the image service of OpenStack. It is
responsible to store the images that will be used as templates to
start the virtual machines. We will use the default configuration and
only do the minimal changes to match our configuration.

Similarly to what we did for the keystone service, also for the glance
service we need to create a database and a pair of user and password
for it.

glance database and keystone setup
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

On the **db-node** create the database and the mysql user::

    root@image-node:~# mysql -u root -p
    mysql> CREATE DATABASE glance;
    mysql> GRANT ALL ON glance.* TO 'glanceUser'@'%' IDENTIFIED BY 'glancePass';

On the **auth-node** instead we need to create an **image** service
and an endpoint associated with it. The following commands assume you
already set the environment variables needed to run keystone without
specifying login, password and endpoint all the times.

First of all, we need to get the **id** of the **service** tenant::

    root@image-node:~# keystone tenant-get service
    +-------------+---------------------------------------+
    |   Property  |              Value                    |
    +-------------+---------------------------------------+
    | description |                                       |
    |   enabled   |               True                    |
    |      id     |   6e0864cd071c4806a05b32b1f891d4e0    |
    |     name    |             service                   |
    +-------------+---------------------------------------+

then we need to create a keystone user for the glance service,
associated with the **service** tenant::

    root@image-node:~# keystone user-create --name=glance --pass=glanceServ --tenant-id 6e0864cd071c4806a05b32b1f891d4e0
    +----------+----------------------------------+
    | Property |              Value               |
    +----------+----------------------------------+
    |  email   |                                  |
    | enabled  |               True               |
    |    id    | fc71fbf5814d434097d2f873db364797 |
    |   name   |              glance              |
    | tenantId | 6e0864cd071c4806a05b32b1f891d4e0 |
    +----------+----------------------------------+        

FIXME: is this really needed???

Then we need to give admin permissions to it::

    root@image-node:~# keystone user-role-add --tenant service --user glance --role admin

Please note that we could have created only one user for all the
services, but this is a cleaner solution.

We need then to create the **image** service::

    root@image-node:~# keystone service-create --name glance --type image --description 'Glance Image Service'
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |       Glance Image Service       |
    |      id     | 4edbbac249de4cd7914fde693b0f404c |
    |     name    |             glance               |
    |     type    |              image               |
    +-------------+----------------------------------+

and the related endpoint::

    root@image-node:~# keystone endpoint-create --region RegionOne --service-id 4edbbac249de4cd7914fde693b0f404c 
        --publicurl 'http://10.0.0.5:9292/v2' --adminurl 'http://10.0.0.5:9292/v2' --internalurl 'http://10.0.0.5:9292/v2'
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    |   adminurl  |     http://10.0.0.5:9292/v2      |
    |      id     | baafe80022984f2c84159a3d6612f00a |
    | internalurl |     http://10.0.0.5:9292/v2      |
    |  publicurl  |     http://10.0.0.5:9292/v2      |
    |    region   |            RegionOne             |
    |  service_id | 4edbbac249de4cd7914fde693b0f404c |
    +-------------+----------------------------------+

glance installation and configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

On the **image-node** install the **glance** package::

    root@image-node:~# apt-get install glance

To configure the glance service we need to edit a few files in ``/etc/glance``:

On the ``/etc/glance/glance-api-paste.ini`` file, we need to adjust
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
    admin_password = serviceServ

Information on how to connect to the mysql database are stored in the
``/etc/glance/glance-api.conf`` file. The syntax is similar to the one
used in the``/etc/keystone/keystone.conf`` file,  but the name of the
option is ``sql_connection`` instead::

    sql_connection = mysql://glanceUser:glancePass@10.0.0.4/glance

We also need to specify the rabbitmq host. The other rabbit parameters
should be fine::

    rabbit_host = 10.0.0.3

Finally, we need to specify which paste pipeline we are using. We are not
entering in details here, just check that the following option is present::

    [paste_deploy]
    flavor = keystone

Similar changes need to be done in the
``/etc/glance/glance-registry.conf``, both for the mysql connection::

    sql_connection = mysql://glanceUser:glancePass@10.0.0.4/glance

and for the paste pipeline::

    [paste_deploy]
    flavor = keystone

Like we did with keystone, we need to populate the glance database::

    root@image-node:~# glance-manage db_sync

Now we are ready to restart the glance services::

    root@image-node:~# restart glance-api
    root@image-node:~# restart glance-registry

FIXME: missing how to test glance and upload the first image


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


``volume-node``
+++++++++++++++

Cinder
++++++

**Cinder** is the name of the openstack block storage. It allows
manipulation of volumes, volume types (similar to compute flavors) and
volume snapshots. 

Note that a volume may only be attached to one instance at a
time. This is not a *shared storage* solution like a SAN of NFS on
which multiple servers can attach to.

Volumes created by cinder are served via iSCSI to the compute node,
which will provide them to the VM as regular sata disk. These volumes
can be stored on different backends: LVM (the default one), Ceph,
GlusterFS, NFS or various appliances from IBM, NetApp etc.

Cinder is actually split in different services:

**cinder-api** The cinder-api service is a WSGI app that authenticates
    and routes requests throughout the Block Storage system. It
    supports the OpenStack API's only, although there is a translation
    that can be done via Nova's EC2 interface which calls in to the
    cinderclient.

**cinder-scheduler** The cinder-scheduler is responsible for
    scheduling/routing requests to the appropriate volume service. As
    of Grizzly; depending upon your configuration this may be simple
    round-robin scheduling to the running volume services, or it can
    be more sophisticated through the use of the Filter Scheduler. The
    Filter Scheduler is the default in Grizzly and enables filter on
    things like Capacity, Availability Zone, Volume Types and
    Capabilities as well as custom filters.

**cinder-volume** The cinder-volume service is responsible for
    managing Block Storage devices, specifically the back-end devices
    themselves.

In our setup, we will run all the cinder services on the same machine,
although you can, in principle, spread them over multiple servers.

The **volume-node** has one more disk (``/dev/vdb``) which will use to
create a LVM volume group to store the logical volumes created by
cinder and served via iSCSI.

cinder database and keystone setup
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

As usual, we need to create a database on the **db-node** and an user
in keystone.

On the **db-node** create the database and the mysql user::

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
    +-------------+---------------------------------------+
    |   Property  |              Value                    |
    +-------------+---------------------------------------+
    | description |                                       |
    |   enabled   |               True                    |
    |      id     |   6e0864cd071c4806a05b32b1f891d4e0    |
    |     name    |             service                   |
    +-------------+---------------------------------------+

then we need to create a keystone user for the cinder service, 
associated with the **service** tenant::

    root@auth-node:~# keystone user-create --name=cinder --pass=cinderServ --tenant-id 6e0864cd071c4806a05b32b1f891d4e0
    +----------+----------------------------------+
    | Property |              Value               |
    +----------+----------------------------------+
    |  email   |                                  |
    | enabled  |               True               |
    |    id    | 3cbe0aab435c435490c200b94908aab2 |
    |   name   |              cinder              |
    | tenantId | 6e0864cd071c4806a05b32b1f891d4e0 |
    +----------+----------------------------------+

FIXME: is this really needed???

Then we need to give admin permissions to it::

       root@auth-node:~# keystone user-role-add --tenant service --user cinder --role admin

We need then to create the **volume** service::

    root@auth-node:~# keystone service-create --name cinder --type volume --description 'Volume Service of OpenStack'
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |   Volume Service of OpenStack    |
    |      id     | 2b6252b673d84019aa6b75e702d1b0ab |
    |     name    |              cinder              |
    |     type    |              volume              |
    +-------------+----------------------------------+


and the related endpoint, using the service id we just got::
        
  Once you have it add the new end-point::


    root@auth-node:~# keystone endpoint-create --region RegionOne --service-id 2b6252b673d84019aa6b75e702d1b0ab
         --publicurl 'http://10.0.0.8:8776/v1/$(tenant_id)s' --adminurl 'http://10.0.0.8:8776/v1/$(tenant_id)s' 
         --internalurl 'http://10.0.0.8:8776/v1/$(tenant_id)s'
    +-------------+---------------------------------------+
    |   Property  |                 Value                 |
    +-------------+---------------------------------------+
    |   adminurl  | http://10.0.0.8:8776/v1/$(tenant_id)s |
    |      id     |    afc967da2a1b400792dc9c51c4fa728a   |
    | internalurl | http://10.0.0.8:8776/v1/$(tenant_id)s |
    |  publicurl  | http://10.0.0.8:8776/v1/$(tenant_id)s |
    |    region   |               RegionOne               |
    |  service_id |    2b6252b673d84019aa6b75e702d1b0ab   |
    +-------------+---------------------------------------+

Please note that the urls need to be quoted using the (') character
(single quote) otherwise the shell will interpret the dollar sign ($).

cinder installation and configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Let's now go back to the  **volume-node** and install the cinder
pachages::

    root@volume-node:~# apt-get install -y cinder-api cinder-scheduler cinder-volume iscsitarget open-iscsi iscsitarget-dkms python-mysqldb  python-cinderclient

Ensure that the iscsi module has been installed by the
iscsitarget-dkms package::

    root@volume-node:~# dkms status
    iscsitarget, 1.4.20.2, 3.5.0-37-generic, x86_64: installed

In file ``/etc/cinder/api-paste.ini`` edit the **filter:authtoken**
section and ensure that information about the keystone user and
endpoint are corret::

    [filter:authtoken]
    paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
    service_protocol = http
    service_host = 10.0.0.6
    service_port = 5000
    auth_host = 10.0.0.4
    auth_port = 35357
    auth_protocol = http
    admin_tenant_name = service
    admin_user = cinder
    admin_password = cinderServ
    signing_dir = /var/lib/cinder

The  ``/etc/cinder/cinder.conf`` file instead contains information
about the MySQL and RabbitMQ host, and information about the iscsi and
LVM configuration. A minimal configuration file will contain::

    [DEFAULT]
    rootwrap_config=/etc/cinder/rootwrap.conf
    sql_connection = mysql://cinderUser:cinderPass@10.0.0.3/cinder
    api_paste_config = /etc/cinder/api-paste.ini
    rabbit_host=10.0.0.3
    iscsi_helper=ietadm
    volume_name_template = volume-%s
    volume_group = cinder-volume
    verbose = True
    auth_strategy = keystone
    iscsi_ip_address=10.0.0.8

Populate the cinder database::

    root@volume-node:~# cinder-manage db sync

Restart cinder services::

    root@volume-node:~# restart cinder-api
    cinder-api start/running, process 1625

    root@volume-node:~# restart cinder-volume
    cinder-volume start/running, process 1636

    root@volume-node:~# restart cinder-scheduler
    cinder-scheduler start/running, process 1655

The file  ``/etc/default/iscsitarget`` controls the startup of the
iscsi daemon, it has to contain this line::

    ISCSITARGET_ENABLE=true

(please note that it is case sensitive)

Ensure that the iscsi services are running::

    root@volume-node:~# service iscsitarget start
    root@volume-node:~# service open-iscsi start

In our configuration (cfr. ``/etc/cinder/cinder.conf`` file) cinder
will provide iscsi volumes starting from LVM volumes created within
the volume group called ``cinder-volume``. Cinder is able to create
LVM volumes by itself, but we have to provide a volume group with this
name.

The virtual machine we created has one more disk (``/dev/vdb``) which
we will use. You can either partition this disk and use those
partitions to create the volume group, or use the whole disk. In our
setup, to keep things simple, we will use the whole disk, so we are
going to:

Create a physical device on the ``/dev/vdb`` disk::

    root@volume-node:~# pvcreate /dev/vdb
      Physical volume "/dev/vdb" successfully created

create a volume group called **cinder-volume** on it::

    root@volume-node:~# vgcreate cinder-volume /dev/vdb 
      Volume group "cinder-volume" successfully created

check that the volume group has been created::

    root@volume-node:~# vgdisplay 
      --- Volume group ---
      VG Name               cinder-volume
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
            
Testing cinder
~~~~~~~~~~~~~~

Cinder command line tool also allow you to pass user, password, tenant
name and authentication url both via command line options or
environment variables. In order to make the commands easier to read we
are going to set the environment variables and run cinder without
options::

    root@volume-node:~# export OS_USERNAME=cinder
    root@volume-node:~# export OS_PASSWORD=cinderServ
    root@volume-node:~# export OS_TENANT_NAME=service
    root@volume-node:~# export OS_AUTH_URL=http://10.0.0.4:5000/v2.0

As usual you can set the environment variables OS_USERNAME

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

Since the volume is not used by any VM, we can delete it with the ``cinder delete`` command::

    root@volume-node:~# cinder delete 1d1a75eb-1493-4fda-8eba-fa851cfd5040

Deleting the volume can take some time::

    root@volume-node:~# cinder list
    +--------------------------------------+----------+--------------+------+-------------+----------+-------------+
    |                  ID                  |  Status  | Display Name | Size | Volume Type | Bootable | Attached to |
    +--------------------------------------+----------+--------------+------+-------------+----------+-------------+
    | 1d1a75eb-1493-4fda-8eba-fa851cfd5040 | deleting |     test     |  1   |     None    |  false   |             |
    +--------------------------------------+----------+--------------+------+-------------+----------+-------------+


``api-node``
------------

Nova
++++

Nova is composed to a variety of services

Now that he have installed a lot of infrastructure, it is time to actually get the 
compute part of our cloud up and running - otherwise, what good would it be?

In this section we are going to install and configure
the OpenStack nova services. 

First move to the **db-node** and create the database::

    root@db-node:~# mysql -u root -p
    
    mysql> CREATE DATABASE nova;
    mysql> GRANT ALL ON nova.* TO 'novaUser'@'%' IDENTIFIED BY 'novaPass';

Go **back to the api-node** and install::

    root@api-node:~# apt-get install nova-api nova-cert novnc nova-consoleauth nova-scheduler nova-novncproxy nova-doc nova-conductor

which are the nova components needed.


We have to create now an endpoint for the OpenStack nova service. This is to be
done on the **auth-node**, so please login there and follow the steps:

* Create the nova user and add the role by doing.

Get the service tenant id::

    root@auth-node:~# keystone tenant-get service
    +-------------+---------------------------------------+
    |   Property  |              Value                    |
    +-------------+---------------------------------------+
    | description |                                       |
    |   enabled   |               True                    |
    |      id     |   6e0864cd071c4806a05b32b1f891d4e0    |
    |     name    |             service                   |
    +-------------+---------------------------------------+


After that create the user and add the role using the service id::

    root@auth-node:~# keystone user-create --name=nova --pass=novaServ --tenant-id 6e0864cd071c4806a05b32b1f891d4e0
    +----------+----------------------------------+
    | Property |              Value               |
    +----------+----------------------------------+
    |  email   |                                  |
    | enabled  |               True               |
    |    id    | 1313793a3d1b452ca9558f53fe0db69c |
    |   name   |               nova               |
    | tenantId | 6e0864cd071c4806a05b32b1f891d4e0 |
    +----------+----------------------------------+
    
    root@auth-node:~# keystone user-role-add keystone user-role-add --tenant service --user nova --role admin

* Create the nova and ec2 services by doing::


    root@auth-node:~# keystone service-create --name nova --type compute --description 'Compute Service of OpenStack'
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |    OpenStack Compute Service     |
    |      id     | 175320193f8e4122b8f21bd2b454b672 |
    |     name    |               nova               |
    |     type    |             compute              |
    +-------------+----------------------------------+
    
    
    root@auth-node:~# keystone service-create --name ec2 --type ec2 --description 'EC2 service of OpenStack'
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |     EC2 service of OpenStack     |
    |      id     | 5e362e6bf75642259276d6c29a2b6749 |
    |     name    |               ec2                |
    |     type    |               ec2                |
    +-------------+----------------------------------+


* Create the endpoint:

First get the nova and ec2 service ids:

::

    root@auth-node:~# keystone service-list
    +----------------------------------+--------+---------+----------------------------+
    |                id                |  name  |   type  |        description         |
    +----------------------------------+--------+---------+----------------------------+
    | 5e362e6bf75642259276d6c29a2b6749 |  ec2   |   ec2   |  EC2 service of OpenStack  |
    | 4edbbac249de4cd7914fde693b0f404c | glance |  image  | Image Service of OpenStack |
    | 175320193f8e4122b8f21bd2b454b672 |  nova  | compute | OpenStack Compute Service  |
    +----------------------------------+--------+---------+----------------------------+

we have to create two end-points: ec2 and compute
        
In order to do that for the nova service please do:

::

    root@auth-node:~# keystone endpoint-create --region RegionOne --service-id 175320193f8e4122b8f21bd2b454b672
      --publicurl 'http://10.0.0.6:8774/v2/$(tenant_id)s' --adminurl 'http://10.0.0.6:8774/v2/$(tenant_id)s' 
      --internalurl 'http://10.0.0.6:8774/v2/$(tenant_id)s'
    
    +-------------+---------------------------------------+
    |   Property  |                 Value                 |
    +-------------+---------------------------------------+
    |   adminurl  | http://10.0.0.6:8774/v2/$(tenant_id)s |
    |      id     |    24cd124974e7441da4557143865ea6de   |
    | internalurl | http://10.0.0.6:8774/v2/$(tenant_id)s |
    |  publicurl  | http://10.0.0.6:8774/v2/$(tenant_id)s |
    |    region   |               RegionOne               |
    |  service_id |    175320193f8e4122b8f21bd2b454b672   |
    +-------------+---------------------------------------+

And for the ec2 service instead:

::

    root@auth-node:~# keystone endpoint-create --region RegionOne --service-id 5e362e6bf75642259276d6c29a2b6749 \
       --publicurl 'http://10.0.0.6:8773/services/Cloud' --adminurl 'http://10.0.0.6:8773/services/Admin'
       --internalurl 'http://10.0.0.6:8773/services/Cloud'
       
    +-------------+-------------------------------------+
    |   Property  |                Value                |
    +-------------+-------------------------------------+
    |   adminurl  | http://10.0.0.6:8773/services/Admin |
    |      id     |   f6df5c37d2644d5498dd81ddbc70882b  |
    | internalurl | http://10.0.0.6:8773/services/Cloud |
    |  publicurl  | http://10.0.0.6:8773/services/Cloud |
    |    region   |              RegionOne              |
    |  service_id |   5e362e6bf75642259276d6c29a2b6749  |
    +-------------+-------------------------------------+

* Adapt the ``/etc/nova/api-paste.ini`` file on the **api-node** with:

::

    [filter:authtoken]
    paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
    auth_host = 10.0.0.4
    auth_port = 35357
    auth_protocol = http
    admin_tenant_name = service
    admin_user = nova
    admin_password = novaServ
    signing_dir = /tmp/keystone-signing
    # Workaround for https://bugs.launchpad.net/nova/+bug/1154809
    auth_version = v2.0

* Adapt the ``/etc/nova/nova.conf`` file with:

::

    [DEFAULT]
    logdir=/var/log/nova
    state_path=/var/lib/nova
    lock_path=/run/lock/nova
    verbose=True
    api_paste_config=/etc/nova/api-paste.ini
    compute_scheduler_driver=nova.scheduler.simple.SimpleScheduler
    rabbit_host=10.0.0.3
    nova_url=http://10.0.0.6:8774/v1.1/
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
    vncserver_proxyclient_address=10.0.0.6
    vncserver_listen=0.0.0.0

    #Metadata
    service_quantum_metadata_proxy = True
    quantum_metadata_proxy_shared_secret = helloOpenStack

    # Compute #
    compute_driver=libvirt.LibvirtDriver

    # Cinder #
    volume_api_class=nova.volume.cinder.API
    osapi_volume_listen_port=5900

* Sync the nova database::

    root@api-node:~# nova-manage db sync 
      
      
* Restart all the nova services in ``/etc/init.d/nova-*``

* Check nova services:

::

    root@api-node:~# nova-manage service list

``netowrk-node``
----------------

nova-network
++++++++++++

Networking in OpenStack is quite complex, you have multiple options
and you currently have two different implementation to get the network
working.

The newer, feature rich but still unstable is called **Neutron**
(previously known as **Quantum**, they renamed it because of Trademark
issues). We are not going to implement this solution because it is:

1) very complex
2) quite unstable
3) not actually needed for a basic setup

The old, stable, very well working solution is **nova-network**, which
is the solution we are going to implement.

Let's just recap how the networking works in OpenStack

FIXME: add a blablabla on networking

Let's start by installing the needed software::

    root@network-node:~# apt-get install -y nova-network

Network configuration on the **network-node** will look like:

+-------+------------------+-----------------------------------------------------+
| iface | network          | usage                                               |
+=======+==================+=====================================================+
| eth0  | 192.168.122.0/24 | ip assigned by kvm, to access the internet          |
+-------+------------------+-----------------------------------------------------+
| eth1  | 10.0.0.0/24      | internal network                                    |
+-------+------------------+-----------------------------------------------------+
| eth2  |                  | public network                                      |
+-------+------------------+-----------------------------------------------------+
| eth3  | 0.0.0.0          | bridge connected to the internal network of the VMs |
+-------+------------------+-----------------------------------------------------+

The last interface (eth3) is managed by **nova-network** itself, so we
only have to create a bridge and attach eth3 to it. This is done on
ubuntu by editing the ``/etc/network/interface`` file and ensuring
that the following content is there::

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
afterwards. To force linux to re-read the file you can run::

    root@network-node:~# sysctl -p /etc/sysctl.conf
    net.ipv4.ip_forward = 1

Add the following lines to the ``/etc/nova/nova.conf`` file for the network setup::

      # NETWORK
      network_manager=nova.network.manager.FlatDHCPManager
      force_dhcp_release=True
      dhcpbridge=/usr/bin/nova-dhcpbridge
      dhcpbridge_flagfile=/etc/nova/nova.conf
      firewall_driver=nova.virt.libvirt.firewall.IptablesFirewallDriver

      flat_network_bridge=br100
      fixed_range=10.99.0.0/22
      
      flat_network_dhcp_start=10.99.0.10
      
      connection_type=libvirt
      network_size=1022
      
      # For floating IPs
      auto_assign_floating_ip=true
      default_floating_pool=public
      public_interface=eth2

..
         # Not sure it's needed
         # libvirt_use_virtio_for_bridges=True
         vlan_interface=eth2
         flat_interface=eth2

Restart the nova-network service with::

    root@network-node:~# restart nova-network


Nova network creation
~~~~~~~~~~~~~~~~~~~~~

You have to create manually a private internal network on the main node::

       root@network-node:~# nova-manage network create --fixed_range_v4 10.99.0.0/22 --num_networks 1 --network_size 1000 --bridge br100 --bridge_interface eth3 net1

FIXME: set the public ip range for the floating IPs

Create a floating public network::

       root@network-node:~# nova-manage floating create --ip_range <Public_IP>/NetMask --pool=public

..
   Enable the security groups for ssh and icmp on (needed for the public network)::

          root@network-node:~# nova secgroup-add-role default icmp -1 -1 0.0.0.0/0
          root@network-node:~# nova secgroup-add-rule default tcp 22 22 0.0.0.0/0


``compute-1`` and ``compute-2``       
-------------------------------

Nova-compute (does not need an endpoint)
++++++++++++++++++++++++++++++++++++++++

Install grizzly repository on the compute node. Install and configure KVM

* Edit the qemu.conf with the needed options as specified in the tutorial (uncomment cgrout, ... )
* Edit libvirt.conf (follow the tutorial)
* Edit libvirt-bin.conf (follow the tutorial)
* Modify l'API in api-paste.ini in order to abilitate access to keystone.

Software installation
~~~~~~~~~~~~~~~~~~~~~

Since we cannot use KVM because our compute nodes are virtualized and
the host node does not support *nested virtualization*, we install
**qemu** instead of **kvm**::

    root@compute-1 # apt-get install -y nova-compute-qemu

This will also install the **nova-compute** package.

..
   Check that the ``ebtables`` package is installed::

       root@compute-1 # dpkg -l ebtables

Network configuration
~~~~~~~~~~~~~~~~~~~~~

Configure the internal bridge. In order to do that you will need to
login using the console. 

Open virt-manager, login as root and shutdown the *network*::

    root@compute-1 # /etc/init.d/networking stop

From the ``/etc/network/interfaces`` file you have to remove the old
lines related to the internal ``eth1`` network and replace them with
the following lines, which will configure a bridge called **br100**
and attach the **eth1** physical interface to it::

    #auto eth1
    #iface eth1 inet static
    # address 10.0.0.20
    # netmask 255.255.255.0

    auto br100
    iface br100 inet static
        address      10.0.0.20
        netmask      255.255.255.0
        pre-up ifconfig eth1 0.0.0.0 
        bridge-ports eth1
        bridge_stp   off
        bridge_fd    0

(This is valid for **compute-1**, please update the IP address when configuring **compute-2**)

Now you can setup again the network::

    root@compute-1 # /etc/init.d/networking start

The **br100** interface should now be up&running::

    root@compute-1 # ifconfig br100
    br100     Link encap:Ethernet  HWaddr 52:54:00:c7:1a:7b  
              inet addr:10.0.0.20  Bcast:0.0.0.0  Mask:255.255.255.255
              inet6 addr: fe80::5054:ff:fec7:1a7b/64 Scope:Link
              UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
              RX packets:6 errors:0 dropped:0 overruns:0 frame:0
              TX packets:6 errors:0 dropped:0 overruns:0 carrier:0
              collisions:0 txqueuelen:0 
              RX bytes:272 (272.0 B)  TX bytes:468 (468.0 B)

The following command will show you the physical interfaces associated
to the **br100** bridge::

    root@compute-1 # brctl show
    bridge name	bridge id		STP enabled	interfaces
    br100		8000.525400c71a7b	no		eth1

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
    # novncproxy_base_url=http://10.0.0.6:6080/vnc_auto.html
    # novncproxy_port=6080
    vncserver_proxyclient_address=10.0.0.20
    vncserver_listen=0.0.0.0

    # Compute #
    compute_driver=libvirt.LibvirtDriver

    network_host=10.0.0.7

..
   On the ``/etc/nova/api-paste.conf`` we have to put the information
   on how to access the keystone authentication service. Ensure then that
   the following information are present in this file::

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

Final check
~~~~~~~~~~~

After restarting the **nova-compute** service::

    root@compute-1 # restart nova-compute

you should be able to see the compute node from the **api-node**::

    root@api-node:~# nova-manage service list
    Binary           Host                                 Zone             Status     State Updated_At
    nova-cert        api-node                             internal         enabled    :-)   2013-08-13 13:43:35
    nova-conductor   api-node                             internal         enabled    :-)   2013-08-13 13:43:31
    nova-consoleauth api-node                             internal         enabled    :-)   2013-08-13 13:43:35
    nova-scheduler   api-node                             internal         enabled    :-)   2013-08-13 13:43:35
    nova-compute     compute-1                            nova             enabled    :-)   None      



Nova and Nova-compute: network configuration
++++++++++++++++++++++++++++++++++++++++++++

Networking inside OpenStack / Grizzly is provided by the nova-network component. Here bellow is what has to be done in order to configure networking properly on OpenStack.

General
~~~~~~~


On the node running nova-network we need at least three physical network interfaces. In our current testing configuration we have:

* eth0 for the 840 VLAN (physical network conf.)
* eth1 for the VMs (bridge)
* eth2 for the pubblic (Floating IPs and NAT).

A bridge is needed for the VMs. The host running nova-network manages: NATTING, DHCP, Floating IPs.


Horizon
+++++++

After an "apt-get install..." the service should work out of the box by accessing: http://api-node/horizon

Workflow for a VM Creation
--------------------------

Horizon asks Keystone for an authorization.
Keystone is then checking on what the users/tenants are "supposed" to see (in terms of images, quotes, etc). Working nodes are periodically writing their status in the nova-database. When a new request arrives it is processed by the nova-scheduler which writes in the nova-database when a matchmaking with a free resource has been accomplished. On the next poll when the resource reads the nova-database it "realises" that it is supposed to start a new VM. nova-compute writes then the status inside the nova database.

Different sheduling policy and options can be set in the nova's configuration file.

Recap
-----

Small recap on what has to be done for a sevice installation:

* create database,
* create user for the this database in way that in can connects and configure the service.
* create user for the service which has role admin in the tenant service
* define the endpoint


