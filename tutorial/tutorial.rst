Welcome to the gridka-school wiki!
==================================

This quide is to be used as reference for the installation of the
OpenStack Grizzly. It does not pretend to be complete, its main aim is
to define a skeleton for the future workshop to take place during the
GridKa School in Karlsruhe 26-30 August this summer.

As starting reference has been used the following `tutorial <https://github.com/mseknibilel/OpenStack-Grizzly-Install-Guide/blob/master/OpenStack_Grizzly_Install_Guide.rst>`_.

As a lot of inconsistencies have been found we added and edited what we considered necessary for the correct functionallity of the OpenStack software.

The official Grizzly tutorial can be found `here <http://docs.openstack.org/grizzly/openstack-compute/install/apt/content/>`_.

Extended notes taken during the hands-on session on Grizzly's installation done by Antonio + some howto:

OpenStack overview
------------------

The main component is Keystone. All the other services use Keystone for the authentication by the means of tokens. The authentication is done through username and password on the MySQL database which gives back the token to the service which has made the request.

* RabbitMQ + MySQL (those two should allow HA of OpenStack?)

* Horizon is the Web Interface: it must installed on the same machine hosting nova-api.

* It is not mandatory to have all the services on the same host. Different databases can be installed/used.

* Cinder services allows to mount additionl volumes on running VM. The volumes are persistent and are not cancelled once the VM is terminated. A VM can be started from a Volume.

* TO BE COMPLETED with the rest of the services

Workflow for a VM Creation
--------------------------

Horizon asks Keyston for an authorization.Keystone is then checking on what the users/tenants are "supposed" to see (in terms of images, quotes, etc). Working nodes are periodically writing their status in the nova-database. When a new request arrives it is processed by the nova-scheduler which writes in the nova-database when a matchmaking with a free resource has been accomplished. On the next poll when the resource reads the nova-database it "realises" that it is supposed to start a new VM. nova-compute writes then the status inside the nova database.

Different sheduling policy and options can be set in the nova's configuration file.

Installation:
-------------

* MySQL + RabbitMQ,
* Keyston
* Glance, Cinder.
* Nova-* (except nova-compute)
* Nova-compute

Note: on each service installed (except for nova-compute) a new endpoint has to be added in keystone. Zone can be used for the services (to be further explainded)

MySQL
+++++

::

     apt-get install mysql-server python-mysqldb 

mysqld listens on the 3306 but the IP is set to 127.0.0.1. This has to be changes so we can make the server accessible from the private nodes' network (192.168.160.45)

RabbitMQ
++++++++

Does NOT need a specific configuration. Should run out of the box. Antonio is not sure if the queues need some setup

NTP
+++

Install NTP.

Keystone
++++++++

On Keyston we need to configure the MySQL database for the authentication/authorization of the services and endpoints. Keystone management is done through the following commands: "keystone-manage" and "keystone".

We have to (this list is TO BE better explained and described):

Create a keystone database user and grant him access to the database.

::

    # keystone-mange db_sync (it feeds the DB with the needed information)

Define a token inside keystone.conf (better a random string) which is used for the administartion afterwards. The port to be used for the administartion ( for potentialy destructive command ) is: 35357, the one for regular administration is 5000.

* Create the "admin" and "service" tenants (not mandatory??).
* Create the "admin" user.
* Define roles (see the tutorial).
* Define the endpoints (usually it is a good practice to do that when a new service is enabled).
* At the end the relations between tenants, users and roles has to be done.

Glance
++++++

For the glance service installation to be done as follows:

* apt-get install ...
* mysql: create glance database (databases can be separated: not necessary on the same machine)
* put endpoint information only in /etc/glance/paste files
* user glance have to be set with admin role in the tenant service (this is valid for all the services)
* glance db_sync
* create endpoint on Keystone

Nova
++++

* apt-get install ...
* Needs two endpoints: EC2 and compute
* Inside api-paste.ini configure access to Keystone
* Inside nova.conf configure: compute_scheduler_driver, nova_url, sql_connection
* Imaging Service: put imaging server: 192.168.160.45:9292?
* Restart services

Nova-compute (does not need an endpoint)
++++++++++++++++++++++++++++++++++++++++

Install grizzly repository on the compute node. Install and configure KVM

* Edit the qemu.conf with the needed options as specified in the tutorial (uncomment cgrout, ... )
* Edit libvirt.conf (follow the tutorial)
* Edit libvirt-bin.conf (follow the tutorial)
* apt-get install nova-compute-kvm
* Modify l'API in api-paste.ini in order to abilitate access to keystone.

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

Add the network bridge in /etc/network/interfaces::

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

Add the following lines to the /etc/nova/nova.conf file for the network setup::

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

No network inforamtion is needed in the /etc/nova/nova.conf file on the compute node.

Nova network creation
~~~~~~~~~~~~~~~~~~~~~

You have to create manually a private internal network on the main node::

       # nova-manage network create --fixed_range_v4 10.65.4.0/22 --num_networks 1 --network_size 1000 --bridge br100 --bridge_interface eth1 net1

Create a floating public network::

       # nova-manage floating create --ip_range <Public_IP>/NetMask --pool=public

Enable the security groups for ssh and icmp on (needed for the public network)::

       # nova secgroup-add-role default icmp -1 -1 0.0.0.0/0
       # nova secgroup-add-rule default tcp 22 22 0.0.0.0/0

Cinder
++++++

The OpenStack Block Storage API allows manipulation of volumes, volume types (similar to compute flavors) and volume snapshots. Bellow you can find the information on how to install and configure cinder using a local VG.

* Create storage space for Cinder (TO BE DEFINES)

* Install the needed packages::

        # apt-get install -y cinder-api cinder-scheduler cinder-volume iscsitarget open-iscsi iscsitarget-dkms

* Create User and enable it in the admin tenant::

        # keystone --os-username=admin --os-tenant-name=admin --os-password=keystoneqwerty --os-auth url=http://192.168.160.45:35357/v2.0 user-create --name=cinder --pass=cinderqwerty --tenant-id=a908ccc0bafe4c40a4cb060e20897a75 --email=info@gc3.uzh.ch 
        # keystone --os-username=admin --os-tenant-name=admin --os-password=keystoneqwerty --os-auth-url=http://192.168.160.45:35357/v2.0 user-role-add --tenant-id a908ccc0bafe4c40a4cb060e20897a75 --user-id c41e0a304e0345b5babe2105734ef929 --role-id 677543c6020844788ec3b232798a1390

* Add the cinder service and create and end point::

        # keystone --os-username=admin --os-tenant-name=admin --os-password=keystoneqwerty --os-auth-url=http://192.168.160.45:35357/v2.0 service-create --name cinder --type volume --description 'OpenStack Volume Service'
        # keystone --os-username=admin --os-tenant-name=admin --os-password=keystoneqwerty --os-auth-url=http://192.168.160.45:35357/v2.0 endpoint-create --region RegionOne --service-id=6ef7129fb15c46b79e70160dca99f3dc --publicurl 'http://192.168.160.45:8776/v1/$(tenant_id)s' --adminurl 'http://192.168.160.45:8776/v1/$(tenant_id)s' --internalurl 'http://192.168.160.45:8776/v1/$(tenant_id)s' 

* Enable iSCSI and restart iSCSI services 

* Create Cinder DB, modify api-paste.ini and enable access to keystone, configure end-point

Horizon
+++++++

After an "apt-get install..." the service should work out of the box by accessing: http://IP/horizon

Recap
-----

Small recap on what has to be done for a sevice installation:

* create database,
* create user for the this database in way that in can connects and configure the service.
* create user for the service which has role admin in the tenant service
* define the endpoint


