Admin procedures
================

Install and run KVM
-------------------

First of all we should install the virtualization software needed for
running the various VMs which will host the OpenStack services.

* Install the needed software:

::
        # yum install kvm virt-manager libvirt

* Start the libvirt daemon:

 :: 
        # /etc/init.d/libvirtd start

Install OpenStack Services VMs
------------------------------

Once you are done you can start setting up the VMs needed for the Openstack Services.
You will need an Ubuntu 12.04 Server iso on the host, which you can get by doing:

::
        # wget http://releases.ubuntu.com/precise/ubuntu-12.04.2-server-amd64.iso


Create bridges between the two hosts
------------------------------------

* Install the needed software: 'bridge-utils' and 'tunctl'

 ::
        # yum install bridge-utils tunctl 

* Create the bridge and add the eth1 interface to it:: 


        # brctl addbr br1  
        # brctl addif br1 eth1

* Add the ifcfg-br1 configuration file in /etc/sysconfig/network-scripts/

It should look like this::


        DEVICE="br1"
        BOOTPROTO=static
        TYPE=Bridge
        DELAY=0
        ONBOOT="yes"
        BROADCAST=10.0.0.255
        # 1 is assigned to the machine hosting the OpenStack services 
        # 2 is assigned to the machine hosting nova-compute.
        IPADDR=10.0.0.{1,2}
        NETMASK=255.255.255.0
        NETWORK=10.0.0.0
        NM_CONTROLLED=no          


The bridge interface is probably also needed for the public interface eth0.  

* Change the ifcfg-eth1 configuration file in /etc/sysconfig/network-scripts/ 

It should look like this::


        DEVICE=eth1
        BOOTPROTO=static
        TYPE=Ethernet
        VLAN=no
        ONBOOT=yes
        NM_CONTROLLED=no
        BRIDGE=br1


* Restart the network 

        # service network restart 

* Edit the /etc/hosts file with::


        10.0.0.3    db-node
        10.0.0.4    auth-node
        10.0.0.5    image-node
        10.0.0.6    api-node
        10.0.0.7    network-node
        10.0.0.8    volume-node
        10.0.0.20   compute-1
        10.0.0.21   compute-2











  
