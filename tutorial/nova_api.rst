``api-node``
------------

As we did for the glance node before staring it is good to quickly check if the
remote ssh execution of the commands done in the `all nodes installation`_ section 
worked without problems. You can again verify it by checking the ntp installation.

Nova
++++

Nova is composed to a variety of services

Now that he have installed a lot of infrastructure, it is time to actually get the 
compute part of our cloud up and running - otherwise, what good would it be?

In this section we are going to install and configure
the OpenStack nova services. 

db and keystone configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

First move to the **db-node** and create the database::

    root@db-node:~# mysql -u root -p
    
    mysql> CREATE DATABASE nova;
    mysql> GRANT ALL ON nova.* TO 'novaUser'@'%' IDENTIFIED BY 'novaPass';


As we did before, on the **auth-node** we have to create a pair of
user and password for nova, but in this case we need to create two
different services and endpoints:

compute
    allows you to manage OpenStack instances

ec2
    compatibility layer on top of the nova service, which allows you
    to use the same APIs you would use with Amazon EC2

First of all we need to create a keystone user for the nova service,
associated with the **service** tenant::

    root@auth-node:~# keystone user-create \
        --name=nova --pass=novaServ --tenant service
    +----------+----------------------------------+
    | Property |              Value               |
    +----------+----------------------------------+
    |  email   |                                  |
    | enabled  |               True               |
    |    id    | 813c0bb78ddd41d48b129787443b895a |
    |   name   |               nova               |
    | tenantId | cb0e475306cc4c91b2a43b537b1a848b |
    +----------+----------------------------------+

Then we need to give admin permissions to it::
        
    root@auth-node:~# keystone user-role-add --tenant service --user nova --role admin

We need to create first the **compute** service::

    root@auth-node:~# keystone service-create --name nova --type compute \
      --description 'Compute Service of OpenStack'
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |   Compute Service of OpenStack   |
    |      id     | 338d7b7ec7f14622a1fc1a99bd9004bf |
    |     name    |               nova               |
    |     type    |             compute              |
    +-------------+----------------------------------+

and its endpoint::

    root@auth-node:~# keystone endpoint-create --region RegionOne \
      --publicurl 'http://api-node.example.org:8774/v2/$(tenant_id)s' \
      --adminurl 'http://api-node.example.org:8774/v2/$(tenant_id)s' \
      --internalurl 'http://10.0.0.6:8774/v2/$(tenant_id)s' \
      --service-id 338d7b7ec7f14622a1fc1a99bd9004bf
    +-------------+---------------------------------------------------+
    |   Property  |                       Value                       |
    +-------------+---------------------------------------------------+
    |   adminurl  | http://api-node.example.org:8774/v2/$(tenant_id)s |
    |      id     |          50f0260b221a4ea889aa03dc0532d55f         |
    | internalurl |       http://10.0.0.6:8774/v2/$(tenant_id)s       |
    |  publicurl  | http://api-node.example.org:8774/v2/$(tenant_id)s |
    |    region   |                     RegionOne                     |
    |  service_id |          338d7b7ec7f14622a1fc1a99bd9004bf         |
    +-------------+---------------------------------------------------+

then the **ec2** service::

    root@auth-node:~# keystone service-create --name ec2 --type ec2 \
      --description 'EC2 service of OpenStack'
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |     EC2 service of OpenStack     |
    |      id     | a17a1f1d605a4ad58993c6d9a803b2af |
    |     name    |               ec2                |
    |     type    |               ec2                |
    +-------------+----------------------------------+

and its endpoint::

    root@auth-node:~# keystone endpoint-create --region RegionOne \
      --publicurl 'http://api-node.example.org:8773/services/Cloud' \
      --adminurl 'http://api-node.example.org:8773/services/Admin' \
      --internalurl 'http://10.0.0.6:8773/services/Cloud' \
      --service-id a17a1f1d605a4ad58993c6d9a803b2af
    +-------------+-------------------------------------------------+
    |   Property  |                      Value                      |
    +-------------+-------------------------------------------------+
    |   adminurl  | http://api-node.example.org:8773/services/Admin |
    |      id     |         c3194c76b046426eaa2eef73b537298e        |
    | internalurl |       http://10.0.0.6:8773/services/Cloud       |
    |  publicurl  | http://api-node.example.org:8773/services/Cloud |
    |    region   |                    RegionOne                    |
    |  service_id |         a17a1f1d605a4ad58993c6d9a803b2af        |
    +-------------+-------------------------------------------------+

nova installation and configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Now we can continue the installation on the **api-node**::

    root@api-node:~# apt-get install -y nova-novncproxy novnc nova-api \
      nova-ajax-console-proxy nova-cert nova-conductor \
      nova-consoleauth nova-doc nova-scheduler python-novaclient

The file ``/etc/nova/api-paste.ini`` is similar to what we have seen
for cinder and glance. Check that the **[filter:authtoken]** section
is correct::

    [filter:authtoken]
    paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
    auth_host = 10.0.0.4
    auth_port = 35357
    auth_protocol = http
    admin_tenant_name = service
    admin_user = nova
    admin_password = novaServ
    #signing_dir = /tmp/keystone-signing
    # Workaround for https://bugs.launchpad.net/nova/+bug/1154809
    auth_version = v2.0


The main configuration file for nova is  ``/etc/nova/nova.conf``. It
accepts *a lot* of different options to control the behavior of
OpenStack. However, we are only going to change what is
needed. Complete reference for the ``nova.conf`` file can be found on
the `Openstack Compute Administration Guide`_, section 5: `List of
configuration options <http://docs.openstack.org/trunk/openstack-compute/admin/content/list-of-compute-config-options.html>`_

::

    [DEFAULT]
    dhcpbridge_flagfile=/etc/nova/nova.conf
    dhcpbridge=/usr/bin/nova-dhcpbridge
    logdir=/var/log/nova
    state_path=/var/lib/nova
    lock_path=/var/lock/nova
    force_dhcp_release=True
    iscsi_helper=tgtadm
    libvirt_use_virtio_for_bridges=True
    connection_type=libvirt
    root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf
    verbose=True
    ec2_private_dns_show_ip=True
    api_paste_config=/etc/nova/api-paste.ini
    volumes_path=/var/lib/nova/volumes
    enabled_apis=ec2,osapi_compute,metadata

    rpc_backend = nova.rpc.impl_kombu
    rabbit_host=10.0.0.3


    sql_connection=mysql://novaUser:novaPass@10.0.0.3/nova

    # Imaging service
    glance_api_servers=10.0.0.5:9292
    image_service=nova.image.glance.GlanceImageService

    # Vnc configuration
    novnc_enabled=true
    novncproxy_base_url=http://10.0.0.6:6080/vnc_auto.html
    novncproxy_port=6080
    vncserver_proxyclient_address=10.0.0.6
    vncserver_listen=0.0.0.0

    # Compute #
    compute_driver=libvirt.LibvirtDriver

    # Cinder #
    volume_api_class=nova.volume.cinder.API
    osapi_volume_listen_port=5900
    
    auth_strategy=keystone
    [keystone_authtoken]
    auth_host = 10.0.0.4
    auth_port = 35357
    auth_protocol = http
    admin_tenant_name = service
    admin_user = nova
    admin_password = novaServ

Sync the nova database::

    root@api-node:~# nova-manage db sync

Restart all the nova services::

    root@api-node:~# service nova-api restart
    nova-api stop/waiting
    nova-api start/running, process 26273

    root@api-node:~# service nova-conductor restart
    nova-conductor stop/waiting
    nova-conductor start/running, process 26296

    root@api-node:~# service nova-scheduler restart
    nova-scheduler stop/waiting
    nova-scheduler start/running, process 26311

    root@api-node:~# service nova-novncproxy restart
    nova-novncproxy stop/waiting
    nova-novncproxy start/running, process 26326

    root@api-node:~# service nova-consoleauth restart
    nova-novncproxy stop/waiting
    nova-novncproxy start/running, process 26370

    root@api-node:~# service nova-cert restart
    nova-cert stop/waiting
    nova-cert start/running, process 26376

These service should be in ``:-)`` state when running::

    root@api-node:~# nova-manage service list
    Binary           Host                                 Zone             Status     State Updated_At
    nova-conductor   api-node                             internal         enabled    :-)   2013-08-16 16:18:53
    nova-scheduler   api-node                             internal         enabled    :-)   2013-08-16 16:18:48
    nova-cert        api-node                             internal         enabled    :-)   2013-08-16 16:18:52

Testing nova
~~~~~~~~~~~~

So far we cannot run an instance yet, but we can check if nova
is able to talk to the services already installed. As usual, you can
set the environment variables to use the ``nova`` command line
without having to specify the credentials via command line options::

    root@api-node:~# export OS_USERNAME=admin
    root@api-node:~# export OS_PASSWORD=keystoneAdmin
    root@api-node:~# export OS_TENANT_NAME=admin
    root@api-node:~# export OS_AUTH_URL=http://auth-node.example.org:5000/v2.0

you can check the status of the nova service::

    root@api-node:~# nova service-list
    +------------------+----------+----------+---------+-------+----------------------------+
    | Binary           | Host     | Zone     | Status  | State | Updated_at                 |
    +------------------+----------+----------+---------+-------+----------------------------+
    | nova-cert        | api-node | internal | enabled | up    | 2013-08-16T16:24:14.000000 |
    | nova-conductor   | api-node | internal | enabled | up    | 2013-08-16T16:24:15.000000 |
    | nova-scheduler   | api-node | internal | enabled | up    | 2013-08-16T16:24:20.000000 |
    | nova-consoleauth | api-node | internal | enabled | up    | 2013-08-16T16:24:20.000000 |
    +------------------+----------+----------+---------+-------+----------------------------+

but you can also work with glance images::

    root@api-node:~# nova image-list
    +--------------------------------------+--------------+--------+--------+
    | ID                                   | Name         | Status | Server |
    +--------------------------------------+--------------+--------+--------+
    | 79af6953-6bde-463d-8c02-f10aca227ef4 | cirros-0.3.0 | ACTIVE |        |
    +--------------------------------------+--------------+--------+--------+

or create and manage cinder volumes::

    root@api-node:~# nova volume-create --display-name test2 1
    +---------------------+--------------------------------------+
    | Property            | Value                                |
    +---------------------+--------------------------------------+
    | status              | creating                             |
    | display_name        | test2                                |
    | attachments         | []                                   |
    | availability_zone   | nova                                 |
    | bootable            | false                                |
    | created_at          | 2013-08-16T16:26:19.627854           |
    | display_description | None                                 |
    | volume_type         | None                                 |
    | snapshot_id         | None                                 |
    | source_volid        | None                                 |
    | size                | 1                                    |
    | id                  | 180a081a-065b-497e-998d-aa32c7c295cc |
    | metadata            | {}                                   |
    +---------------------+--------------------------------------+
    root@api-node:~# nova volume-list
    +--------------------------------------+-----------+--------------+------+-------------+-------------+
    | ID                                   | Status    | Display Name | Size | Volume Type | Attached to |
    +--------------------------------------+-----------+--------------+------+-------------+-------------+
    | 180a081a-065b-497e-998d-aa32c7c295cc | available | test2        | 1    | None        |             |
    +--------------------------------------+-----------+--------------+------+-------------+-------------+

The ``nova`` command line tool also allow you to run instances, but we
need to complete the OpenStack installation in order to test it.


