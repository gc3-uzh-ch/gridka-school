Cinder - Block storage service
==============================

As we did for the image node before staring it is good to quickly
check if the remote ssh execution of the commands done in the `all
nodes installation <basic_services.rst#all-nodes-installation>`_ section worked without problems. You can again
verify it by checking the ntp installation.

Cinder
++++++

**Cinder** is the name of the OpenStack block storage service. It
allows manipulation of volumes, volume types (similar to compute
flavors) and volume snapshots.

Note that a volume may only be attached to one instance at a
time. This is not a *shared storage* solution like NFS, where multiple
servers can mount the same filesystem. Instead, it's more like a SAN,
where volumes are created, and then accessed by one single server at a
time, and used as a raw block device.

It is important to say that cinder volumes are usually *persistent*,
so they are never deleted automatically, and must be deleted manually
via web, command line or API.

Volumes created by cinder are served via iSCSI to the compute node,
which will provide them to the VM as regular sata disk. These volumes
can be stored on different backends: LVM (the default one), Ceph,
GlusterFS, NFS or various appliances from IBM, NetApp etc.

Possible usecase cinder volume are:
* as a backend for a database
* as a device to be exported via NFS/Lustre/GlusterFS to other VMs
* as a mean for backing up important data created from within a VM

Cinder is actually composed of different services:

**cinder-api** 

    The cinder-api service is a WSGI app that authenticates and routes
    requests throughout the Block Storage system. It can be used
    directly (via API or via ``cinder`` command line tool) but it is
    also accessed by the ``nova`` service and the horizon web
    interface.

**cinder-scheduler** 

    The cinder-scheduler is responsible for scheduling/routing
    requests to the appropriate volume service. As of Juno;
    depending upon your configuration this may be simple round-robin
    scheduling to the running volume services, or it can be more
    sophisticated through the use of the Filter Scheduler. The Filter
    Scheduler is the default in Juno and enables filter on things
    like Capacity, Availability Zone, Volume Types and Capabilities as
    well as custom filters.

**cinder-volume** 

    The cinder-volume service is responsible for managing Block
    Storage devices, specifically the back-end devices themselves.

In our setup, we will run all the cinder services on the same machine,
although you can, in principle, spread them over multiple servers.

The **volume-node** has one more disk (``/dev/vdb``) which will use to
create a LVM volume group to store the logical volumes created by cinder.

cinder database and keystone setup
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

As usual, we need to create a database on the **db-node** and an user
in keystone.

On the **db-node** create the database and the MySQL user::

    root@db-node:~# mysql -u root -p
    mysql> CREATE DATABASE cinder;
    mysql> GRANT ALL ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'mhpc';
    mysql> GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'mhpc';
    mysql> FLUSH PRIVILEGES;
    mysql> exit

On the **auth-node** create a keystone user, a "volume" service and
its endpoint, like we did for the *glance* service. The following
commands assume you already set the environment variables needed to
run keystone without specifying login, password and endpoint all the
times.

First of all we need to create a keystone user for the cinder service, 
associated with the **service** tenant::

    root@auth-node:~# keystone user-create --name=cinder \
    --pass=mhpc --tenant service
    +----------+----------------------------------+
    | Property |              Value               |
    +----------+----------------------------------+
    |  email   |                                  |
    | enabled  |               True               |
    |    id    | 9c8172ba531146bca9a3e64d5667f715 |
    |   name   |              cinder              |
    | tenantId | a389a8f0d9a54af4ba96dcaa20a828c8 |
    | username |              cinder              |
    +----------+----------------------------------+

Then we need to give admin permissions to it::

    root@auth-node:~# keystone user-role-add --tenant service --user cinder --role admin

We need then to create the **volume** service::

    root@auth-node:~# keystone service-create --name cinder --type volume \
      --description 'Volume Service of OpenStack'
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |   Volume Service of OpenStack    |
    |   enabled   |               True               |
    |      id     | 9196c7e637f04e26b9246ee6116dd21c |
    |     name    |              cinder              |
    |     type    |              volume              |
    +-------------+----------------------------------+  

and the related endpoint, using the service id we just got::
        
    root@auth-node:~# keystone endpoint-create --region RegionOne \
      --publicurl 'http://volume-node.ostklab:8776/v1/$(tenant_id)s' \
      --adminurl 'http://volume-node.ostklab:8776/v1/$(tenant_id)s' \
      --internalurl 'http://10.0.0.8:8776/v1/$(tenant_id)s' \
      --region RegionOne --service cinder

    +-------------+------------------------------------------------------+
    |   Property  |                        Value                         |
    +-------------+------------------------------------------------------+
    |   adminurl  |        http://10.0.0.8:8776/v1/$(tenant_id)s         |
    |      id     |           b7216435f3864c70a66e5e3b54bb488e           |
    | internalurl |        http://10.0.0.8:8776/v1/$(tenant_id)s         |
    |  publicurl  | http://volume-node.ostklab:8776/v1/$(tenant_id)s     |
    |    region   |                      RegionOne                       |
    |  service_id |           9196c7e637f04e26b9246ee6116dd21c           |
    +-------------+------------------------------------------------------+

Please note that the URLs need to be quoted using the (') character
(single quote) otherwise the shell will interpret the dollar sign ($)
present in the url.

We should now have three endpoints on keystone::

    root@auth-node:~# keystone endpoint-list
    +----------------------------------+-----------+--------------------------------------------------+---------------------------------------+------------------------------------------------------+----------------------------------+
    |                id                |   region  |                    publicurl                     |              internalurl              |                       adminurl                       |            service_id            |
    +----------------------------------+-----------+--------------------------------------------------+---------------------------------------+------------------------------------------------------+----------------------------------+
    | 3f77c8eca16e436c86bf1935e1e7d334 | RegionOne | http://volume-node.ostklab:8776/v1/$(tenant_id)s | http://10.0.0.8:8776/v1/$(tenant_id)s | http://volume-node.ostklab:8776/v1/$(tenant_id)s | 2561a51dd7494651862a44e34d637e1e |
    | 945edccaa68747698f61bf123228e882 | RegionOne |        http://auth-node.ostklab:5000/v2.0        |       http://10.0.0.4:5000/v2.0       |       http://auth-node.ostklab:35357/v2.0        | 28b2812e31334d4494a8a434d3e6fc65 |
    | e1080682380d4f90bfa7016916c40d91 | RegionOne |        http://image-node.ostklab:9292/v2         |        http://10.0.0.5:9292/v2        |        http://image-node.ostklab:9292/v2         | 6cb0cf7a81bc4489a344858398d40222 |
    +----------------------------------+-----------+--------------------------------------------------+---------------------------------------+------------------------------------------------------+----------------------------------+


basic configuration
~~~~~~~~~~~~~~~~~~~

Let's now go back to the  **volume-node** and install the cinder
packages::

    root@volume-node:~# apt-get install -y cinder-api cinder-scheduler cinder-volume \
      open-iscsi python-mysqldb  python-cinderclient

..
   Ensure that the iscsi services are running::

       root@volume-node:~# service open-iscsi restart

We will configure cinder using LVM as backend for the volume images,
but in order to do that we have to provide a volume group called
``cinder-volume`` (you can use a different name, but you have to
update the cinder configuration file).

The **volume-node** machine has one more disk (``/dev/vdb``) which
we will use for LVM. You can either partition this disk and use those
partitions to create the volume group, or use the whole disk. In our
setup, to keep things simple, we will use the whole disk, so we are
going to:

Create a physical device on the ``/dev/vdb`` disk::

    root@volume-node:~# pvcreate /dev/vdb
      Physical volume "/dev/vdb" successfully created

create a volume group called **cinder-volumes** on it::

    root@volume-node:~# vgcreate cinder-volumes /dev/vdb
      Volume group "cinder-volumes" successfully created

check that the volume group has been created::

    root@volume-node:~# vgdisplay cinder-volumes
      --- Volume group ---
      VG Name               cinder-volumes
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

cinder configuration
~~~~~~~~~~~~~~~~~~~~

..
   In file ``/etc/cinder/api-paste.ini`` edit the **filter:authtoken**
   section and ensure that information about the keystone user and
   endpoint are correct, specifically the options ``service_host``,
   ``admin_tenant_name``, ``admin_user`` and ``admin_password``::

       [filter:authtoken]
       paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
       service_protocol = http
       service_host = 10.0.0.4
       service_port = 5000
       auth_host = 10.0.0.4
       auth_port = 35357
       auth_protocol = http
       admin_tenant_name = service
       admin_user = cinder
       admin_password = cinderServ
       signing_dir = /var/lib/cinder

Now let's configure Cinder. The main file is
``/etc/cinder/cinder.conf``.

First of all, we need to configure the information to connect to MySQL
and RabbitMQ, as usual. Update the section ``[DEFAULT]`` and add
``sql_connection``, ``rabbit_host`` and ``rabbit_password`` options::

    [DEFAULT]
    [...]
    sql_connection = mysql://cinder:gridka@10.0.0.3/cinder
    rabbit_host = 10.0.0.3
    rabbit_password = mhpc
    ..
       rpc_backend = cinder.openstack.common.rpc.impl_kombu

Default values for all the other options should be fine. Please note
that here you can change the name of the LVM volume group to use, and
the default name to be used when creating volumes.

.. iscsi_ip_address is needed otherwise, in our case, it will try to
   connect using 192.168. network which is not reachable from the
   OpenStack VMs.

In some cases, you might need to define the ``iscsi_ip_address``,
which is the IP address used to serve the volumes via iSCSI. This IP
must be reachable by the compute nodes, and in some cases you may have
a different network for this kind of traffic.

::
    [DEFAULT]
    [...]
    iscsi_ip_address = 10.0.0.8


Finally, let's add a section for `keystone` authentication::

    [keystone_authtoken]
    auth_uri = http://10.0.0.4:5000
    auth_host = 10.0.0.4
    auth_port = 35357
    auth_protocol = http
    admin_tenant_name = service
    admin_user = cinder
    admin_password = mhpc

.. is already set to tgtadm in Juno``iscsi_helper``.

Populate the cinder database (it's not a typo, for cinder it's ``db
sync``, for glance and keystone it's ``db_sync``...)::

    root@volume-node:~# cinder-manage db sync

    2014-08-21 14:19:13.676 3576 INFO migrate.versioning.api [-] 0 -> 1... 
    ....
    2014-08-21 14:19:19.168 3576 INFO migrate.versioning.api [-] 3 -> 4... 
    2014-08-21 14:19:20.270 3576 INFO 004_volume_type_to_uuid [-] Created foreign key volume_type_extra_specs_ibfk_1
    2014-08-21 14:19:20.548 3576 INFO migrate.versioning.api [-] 5 -> 6... 
    ....
    2014-08-21 14:19:25.102 3576 INFO migrate.versioning.api [-] 20 -> 21... 
    2014-08-21 14:19:25.184 3576 INFO 021_add_default_quota_class [-] Added default quota class data into the DB.
    ....
    2014-08-21 14:19:25.395 3576 INFO migrate.versioning.api [-] done


Restart cinder services::

    root@volume-node:~# for serv in cinder-{api,volume,scheduler}; do service $serv restart; done


Testing cinder
~~~~~~~~~~~~~~

Cinder command line tool also allow you to pass user, password, tenant
name and authentication URL both via command line options or
environment variables. In order to make the commands easier to read we
are going to set the environment variables and run cinder without
options::

    root@volume-node:~# export OS_USERNAME=admin
    root@volume-node:~# export OS_PASSWORD=mhpc
    root@volume-node:~# export OS_TENANT_NAME=admin
    root@volume-node:~# export OS_AUTH_URL=http://auth-node.ostklab:5000/v2.0

Test cinder by creating a volume::

    root@volume-node:~# cinder create --display-name test 1
    +---------------------+--------------------------------------+
    |       Property      |                Value                 |
    +---------------------+--------------------------------------+
    |     attachments     |                  []                  |
    |  availability_zone  |                 nova                 |
    |       bootable      |                false                 |
    |      created_at     |      2014-08-21T12:48:30.524319      |
    | display_description |                 None                 |
    |     display_name    |                 test                 |
    |      encrypted      |                False                 |
    |          id         | 4d04a3d2-0fa7-478d-9314-ca6f52ef08d5 |
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
    | 4d04a3d2-0fa7-478d-9314-ca6f52ef08d5 | available |     test     |  1   |     None    |  false   |             |
    +--------------------------------------+-----------+--------------+------+-------------+----------+-------------+

You can easily check that a new LVM volume has been created::

    root@volume-node:~# lvdisplay /dev/cinder-volumes
      --- Logical volume ---
      LV Name                /dev/cinder-volumes/volume-4d04a3d2-0fa7-478d-9314-ca6f52ef08d5
      VG Name                cinder-volumes
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

.. **tgtadm DOES NOT SHOW ANY OUTPUT WHEN THE VOLUME IS NOT ATTACHED, MOVE TO THE TESTING SECTION** 

..
   To show if the volume is actually served via iscsi you can run::

      root@volume-node:~# tgtadm  --lld iscsi --op show --mode target
      Target 1: iqn.2010-10.org.openstack:volume-4d04a3d2-0fa7-478d-9314-ca6f52ef08d5
          System information:
              Driver: iscsi
              State: ready
          I_T nexus information:
          LUN information:
              LUN: 0
                  Type: controller
                  SCSI ID: IET     00010000
                  SCSI SN: beaf10
                  Size: 0 MB, Block size: 1
                  Online: Yes
                  Removable media: No
                  Readonly: No
                  Backing store type: null
                  Backing store path: None
                  Backing store flags: 
              LUN: 1
                  Type: disk
                  SCSI ID: IET     00010001
                  SCSI SN: beaf11
                  Size: 1074 MB, Block size: 512
                  Online: Yes
                  Removable media: No
                  Readonly: No
                  Backing store type: rdwr
                  Backing store path: /dev/cinder-volumes/volume-4d04a3d2-0fa7-478d-9314-ca6f52ef08d5
                  Backing store flags: 
          Account information:
          ACL information:
              ALL


Since the volume is not used by any VM, we can delete it with the
``cinder delete`` command (you can use the volume `Display Name`
instead of the volume `id` if this is uniqe)::

    root@volume-node:~# cinder delete 4d04a3d2-0fa7-478d-9314-ca6f52ef08d5 

Deleting the volume can take some time::

    root@volume-node:~# cinder list
    +--------------------------------------+----------+--------------+------+-------------+----------+-------------+
    |                  ID                  |  Status  | Display Name | Size | Volume Type | Bootable | Attached to |
    +--------------------------------------+----------+--------------+------+-------------+----------+-------------+
    | 4d04a3d2-0fa7-478d-9314-ca6f52ef08d5 | deleting |     test     |  1   |     None    |  false   |             |
    +--------------------------------------+----------+--------------+------+-------------+----------+-------------+

After a while, the volume is deleted, and LV is deleted::

    root@volume-node:~# cinder list
    +----+--------+--------------+------+-------------+----------+-------------+
    | ID | Status | Display Name | Size | Volume Type | Bootable | Attached to |
    +----+--------+--------------+------+-------------+----------+-------------+
    +----+--------+--------------+------+-------------+----------+-------------+
    root@volume-node:~# lvs
      LV     VG        Attr      LSize Pool Origin Data%  Move Log Copy%  Convert
      root   golden-vg -wi-ao--- 7.76g                                           
      swap_1 golden-vg -wi-ao--- 2.00g 

`Next: nova-api - Compute service <nova_api.rst>`_

..
   **AGAIN MOVE TO THE TESTING SECTION, AS HERE IS NOT RELEVANT**::
       
       root@volume-node:~# tgtadm  --lld iscsi --op show --mode target

       root@volume-node:~# lvdisplay 


