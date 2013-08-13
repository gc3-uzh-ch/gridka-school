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


How to access the physical nodes
++++++++++++++++++++++++++++++++

In order to access the different virtual machines and start working on the 
configuration of OpenStack services listed above you will have to first login 
on one of the nodes assigned to your group by doing:

::

        ssh user@gks-number.domain.example.com -p NUMBER


Virtual Machines
++++++++++++++++

From that bastion node you can now login to the variuos VMs by doing:

:: 

        ssh gridka@<service-name>

The *service-name* string has to be replaced with one of the following values:

* **db-node**, 
* **auth-node**, 
* **api-node**, 
* **network-node**, 
* **image-node**, 
* **volume-node**, 
* **compute-1-node**, 
* **compute-2-node**

where each of the listed values corresponds to a specific VM hosting the OpenStack
services as explained in the Tutorial Overview section. 

Network Setup
+++++++++++++

TODO: explain the network configuration of the VMs etc 


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


``all nodes installation``
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

* Install the NTP servic::

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
be changes in order to make the server accessible from nodes one
private network (10.0.0.0/24)

::
    root@all-nodes # sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf
    root@all-nodes # service mysql restart


RabbitMQ
++++++++

Install the RabbitMQ software:

::
    root@db-node # apt-get install -y rabbitmq-server
        

RabbitMQ does not need any specific configuration. Please keep the
connection to the db-node open as we will need to operate on it
briefly.


``auth-node``
-------------

Keystone
++++++++

* Create the Keystone Databese on the **db-node** by doing::

    root@db-node # mysql -u root -p
    mysql> CREATE DATABASE keystone;
    mysql> GRANT ALL ON keystone.* TO 'keystoneUser'@'%' IDENTIFIED BY 'keystonePass';

Go back to the **auth-node** and start configuring keystone.
        
* Install keystone by doing::

    root@auth-node # apt-get install keystone python-mysqldb -y
        
* Change the DB reference in the ``/etc/keystone/keystone.conf``. For
  doing that you have to replace the connection starting string with::

    connection = mysql://keystoneUser:keystonePass@10.0.0.3/keystone
        
* Restart the keystone servce::

    root@auth-node # service keystone restart
        
* Popolate the keystone database::

    root@auth-node # keystone-manage db_sync
    
which will populate the database with the needed information. 

* Create Tenants, Roles and Users

Before starting you have to setup two environment virables 
needed for correct functionallity of the keystone service::

    root@auth-node # export SERVICE_TOKEN="ADMIN"
    root@auth-node # export SERVICE_ENDPOINT="http://10.0.0.4:35357/v2.0"

Now create the following tenants: **admin** and **service**::

    root@auth-node # keystone tenant-create --name=admin
    root@auth-node # keystone tenant-create --name=service

Create the **admin** user::

    root@auth-node # keystone user-create --name=admin --pass=keystoneAdmin
        
Go on by creating the different roles::

    root@auth-node # keystone role-create --name=admin
    root@auth-node # keystone role-create --name=KeystoneAdmin
    root@auth-node # keystone role-create --name=KeystoneServiceAdmin
    root@auth-node # # It is used by Horizon and Swift
    root@auth-node # keystone role-create --name=Member
        
Assign Roles::

    root@auth-node # keystone user-role-add --user admin --role admin --tenant admin 
    root@auth-node # keystone user-role-add --user admin --role KeystoneAdmin --tenant admin 
    root@auth-node # keystone user-role-add --user admin --role KeystoneServiceAdmin --tenant admin

        

You can change the TOKEN string defined in the
``/etc/keystone/keystone.conf`` to and arbitrary random string. We
will use: "ADMIN_TOKEN". Please restart keystone when done.


For not having to export the credential variables each time you can create a file called 
*keystone_creds* and source it. 

::

    root@auth-node # export SERVICE_TOKEN="ADMIN_TOKEN"
    root@auth-node # export SERVICE_ENDPOINT="http://10.0.0.4:35357/v2.0"

Now we have to create keystone service and endpoint:

* First create the keystone service:

::

    root@auth-node #         keystone service-create --name keystone --type identity --description 'OpenStack Identity'

    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |        OpenStack Identity        |
    |      id     | a92e4230026d4e0a9f16c538781f85a4 |
    |     name    |             keystone             |
    |     type    |             identity             |
    +-------------+----------------------------------+
        
* After that create the keystone endpoint by doing:

::


    root@auth-node # keystone endpoint-create --region $KEYSTONE_REGION --service-id a92e4230026d4e0a9f16c538781f85a4
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

where the **--service-id** is the one corresponding to the keystone service created in the previous step. 


* Restart the keystone servce::

    root@auth-node # service keystone restart  
        

``image-node``
-------------

Glance
++++++

In this section we are going to install and configure the glance imaging service. 

First move to the **db-node** and create the database::

    root@image-node # mysql -u root -p
    mysql> CREATE DATABASE glance;
    mysql> GRANT ALL ON glance.* TO 'glanceUser'@'%' IDENTIFIED BY 'glancePass';

Go **back to the image-node** and install glance then:

::

    root@image-node # apt-get install glance
        
Create glance service and endpoint:

We have to create an endpoint for the imaging service. 
This is to be done on the **auth-node**, so please login 
there and follow the steps:

* Setup the environment::

    root@image-node # export MYSQL_USER=keystoneUser
    root@image-node # export MYSQL_DATABASE=keystone
    root@image-node # export MYSQL_HOST=10.0.0.3
    root@image-node # export MYSQL_PASSWORD=keystonePass
        
* Source the kyestone_creds file you've created previously::

    root@image-node # source keystone_creds
        
* Export the Keystone region variable::

    root@image-node # export KEYSTONE_REGION=RegionOne
        
        
* Create the glance user and add the role by doing.

First get the service tenant id::

    root@image-node # keystone tenant-get service
    +-------------+---------------------------------------+
    |   Property  |              Value                    |
    +-------------+---------------------------------------+
    | description |                                       |
    |   enabled   |               True                    |
    |      id     |   6e0864cd071c4806a05b32b1f891d4e0    |
    |     name    |             service                   |
    +-------------+---------------------------------------+


Once you have it create the user and add the role::

    root@image-node # keystone user-create --name=glance --pass=glanceServ --tenant-id 6e0864cd071c4806a05b32b1f891d4e0
    +----------+----------------------------------+
    | Property |              Value               |
    +----------+----------------------------------+
    |  email   |                                  |
    | enabled  |               True               |
    |    id    | fc71fbf5814d434097d2f873db364797 |
    |   name   |              glance              |
    | tenantId | 6e0864cd071c4806a05b32b1f891d4e0 |
    +----------+----------------------------------+        
    
    root@image-node # keystone user-role-add --tenant service --user glance --role admin

* Create the image service by doing::

    root@image-node # keystone service-create --name glance --type image --description 'Image Service of OpenStack'


* Create the endpoint:

First get the glance service id::

    root@image-node # keystone service-list
    +----------------------------------+--------+-------+----------------------------+
    |                id                |  name  |  type |        description         |
    +----------------------------------+--------+-------+----------------------------+
    | 4edbbac249de4cd7914fde693b0f404c | glance | image | Image Service of OpenStack |
    +----------------------------------+--------+-------+----------------------------+
        
Once you have it, add the new end-point:

::

    root@image-node # keystone endpoint-create --region $KEYSTONE_REGION --service-id 4edbbac249de4cd7914fde693b0f404c 
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


Turn back to the **image-node** and follow the next steps:


* Open ``/etc/glance/glance-api-paste.ini`` file and edit the
  **filter:authtoken** section::


    [filter:authtoken]
    paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
    delay_auth_decision = true
    auth_host = 10.0.0.4
    auth_port = 35357
    auth_protocol = http
    admin_tenant_name = service
    admin_user = glance
    admin_password = glanceServ

* Open ``/etc/glance/glance-registry-paste.ini`` file and edit the
  **filter:authtoken** section::


    [filter:authtoken]
    paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
    auth_host = 10.0.0.4
    auth_port = 35357
    auth_protocol = http
    admin_tenant_name = service
    admin_user = glance
    admin_password = serviceServ

* Open ``/etc/glance/glance-api.conf`` file and edit::

    sql_connection = mysql://glanceUser:glancePass@10.0.0.4/glance

and

::


    [paste_deploy]
    flavor = keystone

* Open ``/etc/glance/glance-registry.conf`` file and edit::

    sql_connection = mysql://glanceUser:glancePass@10.0.0.4/glance

and

::

    [paste_deploy]
    flavor = keystone

* Restart the glance-* services:

::


    root@image-node # service glance-api restart
    root@image-node # service glance-registry restart

* Sync the glance database::

    root@image-node # glance-manage db_sync

* Restart again the services::

    root@image-node # service glance-registry restart
    root@image-node #  service glance-api restart

* Test glance

``volume-node``
+++++++++++++++

Cinder
++++++

The OpenStack Block Storage API allows manipulation of volumes, volume
types (similar to compute flavors) and volume snapshots. Bellow you
can find the information on how to install and configure cinder using
a local VG.

First move to the **db-node** and create the database:

::

    root@db-node # mysql -u root -p
    mysql> CREATE DATABASE cinder;
    mysql> GRANT ALL ON cinder.* TO 'cinderUser'@'%' IDENTIFIED BY 'cinderPass';


* Install the cinder packages:

::

    root@volume-node # apt-get install -y cinder-api cinder-scheduler cinder-volume iscsitarget open-iscsi iscsitarget-dkms python-mysqldb  python-cinderclient tgt
        
We have to create an endpoint for the volume service. This is to be
done on the **auth-node**, so please login there and follow the steps:

* Setup the environment:

::   

    root@auth-node # export MYSQL_USER=keystoneUser
    root@auth-node # export MYSQL_DATABASE=keystone
    root@auth-node # export MYSQL_HOST=10.0.0.3
    root@auth-node # export MYSQL_PASSWORD=keystonePass
        
* Source the keystone_creds file you've created previously:

::

    root@auth-node # source keystone_creds
        
* Export the Keystone region variable:

::

    root@auth-node # export KEYSTONE_REGION=RegionOne
        
        
* Create the cinder user and add the role by doing.

First get the service tenant id::

    root@auth-node # keystone tenant-get service
    +-------------+---------------------------------------+
    |   Property  |              Value                    |
    +-------------+---------------------------------------+
    | description |                                       |
    |   enabled   |               True                    |
    |      id     |   6e0864cd071c4806a05b32b1f891d4e0    |
    |     name    |             service                   |
    +-------------+---------------------------------------+

Once you have it create the user and add the role::

    root@auth-node # keystone user-create --name=cinder --pass=cinderServ --tenant-id 6e0864cd071c4806a05b32b1f891d4e0
    +----------+----------------------------------+
    | Property |              Value               |
    +----------+----------------------------------+
    |  email   |                                  |
    | enabled  |               True               |
    |    id    | 3cbe0aab435c435490c200b94908aab2 |
    |   name   |              cinder              |
    | tenantId | 6e0864cd071c4806a05b32b1f891d4e0 |
    +----------+----------------------------------+
    
    root@auth-node # keystone user-role-add --tenant service --user cinder --role admin

* Create the volume service by doing:

::

    root@auth-node # keystone service-create --name cinder --type volume --description 'Volume Service of OpenStack'
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |   Volume Service of OpenStack    |
    |      id     | 2b6252b673d84019aa6b75e702d1b0ab |
    |     name    |              cinder              |
    |     type    |              volume              |
    +-------------+----------------------------------+


* Create the endpoint:

First get the volume service id:

::

    root@auth-node # keystone service-list
    +----------------------------------+----------+----------+-----------------------------+
    |                id                |   name   |   type   |         description         |
    +----------------------------------+----------+----------+-----------------------------+
    | 2b6252b673d84019aa6b75e702d1b0ab |  cinder  |  volume  | Volume Service of OpenStack |
    ........................................................................................
        
Once you have it add the new end-point::


    root@auth-node # keystone endpoint-create --region $KEYSTONE_REGION --service-id 2b6252b673d84019aa6b75e702d1b0ab
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

Once you are done please go back to the **volume-node**.

Configuration.

* Open the ``/etc/cinder/api-paste.ini`` file and edit the
  **filter:authtoken** section like::

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
        
* Open then the ``/etc/cinder/cinder.conf`` and edit the **[DEFAULT]**
  section like this::

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
        
* Sync the database

::

    root@volume-node # cinder-manage db sync
        
Configure volume space services.

* Edit the  ``/etc/default/iscsitarget`` to 'True'.

* Start the services:

::

    root@volume-node # service iscsitarget start
    root@volume-node # service open-iscsi start

* Create a volumegroup and name it cinder-volume

::

    root@volume-node # dd if=/dev/zero of=cinder-volumes bs=1 count=0 seek=2G
    root@volume-node # fdisk /dev/vdb
    #Type as follows:
    n
    p
    1
    ENTER
    ENTER
    w
        
* Create the physical volume first and then the volume groups:

::

    root@volume-node # pvcreate /dev/vdb1
        Physical volume "/dev/vdb1" successfully created
    root@volume-node # vgcreate cinder-volume /dev/vdb1
        Volume group "cinder-volume" successfully created
            

* Restart cinder-{api,scheduler,volume} services

* Verify they are running.

* Test glance:

::

    root@volume-node # cinder --os-username admin --os-password keystoneAdmin
        --os-tenant-name admin --os-auth-url http://10.0.0.4:5000/v2.0 create --display-name test 1
    +---------------------+--------------------------------------+
    |       Property      |                Value                 |
    +---------------------+--------------------------------------+
    |     attachments     |                  []                  |
    |  availability_zone  |                 nova                 |
    |       bootable      |                false                 |
    |      created_at     |      2013-08-08T15:05:56.983964      |
    | display_description |                 None                 |
    |     display_name    |                 test                 |
    |          id         | 4a811e1a-28cc-4354-b8fd-d8857b8e2667 |  
    |       metadata      |                  {}                  |
    |         size        |                  1                   |
    |     snapshot_id     |                 None                 |
    |     source_volid    |                 None                 |
    |        status       |               creating               |
    |     volume_type     |                 None                 |
    +---------------------+--------------------------------------+
        
    root@volume-node # cinder --os-username admin --os-password keystoneAdmin
        --os-tenant-name admin --os-auth-url http://10.0.0.4:5000/v2.0 list
    +--------------------------------------+-----------+--------------+------+-------------+----------+-------------+
    |                  ID                  |   Status  | Display Name | Size | Volume Type | Bootable | Attached to |
    +--------------------------------------+-----------+--------------+------+-------------+----------+-------------+
    | 4a811e1a-28cc-4354-b8fd-d8857b8e2667 | available |     test     |  1   |     None    |  false   |             |
    +--------------------------------------+-----------+--------------+------+-------------+----------+-------------+
                
    root@volume-node # cinder --os-username admin --os-password keystoneAdmin
        --os-tenant-name admin --os-auth-url http://10.0.0.4:5000/v2.0 delete 4a811e1a-28cc-4354-b8fd-d8857b8e2667


``api-node``
++++++++++++

Nova
++++

Now that he have installed a lot of infrastructure, it is time to actually get the 
compute part of our cloud up and running - otherwise, what good would it be?

In this section we are going to install and configure
the OpenStack nova services. 

First move to the **db-node** and create the database::

    root@db-node # mysql -u root -p
    
    mysql> CREATE DATABASE nova;
    mysql> GRANT ALL ON nova.* TO 'novaUser'@'%' IDENTIFIED BY 'novaPass';

Go **back to the api-node** and install:

::

    root@api-node # apt-get install nova-api nova-cert novnc nova-consoleauth nova-scheduler nova-novncproxy nova-doc nova-conductor

which are the nova components needed.


We have to create now an endpoint for the OpenStack nova service. This is to be
done on the **auth-node**, so please login there and follow the steps:

* Setup the environment::

    root@auth-node # export MYSQL_USER=keystoneUser
    root@auth-node # export MYSQL_DATABASE=keystone
    root@auth-node # export MYSQL_HOST=10.0.0.3
    root@auth-node # export MYSQL_PASSWORD=keystonePass
        
* Source the kyestone_creds file you've created previously::

    root@auth-node # source keystone_creds
        
* Export the Keystone region variable::

    root@auth-node # export KEYSTONE_REGION=RegionOne

* Create the glance user and add the role by doing.

Get the service tenant id::

    root@auth-node # keystone tenant-get service
    +-------------+---------------------------------------+
    |   Property  |              Value                    |
    +-------------+---------------------------------------+
    | description |                                       |
    |   enabled   |               True                    |
    |      id     |   6e0864cd071c4806a05b32b1f891d4e0    |
    |     name    |             service                   |
    +-------------+---------------------------------------+


After that create the user and add the role using the service id::

    root@auth-node # keystone user-create --name=nova --pass=novaServ --tenant-id 6e0864cd071c4806a05b32b1f891d4e0
    +----------+----------------------------------+
    | Property |              Value               |
    +----------+----------------------------------+
    |  email   |                                  |
    | enabled  |               True               |
    |    id    | 1313793a3d1b452ca9558f53fe0db69c |
    |   name   |               nova               |
    | tenantId | 6e0864cd071c4806a05b32b1f891d4e0 |
    +----------+----------------------------------+
    
    root@auth-node # keystone user-role-add keystone user-role-add --tenant service --user nova --role admin


* Create the nova and ec2 services by doing::


    root@auth-node # keystone service-create --name nova --type compute --description 'Compute Service of OpenStack'
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |    OpenStack Compute Service     |
    |      id     | 175320193f8e4122b8f21bd2b454b672 |
    |     name    |               nova               |
    |     type    |             compute              |
    +-------------+----------------------------------+
    
    
    root@auth-node # keystone service-create --name ec2 --type ec2 --description 'EC2 service of OpenStack'
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

    root@auth-node # keystone service-list
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

    root@auth-node # keystone endpoint-create --region $KEYSTONE_REGION --service-id 175320193f8e4122b8f21bd2b454b672
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

    root@auth-node # keystone endpoint-create --region $KEYSTONE_REGION --service-id 5e362e6bf75642259276d6c29a2b6749 \
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

    root@api-node # nova-manage db sync 
      
      
* Restart all the nova services in ``/etc/init.d/nova-*``

* Check nova services:

::

    root@api-node # nova-manage service list


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

    root@compute-1 # /etc/init.d/nova-compute restart

you should be able to see the compute node from the **api-node**::

    root@api-node # nova-manage service list
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

On the Main Node
~~~~~~~~~~~~~~~~

Ensure yourself the installation of all the nova components has been done correctly (nova user creation, database, etc) an easy check can be done by issuing::

      # nova service-list 

Check if the "nova-network" component is installed::

      # root@grizzly:/etc/nova# dpkg -l | grep nova-network
      # ii  nova-network                     1:2013.1-0ubuntu2~cloud1             OpenStack Compute - Network manager.

Check if the "vlan bridge-utils" are installed.

::

    ebtables

In order get the issues working you have to install also the "ebtables" software package which administrates the ethernet bridge frame table::

    # apt-get install ebtables 

Enable IP_Forwarding::

    # sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

 To save you from rebooting, perform the following::

    # sysctl net.ipv4.ip_forward=1

Add the network bridge in ``/etc/network/interfaces``::

    auto br100
    iface br100 inet static
        address      0.0.0.0
        pre-up ifconfig eth1 0.0.0.0 
        bridge-ports eth1
        bridge_stp   off
        bridge_fd    0

Once you're done bring up the br100 interface.

::

    # ifconfing br100 up

Add the following lines to the ``/etc/nova/nova.conf`` file for the network setup::

      # NETWORK
      network_manager=nova.network.manager.FlatDHCPManager
      force_dhcp_release=True
      dhcpbridge=/usr/bin/nova-dhcpbridge
      dhcpbridge_flagfile=/etc/nova/nova.conf
      firewall_driver=nova.virt.libvirt.firewall.IptablesFirewallDriver
      flat_network_bridge=br100
      fixed_range=10.65.4.0/22


      # Not sure it's needed
      # libvirt_use_virtio_for_bridges=True
      vlan_interface=eth1
      flat_interface=eth1
      flat_network_dhcp_start=10.65.4.20


      connection_type=libvirt
      network_size=1022


      # For floating IPs
      auto_assign_floating_ip=true
      default_floating_pool=public
      public_interface=eth2

On the Compute Node
~~~~~~~~~~~~~~~~~~~

Check if "nova-compute-kvm" has been installed on the compute node::

      root@node-08-01-02:~# dpkg -l | grep nova-compute
      ii  nova-compute                     1:2013.1-0ubuntu2~cloud1                   OpenStack Compute - compute node
      ii  nova-compute-kvm                 1:2013.1-0ubuntu2~cloud1                   OpenStack Compute - compute node (KVM)

Configure the br100 interface by deleting the part related to the eth0 interface and adding the following lines::

      # The primary network interface
        auto br100
        iface br100 inet dhcp
           bridge_ports eth0
           bridge_stp off
           bridge_fd 0

Once you're done bring up the br100 interface.

::

    # ifconfing br100 up

No network inforamtion is needed in the ``/etc/nova/nova.conf`` file on the compute node.

Nova network creation
~~~~~~~~~~~~~~~~~~~~~

You have to create manually a private internal network on the main node::

       # nova-manage network create --fixed_range_v4 10.65.4.0/22 --num_networks 1 --network_size 1000 --bridge br100 --bridge_interface eth1 net1

Create a floating public network::

       # nova-manage floating create --ip_range <Public_IP>/NetMask --pool=public

Enable the security groups for ssh and icmp on (needed for the public network)::

       # nova secgroup-add-role default icmp -1 -1 0.0.0.0/0
       # nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
       

Horizon
+++++++

After an "apt-get install..." the service should work out of the box by accessing: http://IP/horizon

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


