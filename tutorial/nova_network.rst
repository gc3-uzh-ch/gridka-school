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


