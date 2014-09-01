Network service - *hard* version - neutron
==========================================

As we did for the api node before staring it is good to quickly check
if the remote ssh execution of the commands done in the `all nodes
installation <basic_services.rst#all-nodes-installation>`_ section
worked without problems. You can again verify it by checking the ntp
installation.

To avoid problems, please shut down the network node before proceedings.

db and keysotne configuration
-----------------------------

neutron is more similar to cinder than to nova-network, so we will
need to configure MySQL, Keystone and rabbit like we did with all the
other services.

First move to the **db-node** and create the database::

    root@db-node:~# mysql -u root -p
    
    mysql> CREATE DATABASE neutron;
    mysql> GRANT ALL ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'gridka';
    mysql> FLUSH PRIVILEGES;
    mysql> exit

Create Neutron user, service and endpoint::

    root@db-node:~# keystone user-create --name=neutron --pass=gridka
    +----------+----------------------------------+
    | Property |              Value               |
    +----------+----------------------------------+
    |  email   |                                  |
    | enabled  |               True               |
    |    id    | 5b92212d919d4db7ae3ef60e33682ad2 |
    |   name   |             neutron              |
    +----------+----------------------------------+
    root@db-node:~# keystone user-role-add --user=neutron --tenant=service --role=admin

    root@db-node:~# keystone service-create --name=neutron --type=network \
         --description="OpenStack Networking Service"

    root@db-node:~# keystone endpoint-create \
         --region RegionOne \
         --service neutron \
         --publicurl http://neutron-node.example.org:9696 \
         --adminurl http://neutron-node.example.org:9696 \
         --internalurl http://10.0.0.9:9696


``neutron-node`` configuration
------------------------------

Neutron si composed of three different kind of services:

* neutron server (API)
* neutron plugin (to deal with different network types)
* neutron agent (some runs on the compute nodes, to provide integration between
  the hypervisor and networks set up by neutron. Others runs on a
  network node, to provide dhcp and routing capabilities)

We are going to install the neutron server and main plugins/agents on
the **neutron-node**, and the needed plugins on the compute
node.

Login on the **neutron-node** and install the following packages::

    root@neutron-node:~# apt-get install python-mysqldb neutron-server \
        neutron-dhcp-agent neutron-plugin-ml2 \
        neutron-plugin-openvswitch-agent neutron-l3-agent

On older releases you may need to also install
``openvswitch-datapath-dkms``, but on Ubuntu 14.04 is not needed.

The network node acts as gateway for the VMs, so we need to enable IP
forwarding. This is done by ensuring that the following lines is
present in ``/etc/sysctl.conf`` file::

    net.ipv4.ip_forward=1
    net.ipv4.conf.all.rp_filter=0
    net.ipv4.conf.default.rp_filter=0

This file is read during the startup, but it is not read
afterwards. To force Linux to re-read the file you can run::

    root@neutron-node:~# sysctl -p /etc/sysctl.conf
    net.ipv4.ip_forward = 1
    net.ipv4.conf.default.rp_filter = 0
    net.ipv4.conf.all.rp_filter = 0

The ``/etc/neutron/neutron.conf`` must be updated to reflect the
RabbitMQ, keystone and MySQL information::

    [DEFAULT]
    # ...

    # RabbitMQ configuration
    rpc_backend = neutron.openstack.common.rpc.impl_kombu
    rabbit_host = 10.0.0.3
    rabbit_password = gridka
    # ...

    # Keystone configuration
    auth_strategy = keystone
    [keystone_authtoken]
    auth_host = 10.0.0.4
    auth_port = 35357
    auth_protocol = http
    admin_tenant_name = service
    admin_user = neutron
    admin_password = gridka
    # ...

    # ...
    # MySQL configuration
    [database]
    connection = mysql://neutron:gridka@10.0.0.3/neutron

Then, we need to also update the configuration related to ML2, the
plugin we are going to use. Again in the
``/etc/neutron/neutron.conf``::

    [DEFAULT]
    # ...

    # ML2 configuration
    core_plugin = ml2
    service_plugins = router
    allow_overlapping_ips = True

We also need to tell Neutron how to contact the `nova-api` service to
communicate any change in the network topology. Again in the
``/etc/neutron/neutron.conf`` file set::

    [DEFAULT]
    # ...

    notify_nova_on_port_status_changes = True
    notify_nova_on_port_data_changes = True
    nova_url = http://10.0.0.6:8774/v2
    nova_admin_username = nova
    nova_admin_tenant_id = 3dff3552489e458c85143a84759db398
    nova_admin_password = gridka
    nova_admin_auth_url = http://10.0.0.4:35357/v2.0


The L3-agent (responsible for routing) reads the
``/etc/neutron/l3_agent.ini`` file instead. Ensure the following
options are set::

    [DEFAULT]
    # ...
    interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver    
    use_namespaces = True

The DHCP agent (responsible for giving private IP addresses to the VMs
using DHCP protocol) reads file
``/etc/neutron/dhcp_agent.ini``. Ensure the following options are set::

    [DEFAULT]
    # ...
    interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver    
    dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
    use_namespaces = True

The metadata agent works as the `nova-metadata-api` daemon we have
seen while configuring `nova-network`. It basically works as a
proxy, contacting the `nova-api` service and gives information about
the running VM.

As you know, when a VM starts it usually execute a program called
`cloud-init`, responsible to contact a well known web server (either
the default gateway or the 169.254.169.254 ip address) and asks for
information about the running instance, including keypairs, root
password, and/or extra data and programs to run (called `userdata`).

Metadata agent reads ``/etc/neutron/metadata_agent.init``
configuration file. Ensure the keystone information are correct, and
create a shared secret that will be shared between the `nova-api`
service and the `metadata-agent`::

    [DEFAULT]
    auth_url = http://10.0.0.4:5000/v2.0
    auth_region = RegionOne
    admin_tenant_name = service
    admin_user = neutron
    admin_password = gridka
    # IP of the nova-api/nova-metadata-api service
    nova_metadata_ip = 10.0.0.6
    metadata_proxy_shared_secret = d1a6195d-5912-4ef9-b01f-426603d56bd2

`nova-api` service
------------------

On the `nova-api` node, you must update the ``/etc/nova/nova.conf``,
adding the shared secret and telling `nova-api` that neutron is used
as a proxy for metadata api::

    [DEFAULT]
    neutron_metadata_proxy_shared_secret = d1a6195d-5912-4ef9-b01f-426603d56bd2
    service_neutron_metadata_proxy = true

Remember to restart the service::

    root@api-node:~# service nova-api restart
    nova-api stop/waiting
    nova-api start/running, process 7830

ML2 plugin configuration
------------------------

ML2 plugin must be configured to use OpenVSwitch to build virtual
networks. In this case we are using GRE tunnels to connect all the
various OpenVSwitch composing the virtual physical layer on top of
which Neutron will build its networks, so edit
``/etc/neutron/plugins/ml2/ml2_conf.ini`` and ensure the following
options are set::

    [ml2]
    # ...
    type_drivers = gre
    tenant_network_types = gre
    mechanism_drivers = openvswitch

        
    [ml2_type_gre]
    # ...
    tunnel_id_ranges = 1:1000

        
    [ovs]
    # ...
    local_ip = 10.0.0.9
    tunnel_type = gre
    enable_tunneling = True

    [securitygroup]
    # ...
    firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
    enable_security_group = True

 
OpenVSwitch
-----------

The package installer should have already created a `br-int` interface
(integration network), used to allow VM-to-VM communication::

    root@neutron-node:~# ovs-vsctl show
    1a05c398-3024-493f-b3c4-a01912688ba4
        Bridge br-int
            fail_mode: secure
            Port br-int
                Interface br-int
                    type: internal
        ovs_version: "2.0.1"

If not, create one with the following command::

    root@neutron-node:~# ovs-vsctl add-br br-int

Then, we need a bridge for external traffic::

    root@neutron-node:~# ovs-vsctl add-br br-ex

The `br-ex` needs to be connected to the  `public network`, in our
case interface `eth2`, therefore you need to run the following command::

    root@neutron-node:~# ovs-vsctl add-port br-ex eth2

After this, the openvswitch configuration should look like::

    root@neutron-node:~# ovs-vsctl show
    1a05c398-3024-493f-b3c4-a01912688ba4
        Bridge br-ex
            Port br-ex
                Interface br-ex
                    type: internal
            Port "eth2"
                Interface "eth2"
        Bridge br-int
            fail_mode: secure
            Port br-int
                Interface br-int
                    type: internal
        ovs_version: "2.0.1"

..
   Depending on your network interface driver, you may need to disable
   Generic Receive Offload (GRO) to achieve suitable throughput
   between your instances and the external network.

   To temporarily disable GRO on the external network interface while testing your environment:

   # ethtool -K INTERFACE_NAME gro off

Please note that the network configuration of the neutron node should
look like (also refer `troubleshooting session <troubleshooting1.rst>`_)::

    auto eth0
    iface eth0 inet static
        address 10.0.0.9
        netmask 255.255.255.0
        network 10.0.0.0
        broadcast 10.0.0.255

    auto eth1
    iface eth1 inet static
        address 172.16.0.9
        netmask 255.255.0.0
        broadcast 172.16.255.255
        gateway 172.16.0.1
        dns-nameservers 141.52.27.35
        dns-search example.org


Also, the `eth2` interface, used by the `br-ext` bridge, must be UP
and in promisc mode::

    root@neutron-node:~# ifconfig eth2 up promisc

This can be done automatically at boot by editing
``/etc/network/interfaces``::

    auto eth2
    iface eth2 inet static
        address 0.0.0.0
        up ifconfig eth2 promisc

Note that we don't assign any IP address, because this is done by
neutron using virtual routers.

..
   Note: the following is only needed if you want to have the external
   interface _and_ the public interface on the same physical network!

   Configure the EXTERNAL_INTERFACE without an IP address and in
   promiscuous mode. Additionally, you must set the newly created br-ex
   interface to have the IP address that formerly belonged to
   EXTERNAL_INTERFACE.

   ``/etc/network/interfaces``::

       auto br-ex
       iface br-ex inet static
            address    172.16.0.9
            network    172.16.0.0
            netmask    255.255.0.0
            broadcast  172.16.255.255
            gateway    172.16.0.1
            up ifconfig eth2 promisc

   (didn't do anything on eth2 but remove IP and shut down the
   interfaces. Let's see what happen)


..
   Note: this is needed when using ovs-plugin instead of ml2-plugin

   Configure the GRE plugin editing
   ``/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini``::

       [ovs]
       tenant_network_type = gre
       tunnel_id_ranges = 1:1000

       # enable_tunnelling deprecated from Icehouse, please only use
       # tunnel_type.
       enable_tunneling = True
       tunnel_type = gre

       integration_bridge = br-int
       tunnel_bridge = br-tun
       local_ip = 192.168.160.11

   On the same file, also configure the security group plugin::

       [securitygroup]
       firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

Almost done!
------------

Restart services::

    root@neutron-node:~# service neutron-server restart
    root@neutron-node:~# service neutron-dhcp-agent restart
    root@neutron-node:~# service neutron-l3-agent restart
    root@neutron-node:~# service neutron-metadata-agent restart


Nova-api configuration
----------------------

Nova compute service has to know that Neutron is being used. Connect
to the **api-node** and update  ``/etc/nova/nova.conf`` file::

    [DEFAULT]
    # ...

    # It is fine to have Noop here, because this is the *nova*
    # firewall. Neutron is responsible of configuring the firewall and its
    # configuration is stored in /etc/neutron/neutron.conf
    network_api_class = nova.network.neutronv2.api.API
    neutron_url = http://10.0.0.9:9696
    neutron_auth_strategy = keystone
    neutron_admin_tenant_name = service
    neutron_admin_username = neutron
    neutron_admin_password = gridka
    neutron_admin_auth_url = http://10.0.0.4:35357/v2.0
    linuxnet_interface_driver = nova.network.linux_net.LinuxOVSInterfaceDriver
    firewall_driver = nova.virt.firewall.NoopFirewallDriver
    security_group_api = neutron


Restart the services::

    root@api-node:~# service nova-api restart
    root@api-node:~# service nova-scheduler restart
    root@api-node:~# service nova-conductor restart

neutron on the compute node
---------------------------

Login on the **compute-1** node and install openvswitch and neutron plugins::

    root@compute-1:~# apt-get install neutron-plugin-openvswitch-agent neutron-plugin-ml2

Ensure the `br-int` bridge has been created by the installer::

    root@compute-1:~# ovs-vsctl show
    62f8b342-8afa-4ce4-aa98-e2ab671d2837
        Bridge br-int
            fail_mode: secure
            Port br-int
                Interface br-int
                    type: internal
        ovs_version: "2.0.1"

Ensure `rp_filter` is disabled. As we did before, you need to ensure
the following lines are present in ``/etc/sysctl.conf`` file.

This file is read during the startup, but it is not read
afterwards. To force Linux to re-read the file you can run::

    root@compute-1:~# sysctl -p /etc/sysctl.conf
    net.ipv4.conf.all.rp_filter=0
    net.ipv4.conf.default.rp_filter=0

Configure RabbitMQ and Keystone options for neutron, by editing
``/etc/neutron/neutron.conf``::

    [DEFAULT]
    # ...

    rpc_backend = neutron.openstack.common.rpc.impl_kombu
    rabbit_host = 10.0.0.3
    rabbit_password = gridka

    auth_strategy = keystone
    # ...

    [keystone_authtoken]
    auth_host = 10.0.0.4
    auth_port = 35357
    auth_protocol = http
    admin_tenant_name = service
    admin_user = neutron
    admin_password = gridka

Again on ``/etc/neutron/neutron.conf``, configure the neutron to use
the ML2 plugin::

    [DEFAULT]
    # ...

    core_plugin = ml2
    service_plugins = router
    allow_overlapping_ips = True

The ML2 plugin is configured in
``/etc/neutron/plugins/ml2/ml2_conf.ini``::

    [ml2]
    # ...

    type_drivers = gre
    tenant_network_types = gre
    mechanism_drivers = openvswitch
    	
    [ml2_type_gre]
    # ...

    tunnel_id_ranges = 1:1000
    
    [ovs]
    # ...
    local_ip = 10.0.0.20
    tunnel_type = gre
    enable_tunneling = True
    	
    [securitygroup]
    # ...

    firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
    enable_security_group = True

Configure `nova-compute` so that it knows about neutron. In file
``/etc/nova/nova.conf`` ensure the following lines are present::

    [DEFAULT]
    # ...

    network_api_class = nova.network.neutronv2.api.API
    neutron_url = http://10.0.0.9:9696
    neutron_auth_strategy = keystone
    neutron_admin_tenant_name = service
    neutron_admin_username = neutron
    neutron_admin_password = gridka
    neutron_admin_auth_url = http://10.0.0.4:35357/v2.0
    linuxnet_interface_driver = nova.network.linux_net.LinuxOVSInterfaceDriver
    firewall_driver = nova.virt.firewall.NoopFirewallDriver
    security_group_api = neutron

Restart `nova-compute` and the neutron agent::

    root@compute-1:~# service nova-compute restart
    nova-compute stop/waiting
    nova-compute start/running, process 17740

    root@compute-1:~# service neutron-plugin-openvswitch-agent restart
    neutron-plugin-openvswitch-agent stop/waiting
    neutron-plugin-openvswitch-agent start/running, process 17788


Default networks
----------------

Before starting any VM, we need to setup some basic networks.

In newtron, a `network` is a L2 network, very much like connecting
computers and switches using physical cables. On top of it, we create
one or more `subnet`, L3 network with a range IP assigned to them.

The first network we create is the *external* network, used by the VMs
of all the tenants to connect to the interned. As usual, you need to
setup the relevant environment variables (`OS_USERNAME`,
`OS_PASSWORD`, `OS_TENANT_NAME`, `OS_AUTH_URL`) in order to use the
`neutron` command::

    root@neutron-node:~# neutron net-create external-net --shared --router:external=True
    Created a new network:
    +---------------------------+--------------------------------------+
    | Field                     | Value                                |
    +---------------------------+--------------------------------------+
    | admin_state_up            | True                                 |
    | id                        | b09f88f7-be98-40e1-9911-d1127182de96 |
    | name                      | external-net                         |
    | provider:network_type     | gre                                  |
    | provider:physical_network |                                      |
    | provider:segmentation_id  | 1                                    |
    | router:external           | True                                 |
    | shared                    | True                                 |
    | status                    | ACTIVE                               |
    | subnets                   |                                      |
    | tenant_id                 | cacb2edc36a343c4b4747b8a8349371a     |
    +---------------------------+--------------------------------------+

Let's now create the L3 network, using the range of floating IPs we
decided to use::

    root@neutron-node:~# neutron subnet-create external-net --name ext-subnet \
      --allocation-pool start=172.16.1.1,end=172.16.1.254 \
      --disable-dhcp --gateway 172.16.0.1 \
      172.16.0.0/16
    Created a new subnet:
    +------------------+------------------------------------------------+
    | Field            | Value                                          |
    +------------------+------------------------------------------------+
    | allocation_pools | {"start": "172.16.1.1", "end": "172.16.1.254"} |
    | cidr             | 172.16.0.0/16                                  |
    | dns_nameservers  |                                                |
    | enable_dhcp      | False                                          |
    | gateway_ip       | 172.16.0.1                                     |
    | host_routes      |                                                |
    | id               | d7fc327b-8e04-43ce-bad4-98840b9b0927           |
    | ip_version       | 4                                              |
    | name             | ext-subnet                                     |
    | network_id       | b09f88f7-be98-40e1-9911-d1127182de96           |
    | tenant_id        | cacb2edc36a343c4b4747b8a8349371a               |
    +------------------+------------------------------------------------+

The ``--disable-dhcp`` option is needed because on this network we
don't want to run a dhcp server.

Also, the ``--gateway`` option specify the *real* gateway of the
network (in our case, we set up the physical node to be the router for
the public network)

Now, we will create a network for a tenant. These commands *do not
need* to run as cloud administrator, they are supposed to be executed
by a regular user belonging to a tenant.

Moreover, the networks, subnetworks and routers we create now are only
visible and usable by the tenant, and they can have the same IP
addressing of other networks created by different tenants.

::
    
    root@neutron-node:~# neutron net-create demo-net
    Created a new network:
    +---------------------------+--------------------------------------+
    | Field                     | Value                                |
    +---------------------------+--------------------------------------+
    | admin_state_up            | True                                 |
    | id                        | 29c861dd-9bf9-4a4e-a0b6-3de62fa33dd5 |
    | name                      | demo-net                             |
    | provider:network_type     | gre                                  |
    | provider:physical_network |                                      |
    | provider:segmentation_id  | 2                                    |
    | shared                    | False                                |
    | status                    | ACTIVE                               |
    | subnets                   |                                      |
    | tenant_id                 | cacb2edc36a343c4b4747b8a8349371a     |
    +---------------------------+--------------------------------------+
    
    root@neutron-node:~# neutron subnet-create demo-net --name demo-subnet --gateway 10.99.0.1 10.99.0.0/24
    Created a new subnet:
    +------------------+----------------------------------------------+
    | Field            | Value                                        |
    +------------------+----------------------------------------------+
    | allocation_pools | {"start": "10.99.0.2", "end": "10.99.0.254"} |
    | cidr             | 10.99.0.0/24                                 |
    | dns_nameservers  |                                              |
    | enable_dhcp      | True                                         |
    | gateway_ip       | 10.99.0.1                                    |
    | host_routes      |                                              |
    | id               | 5d4c6c72-9cf8-4272-8cec-08bd04b4b1f4         |
    | ip_version       | 4                                            |
    | name             | demo-subnet                                  |
    | network_id       | 29c861dd-9bf9-4a4e-a0b6-3de62fa33dd5         |
    | tenant_id        | cacb2edc36a343c4b4747b8a8349371a             |
    +------------------+----------------------------------------------+

This network is completely isolated, as it has no connection to the
external network we created before. In order to connect the two, we
need to create a router::

    root@neutron-node:~# neutron router-create demo-router
    Created a new router:
    +-----------------------+--------------------------------------+
    | Field                 | Value                                |
    +-----------------------+--------------------------------------+
    | admin_state_up        | True                                 |
    | external_gateway_info |                                      |
    | id                    | 3616bd03-0100-4247-9699-2839e360a688 |
    | name                  | demo-router                          |
    | status                | ACTIVE                               |
    | tenant_id             | cacb2edc36a343c4b4747b8a8349371a     |
    +-----------------------+--------------------------------------+

and connect it to the subnet `demo-subnet`::

    root@neutron-node:~# neutron router-interface-add demo-router demo-subnet
    Added interface 32ea1402-bb31-4575-8c14-06aea02d3442 to router demo-router.

and to the external network `external-net`::

    root@neutron-node:~# neutron router-gateway-set demo-router external-net
    Set gateway for router demo-router

On the neutron node, you should see that new ports have been created
on openvswitch::

    root@neutron-node:~# ovs-vsctl show
    1a05c398-3024-493f-b3c4-a01912688ba4
        Bridge br-ex
            Port br-ex
                Interface br-ex
                    type: internal
            Port "eth2"
                Interface "eth2"
            Port "qg-808b139c-45"
                Interface "qg-808b139c-45"
                    type: internal
        Bridge br-int
            fail_mode: secure
            Port "qr-32ea1402-bb"
                Interface "qr-32ea1402-bb"
                    type: internal
            Port patch-tun
                Interface patch-tun
                    type: patch
                    options: {peer=patch-int}
            Port br-int
                Interface br-int
                    type: internal
        ovs_version: "2.0.1"

and a new namespace has been created::

    root@neutron-node:~# ip netns list
    qrouter-3616bd03-0100-4247-9699-2839e360a688

In order to allow multiple tenant networks to share the same range of
IP addresses, neutron uses `namespaces`. This also means that the IP
address of the router `demo-router` is *not* visibile on the default
namespare, but only on the namespace created for that router. Indeed,
running `ip addr show`::

    root@neutron-node:~# ip addr show|grep 10.99
    root@neutron-node:~# 

will show no IP addresses on the range we specified in the default
namespace.

However, switching namespace...::

    root@neutron-node:~# ip netns exec qrouter-3616bd03-0100-4247-9699-2839e360a688 ip addr show
    1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default 
        link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
        inet 127.0.0.1/8 scope host lo
           valid_lft forever preferred_lft forever
        inet6 ::1/128 scope host 
           valid_lft forever preferred_lft forever
    10: qr-32ea1402-bb: <BROADCAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default 
        link/ether fa:16:3e:e2:d8:74 brd ff:ff:ff:ff:ff:ff
        inet 10.99.0.1/24 brd 10.99.0.255 scope global qr-32ea1402-bb
           valid_lft forever preferred_lft forever
        inet6 fe80::f816:3eff:fee2:d874/64 scope link 
           valid_lft forever preferred_lft forever
    11: qg-808b139c-45: <BROADCAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default 
        link/ether fa:16:3e:ca:6f:eb brd ff:ff:ff:ff:ff:ff
        inet 172.16.1.2/16 brd 172.16.255.255 scope global qg-808b139c-45
           valid_lft forever preferred_lft forever
        inet6 fe80::f816:3eff:feca:6feb/64 scope link 
           valid_lft forever preferred_lft forever

will show you the `10.99.0.1` ip address, that has been automatically
choosen for the `demo-router`.

Netspaces increase the flexibility but of course makes troubleshooting
much more complicated...

Now, as you can see::

    root@neutron-node:~# neutron port-list
    +--------------------------------------+------+-------------------+-----------------------------------------------------------------------------------+
    | id                                   | name | mac_address       | fixed_ips                                                                         |
    +--------------------------------------+------+-------------------+-----------------------------------------------------------------------------------+
    | 32ea1402-bb31-4575-8c14-06aea02d3442 |      | fa:16:3e:e2:d8:74 | {"subnet_id": "5d4c6c72-9cf8-4272-8cec-08bd04b4b1f4", "ip_address": "10.99.0.1"}  |
    | 808b139c-4598-4bf4-92b4-1a728aa0a21e |      | fa:16:3e:ca:6f:eb | {"subnet_id": "d7fc327b-8e04-43ce-bad4-98840b9b0927", "ip_address": "172.16.1.2"} |
    +--------------------------------------+------+-------------------+-----------------------------------------------------------------------------------+
    root@neutron-node:~# neutron subnet-list
    +--------------------------------------+-------------+---------------+------------------------------------------------+
    | id                                   | name        | cidr          | allocation_pools                               |
    +--------------------------------------+-------------+---------------+------------------------------------------------+
    | 5d4c6c72-9cf8-4272-8cec-08bd04b4b1f4 | demo-subnet | 10.99.0.0/24  | {"start": "10.99.0.2", "end": "10.99.0.254"}   |
    | d7fc327b-8e04-43ce-bad4-98840b9b0927 | ext-subnet  | 172.16.0.0/16 | {"start": "172.16.1.1", "end": "172.16.1.254"} |
    +--------------------------------------+-------------+---------------+------------------------------------------------+

an IP address has been assigned to the virtual port connected to the
`ext-subnet` subnetwork. This is only visible on the router namespace,
as you have already seen::

    root@neutron-node:~# ip netns exec qrouter-3616bd03-0100-4247-9699-2839e360a688 ip addr show | grep 172
        inet 172.16.1.2/16 brd 172.16.255.255 scope global qg-808b139c-45

If everything went fine, you should be able to ping this IP address
from the physical node::

    [root@gks-061 ~]# ping 172.16.1.2 -c 1
    PING 172.16.1.2 (172.16.1.2) 56(84) bytes of data.
    64 bytes from 172.16.1.2: icmp_seq=1 ttl=64 time=0.307 ms

    --- 172.16.1.2 ping statistics ---
    1 packets transmitted, 1 received, 0% packet loss, time 0ms
    rtt min/avg/max/mdev = 0.307/0.307/0.307/0.000 ms


Testing instance creation
-------------------------


::

    root@auth-node:~# nova boot --flavor m1.tiny  --key-name gridka-auth-node \
        --image cirros-0.3.0 \
        --nic net-id=29c861dd-9bf9-4a4e-a0b6-3de62fa33dd5 test-1


On the **neutron-node** the OpenVSwitch configuration now looks like::

    root@neutron-node:~# ovs-vsctl show
    1a05c398-3024-493f-b3c4-a01912688ba4
        Bridge br-ex
            Port br-ex
                Interface br-ex
                    type: internal
            Port "eth2"
                Interface "eth2"
            Port "qg-808b139c-45"
                Interface "qg-808b139c-45"
                    type: internal
        Bridge br-tun
            Port br-tun
                Interface br-tun
                    type: internal
            Port "gre-0a000014"
                Interface "gre-0a000014"
                    type: gre
                    options: {in_key=flow, local_ip="10.0.0.9", out_key=flow, remote_ip="10.0.0.20"}
            Port patch-int
                Interface patch-int
                    type: patch
                    options: {peer=patch-tun}
        Bridge br-int
            fail_mode: secure
            Port "tap1ddd9f69-d9"
                tag: 1
                Interface "tap1ddd9f69-d9"
                    type: internal
            Port patch-tun
                Interface patch-tun
                    type: patch
                    options: {peer=patch-int}
            Port br-int
                Interface br-int
                    type: internal
            Port "qr-32ea1402-bb"
                tag: 1
                Interface "qr-32ea1402-bb"
                    type: internal
            ovs_version: "2.0.1"

There are two namespaces defined, one for the router and one for the
DHCP agent::

    root@neutron-node:~# ip netns list
    qdhcp-29c861dd-9bf9-4a4e-a0b6-3de62fa33dd5
    qrouter-3616bd03-0100-4247-9699-2839e360a688

On the namespace of the dhcp agent you will see the IP of the dhcp service::

    root@neutron-node:~# ip netns exec qdhcp-29c861dd-9bf9-4a4e-a0b6-3de62fa33dd5 ip addr show
    1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default 
        link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
        inet 127.0.0.1/8 scope host lo
           valid_lft forever preferred_lft forever
    21: tap1ddd9f69-d9: <BROADCAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default 
        link/ether fa:16:3e:19:61:2a brd ff:ff:ff:ff:ff:ff
        inet 10.99.0.7/24 brd 10.99.0.255 scope global tap1ddd9f69-d9
           valid_lft forever preferred_lft forever

while the namespace of the router contains both the private and the
public IP used by the `demo-router`, connecting the internal network
`demo-subnet` and the external network::

    root@neutron-node:~# ip netns exec qrouter-3616bd03-0100-4247-9699-2839e360a688 ip addr show
    1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default 
        link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
        inet 127.0.0.1/8 scope host lo
           valid_lft forever preferred_lft forever
    23: qr-32ea1402-bb: <BROADCAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default 
        link/ether fa:16:3e:e2:d8:74 brd ff:ff:ff:ff:ff:ff
        inet 10.99.0.1/24 brd 10.99.0.255 scope global qr-32ea1402-bb
           valid_lft forever preferred_lft forever
    24: qg-808b139c-45: <BROADCAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default 
        link/ether fa:16:3e:ca:6f:eb brd ff:ff:ff:ff:ff:ff
        inet 172.16.1.2/16 brd 172.16.255.255 scope global qg-808b139c-45
           valid_lft forever preferred_lft forever


    root@neutron-node:~# neutron port-list
    +--------------------------------------+------+-------------------+-----------------------------------------------------------------------------------+
    | id                                   | name | mac_address       | fixed_ips                                                                         |
    +--------------------------------------+------+-------------------+-----------------------------------------------------------------------------------+
    | 32ea1402-bb31-4575-8c14-06aea02d3442 |      | fa:16:3e:e2:d8:74 | {"subnet_id": "5d4c6c72-9cf8-4272-8cec-08bd04b4b1f4", "ip_address": "10.99.0.1"}  |
    | 6b31e572-b5e7-49e6-94ab-0c1e78505ce9 |      | fa:16:3e:0d:5d:20 | {"subnet_id": "5d4c6c72-9cf8-4272-8cec-08bd04b4b1f4", "ip_address": "10.99.0.12"} |
    | 808b139c-4598-4bf4-92b4-1a728aa0a21e |      | fa:16:3e:ca:6f:eb | {"subnet_id": "d7fc327b-8e04-43ce-bad4-98840b9b0927", "ip_address": "172.16.1.2"} |
    +--------------------------------------+------+-------------------+-----------------------------------------------------------------------------------+
    root@neutron-node:~# neutron subnet-list
    +--------------------------------------+-------------+---------------+------------------------------------------------+
    | id                                   | name        | cidr          | allocation_pools                               |
    +--------------------------------------+-------------+---------------+------------------------------------------------+
    | 5d4c6c72-9cf8-4272-8cec-08bd04b4b1f4 | demo-subnet | 10.99.0.0/24  | {"start": "10.99.0.2", "end": "10.99.0.254"}   |
    | d7fc327b-8e04-43ce-bad4-98840b9b0927 | ext-subnet  | 172.16.0.0/16 | {"start": "172.16.1.1", "end": "172.16.1.254"} |
    +--------------------------------------+-------------+---------------+------------------------------------------------+

On the compute node instead::

    root@compute-1:~# ovs-vsctl show
    62f8b342-8afa-4ce4-aa98-e2ab671d2837
        Bridge br-tun
            Port "gre-0a000009"
                Interface "gre-0a000009"
                    type: gre
                    options: {in_key=flow, local_ip="10.0.0.20", out_key=flow, remote_ip="10.0.0.9"}
            Port br-tun
                Interface br-tun
                    type: internal
            Port patch-int
                Interface patch-int
                    type: patch
                    options: {peer=patch-tun}
        Bridge br-int
            fail_mode: secure
            Port br-int
                Interface br-int
                    type: internal
            Port "qvo6b31e572-b5"
                tag: 3
                Interface "qvo6b31e572-b5"
            Port patch-tun
                Interface patch-tun
                    type: patch
                    options: {peer=patch-int}
        ovs_version: "2.0.1"

    root@compute-1:~# brctl show
    bridge name	        bridge id		STP enabled	interfaces
    qbr6b31e572-b5		8000.8ed137166fb4	no		qvb6b31e572-b5
    							                    tap6b31e572-b5
    root@compute-1:~# virsh dumpxml 23|grep tap
          <target dev='tap6b31e572-b5'/>

To recap:

* The VM has interface `tap6b31e572-b5`
* `tap6b31e572-b5` interface is connected to the bridge
  `qbr6b31e572-b5`
* to bridge `qbr6b31e572-b5`, is also connected an OVS port
  `qvb6b31e572-b5`
* port `qvb6b31e572-b5` is connected ot the `br-int` OVS swith, and
  belongs to `VLAN 3` (tenant isolation)
* `br-int` switch is connected to `br-tun` switch using `patch-tun`
  OVS internal connection
* `br-tun` is connected to the `neutron-node` using a GRE tunnel, via
  `gre-0a000009` OVS port.
* On the neutron-node, `gre-0a000014` is the other endpoints of the
  GRE tunnel
* the `br-tun` switch on neutron-node is connected again to `br-int`
* an interface `tap1ddd9f69-d9` is connected to `br-int` on the
  neutron node
* The interface `tap1ddd9f69-d9` only has an IP in the network
  namespace of the dhcp (`qdhcp-29c861dd-9bf9-4a4e-a0b6-3de62fa33dd5`)
* The interface `qr-32ea1402-bb` connected on the `br-int`, and the
  interface `qg-808b139c-45` connected to the `br-ext` switch lives on
  a separate namespace.
* Routing happens on the router namespace, using standard linux routing.

Floating IPs
------------

Let's now allocate a new floating IP::

    root@neutron-node:~# neutron floatingip-create external-net
    Created a new floatingip:
    +---------------------+--------------------------------------+
    | Field               | Value                                |
    +---------------------+--------------------------------------+
    | fixed_ip_address    |                                      |
    | floating_ip_address | 172.16.1.4                           |
    | floating_network_id | b09f88f7-be98-40e1-9911-d1127182de96 |
    | id                  | 21d81167-1373-442b-85ad-b930f8223c17 |
    | port_id             |                                      |
    | router_id           |                                      |
    | status              | DOWN                                 |
    | tenant_id           | cacb2edc36a343c4b4747b8a8349371a     |
    +---------------------+--------------------------------------+
    root@neutron-node:~# nova floating-ip-associate test-2 172.16.1.4
    root@neutron-node:~# nova list
    +--------------------------------------+--------+--------+------------+-------------+---------------------------------+
    | ID                                   | Name   | Status | Task State | Power State | Networks                        |
    +--------------------------------------+--------+--------+------------+-------------+---------------------------------+
    | ff57e37d-a5f3-4591-8655-1c7f535231f8 | test-2 | ACTIVE | -          | Running     | demo-net=10.99.0.12, 172.16.1.4 |
    +--------------------------------------+--------+--------+------------+-------------+---------------------------------+

As usual, if you want to check the firewall rules created to
enforce security groups and floating IPs, you have to run the command
inside the correct namespace::

    root@neutron-node:~# ip netns exec qrouter-3616bd03-0100-4247-9699-2839e360a688 iptables -L -t nat
    Chain PREROUTING (policy ACCEPT)
    target     prot opt source               destination         
    neutron-l3-agent-PREROUTING  all  --  anywhere             anywhere            

    Chain INPUT (policy ACCEPT)
    target     prot opt source               destination         

    Chain OUTPUT (policy ACCEPT)
    target     prot opt source               destination         
    neutron-l3-agent-OUTPUT  all  --  anywhere             anywhere            

    Chain POSTROUTING (policy ACCEPT)
    target     prot opt source               destination         
    neutron-l3-agent-POSTROUTING  all  --  anywhere             anywhere            
    neutron-postrouting-bottom  all  --  anywhere             anywhere            

    Chain neutron-l3-agent-OUTPUT (1 references)
    target     prot opt source               destination         
    DNAT       all  --  anywhere             172.16.1.4           to:10.99.0.12

    Chain neutron-l3-agent-POSTROUTING (1 references)
    target     prot opt source               destination         
    ACCEPT     all  --  anywhere             anywhere             ! ctstate DNAT

    Chain neutron-l3-agent-PREROUTING (1 references)
    target     prot opt source               destination         
    REDIRECT   tcp  --  anywhere             169.254.169.254      tcp dpt:http redir ports 9697
    DNAT       all  --  anywhere             172.16.1.4           to:10.99.0.12

    Chain neutron-l3-agent-float-snat (1 references)
    target     prot opt source               destination         
    SNAT       all  --  10.99.0.12           anywhere             to:172.16.1.4

    Chain neutron-l3-agent-snat (1 references)
    target     prot opt source               destination         
    neutron-l3-agent-float-snat  all  --  anywhere             anywhere            
    SNAT       all  --  10.99.0.0/24         anywhere             to:172.16.1.2

    Chain neutron-postrouting-bottom (1 references)
    target     prot opt source               destination         
    neutron-l3-agent-snat  all  --  anywhere             anywhere            


Now we should be able to connect to the VM from the physical node.



