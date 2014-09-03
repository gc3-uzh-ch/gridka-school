Next: life of a VM (Compute service) - nova-compute
===================================================

As we did for the network node before staring it is good to quickly
check if the remote ssh execution of the commands done in the `all
nodes installation <basic_services.rst#all-nodes-installation>`_
section worked without problems. You can again verify it by checking
the ntp installation.

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

.. FIXME: let's see if with icehouse nova-compute is using
   nova-conductor by default and nothing else.

   In order to allow the compute nodes to access the MySQL server you must 
   install the **MySQL python library**:: 

       root@compute-1 # apt-get install -y python-mysqldb


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
        pre-up ifconfig eth1 0.0.0.0 
        bridge-ports eth1
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
    br100       8000.525400c71a7b   no      eth1


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
    rabbit_password = gridka
    # nova_url=http://10.0.0.6:8774/v1.1/
    #sql_connection=mysql://novaUser:novaPass@10.0.0.3/nova

    # Imaging service
    glance_api_servers=10.0.0.5:9292
    image_service=nova.image.glance.GlanceImageService

    # Cinder: use internal URl instead of public one.
    cinder_catalog_info = volume:cinder:internalURL

    # Vnc configuration
    novnc_enabled=true
    novncproxy_base_url=http://10.0.0.6:6080/vnc_auto.html
    novncproxy_port=6080
    vncserver_proxyclient_address=10.0.0.20
    vncserver_listen=0.0.0.0

    # Compute #
    compute_driver=libvirt.LibvirtDriver

    # Auth
    use_deprecated_auth=false
    auth_strategy=keystone
    
    [keystone_authtoken]
    auth_uri = http://10.0.0.4:5000
    auth_host = 10.0.0.4
    auth_port = 35357
    auth_protocol = http
    admin_tenant_name = service
    admin_user = nova
    admin_password = gridka
    

..
    # Cinder
    cinder_catalog_info = volume:cinder:internalURL
    # This option has to be set, otherwise cinder
    # will try to use the publicURL (by default) which will
    # generate a "ConnectionError" message because
    # compute hosts have no public interface. 
    # Lets leave this as an exercise for the students.   

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
    compute_driver=libvirt.LibvirtDriver
    [libvirt]
    virt_type=qemu

..
   Was:
       [DEFAULT]
       libvirt_type=qemu
       libvirt_cpu_mode=none

Please note that these are the lines needed on *our* setup because we
have virtualized compute nodes without support for nested
virtualization. On a production environment, using physical machines
with full support for virtualization you would probably need to set::

    [libvirt]
    virt_type=kvm

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
    +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+
    | ID | Name      | Memory_MB | Disk | Ephemeral | Swap | VCPUs | RXTX_Factor | Is_Public |
    +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+
    | 1  | m1.tiny   | 512       | 1    | 0         |      | 1     | 1.0         | True      |
    | 2  | m1.small  | 2048      | 20   | 0         |      | 1     | 1.0         | True      |
    | 3  | m1.medium | 4096      | 40   | 0         |      | 2     | 1.0         | True      |
    | 4  | m1.large  | 8192      | 80   | 0         |      | 4     | 1.0         | True      |
    | 5  | m1.xlarge | 16384     | 160  | 0         |      | 8     | 1.0         | True      |
    +----+-----------+-----------+------+-----------+------+-------+-------------+-----------+


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

`Next: Troubleshooting <troubleshooting1.rst>`_

References
----------
..

   We adapted the tutorial above with what we considered necessary for
   our purposes and for installing OpenStack on 6 hosts.

.. _`Openstack Compute Administration Guide`: http://docs.openstack.org/trunk/openstack-compute/admin/content/index.html



