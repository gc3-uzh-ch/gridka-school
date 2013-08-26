GridKa School 2013 - Working with the cloud
===========================================

This document is intended to be used after you have installed a working Grizzly
cloud. It shows common tasks and how to use the CLI to handle them. It also give
you a bit more detail on where important bits and pieces of the system are
located.


Log Files
---------

Most information that is needed for analyzing an OpenStack installation can be
found in the log files. They usually are in `/var/lib`::

* `/var/log/nova/nova-compute.log` 
* `/var/log/libvirt/libvirt.log`
* `/var/log/cinder/cinder-volume.log`
* `/var/log/horizon/horizon.log`
* ...

Command Line tools
------------------

There are command line tools to directly interact with the different components
of Grizzly. They can be installed either on the server or on your local
workstation. They use the REST API to communicate, so as long as you have an
HTTP(S) connection to your servers, they will work.

They are installed either with the package manager or with `pip`, the Python
install tool::

* python-novaclient  - provides `nova`
* python-glanceclient - provides `glance`
* python-keystoneclient - provides `keystone`
* python-cinderclient - provides `cinder`
* python-swiftclient - provides `swift`
* python-quantumclient - provides `quantum` (not used in this course)

      apt-get install <package-name>
      pip install <package-name>


Adminstrative tools
-------------------

Some of the tools must run on the cloud controller server because they read
config files. 

* `nova-manage`
* `glance-manage`
* `keystone-manage`
* `cinder-manage`


Setting up the credentials
--------------------------

Credentials are handled via environment variables - we suggest you create a
small file (for example called `.openstack`) that you can source in the shell::

    OS_AUTH_URL=http://auth-node:5000/v2.0
    OS_PASSWORD="secret_password"
    OS_TENANT_NAME="admin"
    OS_USERNAME="admin"
    OS_NO_CACHE=1

    export OS_AUTH_URL OS_PASSWORD
    export OS_TENANT_NAME OS_USERNAME
    export OS_NO_CACHE

You can then source this file in the shell by doing::

    . ~/.openstack


You can of course have multiple files with different credentials.


Servers and Services
--------------------

List all services::

      nova-manage service list

      Binary           Host          Zone   Status     State Updated_At
      nova-consoleauth ineri         nova   enabled    :-)   2013-08-20 09:18:07
      nova-scheduler   ineri         nova   enabled    :-)   2013-08-20 09:18:03
      nova-cert        ineri         nova   enabled    :-)   2013-08-20 09:18:02
      nova-compute     s2            nova   enabled    :-)   2013-08-20 09:18:01
      nova-compute     s3            nova   disabled   XXX   2013-06-04 11:42:09
      nova-compute     s1            nova   enabled    :-)   2013-08-20 09:18:10
      nova-compute     s0            nova   enabled    :-)   2013-08-20 09:18:08
      nova-compute     s4            nova   enabled    :-)   2013-08-20 09:18:02
      nova-compute     h2            nova   enabled    :-)   2013-08-20 09:18:05
      nova-compute     h0            nova   enabled    :-)   2013-08-20 09:18:01
      nova-compute     h1            nova   enabled    :-)   2013-08-20 09:18:06
      nova-compute     h3            nova   enabled    :-)   2013-08-20 09:18:02
      nova-compute     h4            nova   enabled    :-)   2013-08-20 09:18:09
      nova-network     ineri         nova   enabled    :-)   2013-08-20 09:18:10
      nova-compute     h5            nova   enabled    :-)   2013-08-20 09:18:01

See all services (as known by Keystone)::

      keystone service-list

      +----------------------------------+----------+----------+----------------------------+
      |                id                |   name   |   type   |        description         |
      +----------------------------------+----------+----------+----------------------------+
      | e41d0b7e2f364189a442a677657db49e |  cinder  |  volume  |       Cinder Service       |
      | d7188fd2a5504633ade3fb8bbe1f5afc |  glance  |  image   |  Openstack Image Service   |
      | ffb5f63bf9084ac38a76d61ade92cb6b | keystone | identity | OpenStack Identity Service |
      | b45443a3c004475b8de10a3df875ef1e | neutron  | network  | Neutron Networking Service |
      | d189af89a6bb4b91a977dfafdb7d6ed5 |   nova   | compute  | Openstack Compute Service  |
      | 99949218c3cd49829a2ca3539420ab9f | nova_ec2 |   ec2    |        EC2 Service         |
      | 6f87b03cb7e54d20a9dc331ef815f2d1 | quantum  | network  | Quantum Networking Service |
      +----------------------------------+----------+----------+----------------------------+


Tenants and Users
-----------------

Ask Keystone about tenants and users::

      keystone tenant-list
      +----------------------------------+----------+---------+
      |                id                |   name   | enabled |
      +----------------------------------+----------+---------+
      | 4eaf2faefeb24f009ae45d9203b3df86 |  admin   |   True  |
      | 2c5ca19175da4cecab75d36db3c49865 | services |   True  |
      +----------------------------------+----------+---------+

      keystone user-list
      +----------------------------------+-----------+---------+-------------------+
      |                id                |    name   | enabled |       email       |
      +----------------------------------+-----------+---------+-------------------+
      | dfa143180d8a400695454fab67bf5488 |   admin   |   True  |   root@localhost  |
      | efa139165b6c41f49fa99f4f0fa75155 |   casutt  |   True  |                   |
      | 4d0966badc094fee8a60c55f07ff7342 |   cinder  |   True  |  cinder@localhost |
      | 8ac340a82d59424cbab79d5d5fe0f424 |   glance  |   True  |  glance@localhost |
      | 05df48f1d98c409ebf822aa067ac3f78 | jcfischer |   True  |                   |
      | 13c69fd2491346018c1059564899b75f |  neutron  |   True  | neutron@localhost |
      | c74cea758acb42848d3b6f9fb806332b |    nova   |   True  |   nova@localhost  |
      | 6ef6585145264e67be1a96cccba20820 |  quantum  |   True  | quantum@localhost |
      +----------------------------------+-----------+---------+-------------------+


Running instances
-----------------

To see, what VMs are running on your srevers::

      nova list --all-tenants
      +------+--------------------------------------------+-----------+--------------------------------------+
      | ID   | Name                                       | Status    | Networks                             |
      +------+--------------------------------------------+-----------+--------------------------------------+
      | ...  | devstack-simon                             | SHUTOFF   | novanetwork=10.0.0.12, 199.99.999.25 |
      | ...  | disk_test                                  | ACTIVE    | novanetwork=10.0.0.27, 199.99.999.44 |
      | ...  | jcf                                        | SHUTOFF   | novanetwork=10.0.0.39, 199.99.999.54 |
      | ...  | test3                                      | ACTIVE    | novanetwork=10.0.0.22, 199.99.999.35 |
      | ...  | test4                                      | ACTIVE    | novanetwork=10.0.0.19, 199.99.999.30 |
      +------+--------------------------------------------+-----------+--------------------------------------+

To see more about a specifc VM, ask for some details using the `uuid`::

     nova show 80f6f0f0-23fe-46d6-83c0-1a8f1e2f459b
     +-------------------------------------+-------------------------------------------------------------+
     | Property                            | Value                                                       |
     +-------------------------------------+-------------------------------------------------------------+
     | OS-DCF:diskConfig                   | MANUAL                                                      |
     | OS-EXT-SRV-ATTR:host                | h3                                                          |
     | OS-EXT-SRV-ATTR:hypervisor_hostname | h3.bcc.switch.ch                                            |
     | OS-EXT-SRV-ATTR:instance_name       | instance-00000193                                           |
     | OS-EXT-STS:power_state              | 1                                                           |
     | OS-EXT-STS:task_state               | None                                                        |
     | OS-EXT-STS:vm_state                 | active                                                      |
     | accessIPv4                          |                                                             |
     | accessIPv6                          |                                                             |
     | config_drive                        |                                                             |
     | created                             | 2013-07-29T12:36:58Z                                        |
     | flavor                              | x1.tiny (10)                                                |
     | hostId                              | 006b27a88836c79e0eeef96b2cdadc0ac7dfec81b945d078ed8b7f63    |
     | id                                  | 80f6f0f0-23fe-46d6-83c0-1a8f1e2f459b                        |
     | image                               | SwitchPadSnap_130729 (b0a03468-75f9-47b7-a590-1b7cbce669ca) |
     | key_name                            | jcf                                                         |
     | metadata                            | {}                                                          |
     | name                                | SwitchPad                                                   |
     | novanetwork network                 | 10.0.0.49, 199.99.999.64                                    |
     | progress                            | 0                                                           |
     | security_groups                     | [{u'name': u'default'}, {u'name': u'Webservice'}]           |
     | status                              | ACTIVE                                                      |
     | tenant_id                           | 9030aced43824fb39aa02b56f5e8dd50                            |
     | updated                             | 2013-07-30T11:17:26Z                                        |
     | user_id                             | f92fd1b7ebc6404eabcc76df20a58e73                            |
     +-------------------------------------+-------------------------------------------------------------+

Note: It depends on the access level you have to the tenant/project how much information you are seeing.

Behind the scenes
-----------------

If you administer an OpenStack installation, it is helpful to know how the actual pieces fit together. A central piece
of the system is to run VMs. OpenStack uses a normal hypervisor for that and the VMs are under control of that
hypervisor, with OpenStack (or rather nova specifically) orchestrates everything.

In our setup, we are using KVM as the hypervisor, so if you have any specific problems, it is useful to know how KVM
goes about doing its work.

From the `nova show` command, you can see which of your compute nodes the VM is running on. In the example above, the VM
is running on the host named `s3` and has the name `instance-00000193`. This is the information you need to find out
more about it. When you ssh to the host, you will find the files belonging to that instance in
`/var/lib/nova/instances/` like so::

        root@h3:/var/lib/nova/instances/instance-00000193# ll -h
        total 638M
        drwxrwxr-x 1 nova         nova   52 Jul 29 14:38 ./
        drwxr-xr-x 1 nova         nova  232 Aug 10 14:57 ../
        -rw-rw---- 1 libvirt-qemu kvm     0 Jul 30 13:16 console.log
        -rw-r--r-- 1 libvirt-qemu kvm  638M Aug 20 13:13 disk
        -rw-rw-r-- 1 nova         nova 1.4K Jul 29 14:37 libvirt.xml


`libvirt.xml` is the control defintion of the VM and generated by nova. Take a peek inside to see information about
network drivers and volumes. Should you ever wish to change the contents of libvirt.xml you can do so (behind the back
of nova). After you have edited `libvirt.xml`, do the following::

        virsh destroy instance-xxxxxx
        virsh undefine instance-xxxxxx
        virsh define /var/lib/nova/instance-xxxxxxx/libvirt.xml
        vish start instance-xxxxxx

Resetting the state of a VM
---------------------------

Flavours
--------

Resizing a VM
-------------


Migrating a VM to another host
------------------------------


