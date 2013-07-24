Admin procedures for preparation of the school hosting machines
===============================================================

Install and run KVM
-------------------

First of all we should install the virtualization software needed for
running the various VMs which will host the OpenStack services.

* Install the needed software:

         yum install qemu kvm virt-manager 

* Start the libvirt daemon:
 
         /etc/init.d/libvirtd start

Install OpenStack Services VMs
------------------------------

Once you are done you can start setting up the VMs needed for the Openstack Services.
You will need an Ubuntu 12.04 Server iso on the host, which you can get by doing:

         wget http://releases.ubuntu.com/precise/ubuntu-12.04.2-server-amd64.iso









  
