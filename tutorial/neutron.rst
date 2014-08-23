Neutron configuration
=====================


Neutron
-------

Execute in mysql::

    CREATE DATABASE neutron;
    GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'neutronPass';

Create Neutron user, service and endpoint::

    root@cloud2:~# keystone user-create --name=neutron --pass=neutronServ
    +----------+----------------------------------+
    | Property |              Value               |
    +----------+----------------------------------+
    |  email   |                                  |
    | enabled  |               True               |
    |    id    | 5b92212d919d4db7ae3ef60e33682ad2 |
    |   name   |             neutron              |
    +----------+----------------------------------+
    root@cloud2:~# keystone user-role-add --user=neutron --tenant=service --role=admin

    root@cloud2:~# keystone service-create --name=neutron --type=network \
         --description="OpenStack Networking Service"

    root@cloud2:~# keystone endpoint-create \
         --region RegionOne \
         --service neutron \
         --publicurl http://cloud2.gc3.uzh.ch:9696 \
         --adminurl http://cloud2.gc3.uzh.ch:9696 \
         --internalurl http://192.168.160.11:9696

    root@cloud2:~# apt-get install neutron-server neutron-dhcp-agent \
    neutron-plugin-openvswitch-agent neutron-l3-agent


The network node acts as gateway for the VMs, so we need to enable IP
forwarding. This is done by ensuring that the following lines is
present in ``/etc/sysctl.conf`` file::

    net.ipv4.ip_forward=1
    net.ipv4.conf.all.rp_filter=0
    net.ipv4.conf.default.rp_filter=0

This file is read during the startup, but it is not read
afterwards. To force Linux to re-read the file you can run::

    root@network-node:~# sysctl -p /etc/sysctl.conf
    net.ipv4.ip_forward = 1
    net.ipv4.conf.default.rp_filter = 0
    net.ipv4.conf.all.rp_filter = 0

The ``/etc/neutron/neutron.conf`` must be updated::

    [DEFAULT]
    # ...
    core_plugin = neutron.plugins.openvswitch.ovs_neutron_plugin.OVSNeutronPluginV2
    auth_strategy = keystone
    # ...
    rabbit_host = 192.168.160.11
    # ...
    [keystone_authtoken]
    auth_host = cloud2.gc3.uzh.ch
    auth_port = 35357
    auth_protocol = http
    admin_tenant_name = service
    admin_user = neutron
    admin_password = neutronServ
    # ...
    [database]
    connection = mysql://neutron:neutronPass@192.168.160.11/neutron

and also ``/etc/neutron/api-paste.conf``::

    [filter:authtoken]
    paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
    auth_host = cloud2.gc3.uzh.ch
    auth_uri = http://cloud2.gc3.uzh.ch:5000
    admin_tenant_name = service
    admin_user = neutron
    admin_password = neutronServ


OpenVSwitch
-----------


root@cloud2:~# apt-get install neutron-plugin-openvswitch-agent \
openvswitch-datapath-dkms

..
    openvswitch-datapath-dkms is only needed for ubuntu 12.04, cfr
    http://docs.openstack.org/havana/install-guide/install/apt/content/install-neutron.install-plug-in.ovs.html


root@cloud2:~# ovs-vsctl add-br br-int
root@cloud2:~# ovs-vsctl add-br br-ex
root@cloud2:~# ovs-vsctl add-port br-ex eth3

Configure the EXTERNAL_INTERFACE without an IP address and in
promiscuous mode. Additionally, you must set the newly created br-ex
interface to have the IP address that formerly belonged to
EXTERNAL_INTERFACE.

``/etc/network/interfaces``::

    auto br-ex
    iface br-ex inet static
         address 130.60.24.12
         network    130.60.24.0
         netmask    255.255.255.0
         broadcast  130.60.24.255
         gateway    130.60.24.1
         dns-nameservers 130.60.128.3 130.60.64.51
         dns-search gc3.uzh.ch uzh.ch
         up ifconfig eth3 promisc

(didn't do anything on eth3 but remove IP and shut down the
interfaces. Let's see what happen)

Edit ``/etc/neutron/l3_agent.ini``::

    interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
    
    use_namespaces = True

Edit ``/etc/neutron/dhcp_agent.ini``::

    interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
    
    use_namespaces = True

    dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq

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


To allow virtual machines to access the Compute metadata information,
the Networking metadata agent must be enabled and configured. The
agent will act as a proxy for the Compute metadata service.

On the controller, edit the /etc/nova/nova.conf file to define a
secret key that will be shared between the Compute Service and the
Networking metadata agent::

    [DEFAULT]
    neutron_metadata_proxy_shared_secret = NeutronMetadataSharedSecret
    service_neutron_metadata_proxy = true

Configure the metadata agent in ``/etc/neutron/metadata_agent.init``::

    [DEFAULT]
    auth_url = http://cloud2.gc3.uzh.ch:5000/v2.0
    auth_region = RegionOne
    admin_tenant_name = service
    admin_user = neutron
    admin_password = neutronServ
    nova_metadata_ip = 192.168.160.11
    metadata_proxy_shared_secret = NeutronMetadataSharedSecret

Restart services::

    service neutron-server restart
    service neutron-dhcp-agent restart
    service neutron-l3-agent restart
    service neutron-metadata-agent restart
    service neutron-plugin-openvswitch-agent restart


Nova-api configuration
----------------------

modify /etc/nova/nova.conf::

    # It is fine to have Noop here, because this is the *nova*
    # firewall. Neutron is responsible of configuring the firewall and its
    # configuration is stored in /etc/neutron/neutron.conf
        network_api_class=nova.network.neutronv2.api.API
    neutron_url=http://controller:9696
    neutron_auth_strategy=keystone
    neutron_admin_tenant_name=service
    neutron_admin_username=neutron
    neutron_admin_password=neutronServ
    neutron_admin_auth_url=http://controller:35357/v2.0
    linuxnet_interface_driver = nova.network.linux_net.LinuxOVSInterfaceDriver
    firewall_driver=nova.virt.firewall.NoopFirewallDriver
    security_group_api=neutron


Restart the services::

    root@cloud2:~# service nova-api restart
    root@cloud2:~# service nova-scheduler restart
    root@cloud2:~# service nova-conductor restart
    root@cloud2:~# service neutron-server restart


neutron on the compute node
---------------------------

Assuming you already configured nova.conf in here

Install openvswitch and neutron plugins::

    root@cloud2:~# apt-get install neutron-plugin-openvswitch-agent openvswitch-datapath-dkms

Create the integration bridge::

    root@cloud2:~# ovs-vsctl add-br br-int

Like we did for the controller, configure GRE by editing
``/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini``::

    [ovs]
    tenant_network_type = gre
    tunnel_id_ranges = 1:1000
    enable_tunneling = True
    integration_bridge = br-int
    tunnel_bridge = br-tun
    local_ip = 192.168.160.152

Modify  and
add the sepcified driver for security groups::

    [securitygroup]
    firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver


Network creation
----------------

On the controller node, create the *external network*::

    root@cloud2:~# neutron net-create ext-net -- --router:external=True
    Created a new network:
    +---------------------------+--------------------------------------+
    | Field                     | Value                                |
    +---------------------------+--------------------------------------+
    | admin_state_up            | True                                 |
    | id                        | c434bd85-91dd-4f98-8f72-fddb73d3347d |
    | name                      | ext-net                              |
    | provider:network_type     | gre                                  |
    | provider:physical_network |                                      |
    | provider:segmentation_id  | 1                                    |
    | router:external           | True                                 |
    | shared                    | False                                |
    | status                    | ACTIVE                               |
    | subnets                   |                                      |
    | tenant_id                 | 519158d1c5b84e9d8387381468707636     |
    +---------------------------+--------------------------------------+

Create a subnetwork::

    root@cloud2:~# neutron subnet-create ext-net \
      --allocation-pool start=130.60.24.224,end=130.60.24.227 \
      --gateway=130.60.24.1 --enable_dhcp=False \
      130.60.24.0/24

**QUESTION:** this subnet is automatically used for floating ip?

Create a tenant::

    root@cloud2:~# keystone tenant-create --name demo
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |                                  |
    |   enabled   |               True               |
    |      id     | dc6dada1ca5248d692f057e7483bdae6 |
    |     name    |               demo               |
    +-------------+----------------------------------+

and create a router for this tenant::

    root@cloud2:~# neutron router-create ext-to-int --tenant-id dc6dada1ca5248d692f057e7483bdae6
    Created a new router:
    +-----------------------+--------------------------------------+
    | Field                 | Value                                |
    +-----------------------+--------------------------------------+
    | admin_state_up        | True                                 |
    | external_gateway_info |                                      |
    | id                    | 6ef98eb2-0611-4f9e-b14c-d9f26bae0983 |
    | name                  | ext-to-int                           |
    | status                | ACTIVE                               |
    | tenant_id             | dc6dada1ca5248d692f057e7483bdae6     |
    +-----------------------+--------------------------------------+


Now you have to set the gateway for this router to be the external
network::

    root@cloud2:~# neutron net-list
    +--------------------------------------+---------+-----------------------------------------------------+
    | id                                   | name    | subnets                                             |
    +--------------------------------------+---------+-----------------------------------------------------+
    | c434bd85-91dd-4f98-8f72-fddb73d3347d | ext-net | f8e1da44-a64f-4197-b6f9-f4ec88b711c0 130.60.24.0/24 |
    +--------------------------------------+---------+-----------------------------------------------------+
    root@cloud2:~# neutron router-gateway-set \
    6ef98eb2-0611-4f9e-b14c-d9f26bae0983 \
    c434bd85-91dd-4f98-8f72-fddb73d3347d

Create an internal network for the demo tenant::

    root@cloud2:~# neutron net-create \
        --tenant-id dc6dada1ca5248d692f057e7483bdae6 \
        demo-net
    Created a new network:
    +---------------------------+--------------------------------------+
    | Field                     | Value                                |
    +---------------------------+--------------------------------------+
    | admin_state_up            | True                                 |
    | id                        | edcf04b5-ee64-463f-a214-75ae7b7e1e3c |
    | name                      | demo-net                             |
    | provider:network_type     | gre                                  |
    | provider:physical_network |                                      |
    | provider:segmentation_id  | 2                                    |
    | shared                    | False                                |
    | status                    | ACTIVE                               |
    | subnets                   |                                      |
    | tenant_id                 | dc6dada1ca5248d692f057e7483bdae6     |
    +---------------------------+--------------------------------------+

create a subnet::

    root@cloud2:~# neutron subnet-create \
        --tenant-id dc6dada1ca5248d692f057e7483bdae6 \
        demo-net 10.5.5.0/24 --gateway 10.5.5.1
    Created a new subnet:
    +------------------+--------------------------------------------+
    | Field            | Value                                      |
    +------------------+--------------------------------------------+
    | allocation_pools | {"start": "10.5.5.2", "end": "10.5.5.254"} |
    | cidr             | 10.5.5.0/24                                |
    | dns_nameservers  |                                            |
    | enable_dhcp      | True                                       |
    | gateway_ip       | 10.5.5.1                                   |
    | host_routes      |                                            |
    | id               | 1e6ebaba-ce72-47fb-923e-20d000912c1c       |
    | ip_version       | 4                                          |
    | name             |                                            |
    | network_id       | edcf04b5-ee64-463f-a214-75ae7b7e1e3c       |
    | tenant_id        | dc6dada1ca5248d692f057e7483bdae6           |
    +------------------+--------------------------------------------+

add this network to the main router::

    root@cloud2:~# neutron router-interface-add \
        6ef98eb2-0611-4f9e-b14c-d9f26bae0983 \
        1e6ebaba-ce72-47fb-923e-20d000912c1c
    Added interface 46eef30e-7d94-4514-b306-584acb13ce54 to router 6ef98eb2-0611-4f9e-b14c-d9f26bae0983.

After you create all the networks, tell the L3 agent what the external
network ID is, as well as the ID of the router associated with this
machine (because you are not using namespaces, there can be only one
router for each machine). To do this, edit the
``/etc/neutron/l3_agent.ini`` file::


    gateway_external_network_id = c434bd85-91dd-4f98-8f72-fddb73d3347d
    router_id = 6ef98eb2-0611-4f9e-b14c-d9f26bae0983

**QUESTION:** Check if router_id is always needed. I think it's only
needed if you use the same router for all the tenants.

Then, restart the L3 agent::

    root@cloud2:~# service neutron-l3-agent restart

Boot an instance
----------------

::
    root@cloud2:~# nova boot --flavor m1.tiny --image 3709961d-625e-427f-aa97-d975d991aa56 --nic net-id=edcf04b5-ee64-463f-a214-75ae7b7e1e3c --key-name antonio test1

What didn't work at first? Neutron configuration of some service was
not correct.

Then, connectivity between node and host is not working. Why?

The problem was in neutron.conf in the compute node, which has to be
more or less the same as the one in the network node.

Floating IPs
------------

Are they automatically created when creating the external network?

Notes
-----

When everything is working fine, the gre tunnel is automatically
created by neutron-plugin-openvswitch service

The external interface *must* be in promisc mode, because the floating
IP address is not assigned to the interface.

LBaaS install
-------------

::

    root@cloud2:~# apt-get install neutron-lbaas-agent haproxy

Edit ``/etc/neutron/neutron.conf``::


    service_plugins = neutron.services.loadbalancer.plugin.LoadBalancerPlugin

edut ``/etc/neutron/lbaas_agent.ini``::

    device_driver = neutron.services.loadbalancer.drivers.haproxy.namespace_driver.HaproxyNSDriver
    interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver

Also configure horizon ``/etc/openstack-dashboard/local_settings.py``::

    OPENSTACK_NEUTRON_NETWORK = {
        'enable_lb': True,


Restart services::

    root@cloud2:~# service neutron-server restart
    root@cloud2:~# service neutron-lbaas-agent restart
    root@cloud2:~# service apache2 restart

LBaaS test
----------




Questions
---------

* Multi-host (high availability) for neutron
* configuration that mixes with real network: is it possible to give
  internal IP which are connected to the same L2 network as my
  internal network? (use case: access services which are internal)
* maybe can be done using floatin IPs? Creating a new internal network
  connected to an external network which lives in my L2 service
  network?
* I created a second, isolated, network, but when I try to start an
  instance with both interface, the interface in the routed network is
  not getting any IP address, and of course the second interface
  cannot access the metadata server
* when I create a router for the external network, do I need to assign
  an IP? It assignes automatically one...
* I created a new network from the web interface, set the gateway to
  the external gateway, 
* I created two network, they are routed. How can I create *isolated*
  networks? (only routable towards the external network) Shall I
  create two external routers? (yes, it works)
* auto assignment of floating ip? There is a blueprint but no code has
  been written yet:
  https://blueprints.launchpad.net/neutron/+spec/auto-associate-floating-ip
* In OVS solution, what's the overhead?
* Do I really need to assign an IP to the external router when
  creating the external router?
* Why it's not possible to associate two floating ip to the same port?


My test:

Add network_vlan_ranges = eth3:24:24

create network
root@cloud2:~# neutron net-create ext-net --shared --provider:network_type vlan --provider:physical_network eth3 --provider:segmentation_id 24

neutron subnet-create --name public-network --no-gateway --host-route destination=0.0.0.0/0,nexthop=130.60.24.1  --enable-dhcp=True --allocation-pool start=130.60.24.224,end=130.60.24.227 ext-net 130.60.24.0/24

Not working! Maybe because I'm mixing vlan and gre?

QUESTION: can I mix vlan and gre networks?


TEST: create an internal network and a multihomed host.
-------------------------------------------------------

Current configuration:

root@cloud2:~# neutron net-list
+--------------------------------------+----------+-----------------------------------------------------+
| id                                   | name     | subnets                                             |
+--------------------------------------+----------+-----------------------------------------------------+
| ccad1f1a-ad8b-4e23-96ee-4894508280bf | test-net | 9a261534-7939-4869-ba6b-ba9e340c1532 10.0.0.0/24    |
| e7eb3dfa-5afe-43be-bd09-b3e589e52840 | ext-net  | f5577bd7-12b8-44f6-a3fa-507aa38f198e 130.60.24.0/24 |
+--------------------------------------+----------+-----------------------------------------------------+
root@cloud2:~# neutron subnet-list
+--------------------------------------+-------------+----------------+----------------------------------------------------+
| id                                   | name        | cidr           | allocation_pools                                   |
+--------------------------------------+-------------+----------------+----------------------------------------------------+
| 9a261534-7939-4869-ba6b-ba9e340c1532 | test-subnet | 10.0.0.0/24    | {"start": "10.0.0.2", "end": "10.0.0.254"}         |
| f5577bd7-12b8-44f6-a3fa-507aa38f198e |             | 130.60.24.0/24 | {"start": "130.60.24.224", "end": "130.60.24.227"} |
+--------------------------------------+-------------+----------------+----------------------------------------------------+
root@cloud2:~# neutron router-list
+--------------------------------------+------------+-----------------------------------------------------------------------------+
| id                                   | name       | external_gateway_info                                                       |
+--------------------------------------+------------+-----------------------------------------------------------------------------+
| 31e1f1b1-70c3-4072-8011-524b43f55243 | int-to-ext | {"network_id": "e7eb3dfa-5afe-43be-bd09-b3e589e52840", "enable_snat": true} |
+--------------------------------------+------------+-----------------------------------------------------------------------------+
root@cloud2:~# neutron port-list
+--------------------------------------+------+-------------------+--------------------------------------------------------------------------------------+
| id                                   | name | mac_address       | fixed_ips                                                                            |
+--------------------------------------+------+-------------------+--------------------------------------------------------------------------------------+
| 35cce64f-11fb-4885-8d3f-a34cd9e1ef08 |      | fa:16:3e:ab:70:0a | {"subnet_id": "9a261534-7939-4869-ba6b-ba9e340c1532", "ip_address": "10.0.0.3"}      |
| b4a8b91a-1997-40ee-b409-3b02dc871fbc |      | fa:16:3e:34:c6:de | {"subnet_id": "9a261534-7939-4869-ba6b-ba9e340c1532", "ip_address": "10.0.0.1"}      |
| d19e2b9f-93ce-4429-968e-cad3492168c5 |      | fa:16:3e:67:1c:7c | {"subnet_id": "f5577bd7-12b8-44f6-a3fa-507aa38f198e", "ip_address": "130.60.24.224"} |
| e6d9ed03-f355-4c2b-8370-dcc0a9643354 |      | fa:16:3e:0e:b0:23 | {"subnet_id": "f5577bd7-12b8-44f6-a3fa-507aa38f198e", "ip_address": "130.60.24.225"} |
+--------------------------------------+------+-------------------+--------------------------------------------------------------------------------------+


ext-net: external network.
test-net: internal network, with access to int-to-ext router
int-to-ext: router to the external network

External network creation::

    neutron net-create ext-net -- --router:external=True

    neutron subnet-create ext-net \
        --allocation-pool start=130.60.24.224,end=130.60.24.227 \
        --gateway=130.60.24.1 --enable_dhcp=False \
        130.60.24.0/24

Creation of the router (for tenant `demo`)::

    neutron  router-create int-to-ext \
        --tenant-id dc6dada1ca5248d692f057e7483bdae6

Following commands are run as demo tenant

(creation of test-net network done via web interface ...)

Creation of the internal network::

    root@cloud2:~# neutron net-create internal
    Created a new network:
    +---------------------------+--------------------------------------+
    | Field                     | Value                                |
    +---------------------------+--------------------------------------+
    | admin_state_up            | True                                 |
    | id                        | b54b7527-7be7-4d28-ac1d-cea216bcc71b |
    | name                      | internal                             |
    | provider:network_type     | gre                                  |
    | provider:physical_network |                                      |
    | provider:segmentation_id  | 3                                    |
    | shared                    | False                                |
    | status                    | ACTIVE                               |
    | subnets                   |                                      |
    | tenant_id                 | dc6dada1ca5248d692f057e7483bdae6     |
    +---------------------------+--------------------------------------+
    root@cloud2:~# neutron subnet-create --no-gateway --host-route destination=169.254.0.0/16,nexthop=10.9.0.1  --name int-subnet internal 10.9.0.0/24
    Created a new subnet:
    +------------------+----------------------------------------------------------+
    | Field            | Value                                                    |
    +------------------+----------------------------------------------------------+
    | allocation_pools | {"start": "10.9.0.1", "end": "10.9.0.254"}               |
    | cidr             | 10.9.0.0/24                                              |
    | dns_nameservers  |                                                          |
    | enable_dhcp      | True                                                     |
    | gateway_ip       |                                                          |
    | host_routes      | {"destination": "169.254.0.0/16", "nexthop": "10.9.0.1"} |
    | id               | 1478350f-f19e-4ce6-9165-0f25a5cc4a6c                     |
    | ip_version       | 4                                                        |
    | name             | int-subnet                                               |
    | network_id       | b54b7527-7be7-4d28-ac1d-cea216bcc71b                     |
    | tenant_id        | dc6dada1ca5248d692f057e7483bdae6                         |
    +------------------+----------------------------------------------------------+

Creation of a *router*. This is needed for the metadata server to
work::

    root@cloud2:~# neutron router-create int-router
    Created a new router:
    +-----------------------+--------------------------------------+
    | Field                 | Value                                |
    +-----------------------+--------------------------------------+
    | admin_state_up        | True                                 |
    | external_gateway_info |                                      |
    | id                    | 47889473-f780-45bc-9f9a-5de2d9ea3187 |
    | name                  | int-router                           |
    | status                | ACTIVE                               |
    | tenant_id             | dc6dada1ca5248d692f057e7483bdae6     |
    +-----------------------+--------------------------------------+

Create a *port* in the subnet with the 10.9.0.1 ip (the one we used
as nexthop in the subnet creation)::

    root@cloud2:~# neutron port-create internal --fixed-ip ip_address=10.9.0.1
    Created a new port:
    +-----------------------+---------------------------------------------------------------------------------+
    | Field                 | Value                                                                           |
    +-----------------------+---------------------------------------------------------------------------------+
    | admin_state_up        | True                                                                            |
    | allowed_address_pairs |                                                                                 |
    | binding:capabilities  | {"port_filter": true}                                                           |
    | binding:host_id       |                                                                                 |
    | binding:vif_type      | ovs                                                                             |
    | device_id             |                                                                                 |
    | device_owner          |                                                                                 |
    | fixed_ips             | {"subnet_id": "1478350f-f19e-4ce6-9165-0f25a5cc4a6c", "ip_address": "10.9.0.1"} |
    | id                    | 7aef10a4-750f-4ddd-858d-87cf5ec876d4                                            |
    | mac_address           | fa:16:3e:0e:2e:00                                                               |
    | name                  |                                                                                 |
    | network_id            | b54b7527-7be7-4d28-ac1d-cea216bcc71b                                            |
    | security_groups       | 77b0f279-5480-4d74-91af-482acf78204d                                            |
    | status                | DOWN                                                                            |
    | tenant_id             | dc6dada1ca5248d692f057e7483bdae6                                                |
    +-----------------------+---------------------------------------------------------------------------------+


Attach the interface to the internal router::

    root@cloud2:~# neutron router-interface-add 47889473-f780-45bc-9f9a-5de2d9ea3187 port=7aef10a4-750f-4ddd-858d-87cf5ec876d4
    Added interface 7aef10a4-750f-4ddd-858d-87cf5ec876d4 to router 47889473-f780-45bc-9f9a-5de2d9ea3187.



ACTUAL TESTING:

Boot the master instance::

    root@cloud2:~# nova boot --flavor m1.tiny --image "Ubuntu 12.04"  --nic net-id=b54b7527-7be7-4d28-ac1d-cea216bcc71b --nic net-id=ccad1f1a-ad8b-4e23-96ee-4894508280bf  --key-name antonio master

Boot 4 client machines::

    root@cloud2:~# nova boot --flavor m1.tiny --image "Ubuntu 12.04"  --nic net-id=b54b7527-7be7-4d28-ac1d-cea216bcc71b --num-instances 4  --key-name antonio client


Multihomed netowrk

ifconfig -a | grep ^eth|awk '{print $1}' | while read iface; do grep "^iface $iface" /etc/network/interfaces || (echo -e "auto $iface\niface $iface inet dhcp\n" >> /etc/network/interfaces; ifup $iface); done
for key in rsa dsa ecdsa; do keyfile=/etc/ssh/ssh_host_$key_key; [ -f $keyfile ] || ssh-keygen -t  -q -N '' -f $keyfile; done; exit 0



Create a L2-only network, without metadata and dhcp
---------------------------------------------------

neutron net-create --tenant-id dc6dada1ca5248d692f057e7483bdae6 bnet
neutron subnet-create --no-gateway --disable-dhcp --name bnet bnet 10.9.9.0/24


Performance tests:

https://ask.openstack.org/en/question/6140/quantum-neutron-gre-slow-performance/

from within the VM, iperf was fine but wget was going 15kb/s while
from cloud2 was going 1.5 MB/s
