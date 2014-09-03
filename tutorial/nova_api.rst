Compute service - nova-api
==========================

As we did for the glance node before staring it is good to quickly
check if the remote ssh execution of the commands done in the `all
nodes installation <basic_services.rst#all-nodes-installation>`_
section worked without problems. You can again verify it by checking
the ntp installation.

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
    mysql> GRANT ALL ON nova.* TO 'nova'@'%' IDENTIFIED BY 'gridka';
    mysql> FLUSH PRIVILEGES;
    mysql> exit


As we did before, on the **auth-node** we have to create a pair of
user and password for nova, but in this case we need to create **two**
different services and endpoints, since OpenStack also has a
compatibility layer to Amazon EC2 API:

compute
    allows you to manage OpenStack instances

ec2
    compatibility layer on top of the nova service, which allows you
    to use the same APIs you would use with Amazon EC2

First of all we need to create a keystone user for the nova service,
associated with the **service** tenant::

    root@auth-node:~# keystone user-create \
        --name=nova --pass=gridka --tenant service
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
      --service nova
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
      --service ec2
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

The main configuration file for all `nova-*` services is
``/etc/nova/nova.conf``. In this case we need to update, as usual,
MySQL, RabbitMQ nad Keystone options.

In ``/etc/nova/nova.conf`` add a ``[database]`` section::

    [database]
    connection = mysql://nova:gridka@10.0.0.3/nova

In ``[DEFAULT]`` section, update RabbitMQ configuration options::

    [DEFAULT]
    ...
    rpc_backend = rabbit
    rabbit_host = 10.0.0.3
    rabbit_password = gridka

For keystone integration, ensure ``auth_strategy`` option is set in
``[DEFAULT]`` section, and add a ``[keystone_authtoken]`` section::

    [DEFAULT]
    ...
    auth_strategy = keystone

    [keystone_authtoken]
    auth_uri = http://10.0.0.4:5000
    auth_host = 10.0.0.4
    auth_port = 35357
    auth_protocol = http
    admin_tenant_name = service
    admin_user = nova
    admin_password = gridka

Finally, a few options related to vnc display need to be changed in
``[DEFAULT]`` section::

   [DEFAULT]
   ...
   my_ip = 10.0.0.11
   vncserver_listen = 10.0.0.11
   vncserver_proxyclient_address = 10.0.0.11

Also, since we want to contact the glance server using the management
network, we will also update option ``glance_api_servers``::

    [DEFAULT]
    ...
    glance_api_servers=10.0.0.5:9292

..
   ::
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

    root@api-node:~# for serv in \
        nova-{api,conductor,scheduler,novncproxy,consoleauth,cert};\
        do service $serv restart; done

``nova-manage`` can be used to check the status of the services::

    root@api-node:~# nova-manage service list
    Binary           Host                                 Zone             Status     State Updated_At
    nova-conductor   api-node                             internal         enabled    :-)   2014-08-16 16:18:53
    nova-scheduler   api-node                             internal         enabled    :-)   2014-08-16 16:18:48
    nova-consoleauth api-node                             internal         enabled    :-)   2014-08-26 16:18:54
    nova-cert        api-node                             internal         enabled    :-)   2014-08-16 16:18:52

Similar output is given by ``nova service-list`` and ``nova
host-list`` commands, although ``nova-manage`` has direct access to
the database, therefore must run on an host with the correct
``nova.conf``, while the ``nova`` commands uses the network API, so
you can run them from a computer not part of the cloud.

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

The ``nova`` command line tool is the main command used to manage
instances, volumes etc, but we need to complete the OpenStack
installation in order to test it.


Horizon
-------

On the **api-node**::

    root@api-node:# apt-get install openstack-dashboard

Edit the file ``/etc/openstack-dashboard/local_settings.py`` and
update the ``OPENSTACK_HOST`` variable::

    OPENSTACK_HOST = "auth-node.example.org"

From the **physical node** you can connect to the api-node node by
opening the URL ``http://172.16.0.6/horizon`` on your web browser


..
   Keystone is then checking on what the users/tenants are "supposed" to
   see (in terms of images, quotes, etc). Working nodes are periodically
   writing their status in the nova-database. When a new request arrives
   it is processed by the nova-scheduler which writes in the
   nova-database when a matchmaking with a free resource has been
   accomplished. On the next poll when the resource reads the
   nova-database it "realizes" that it is supposed to start a
   new VM. nova-compute writes then the status inside the nova database.

   Different scheduling policy and options can be set in the nova's configuration file.


Notes on EC2 compatible interface
---------------------------------

The EC2 compatibility layer in nova is provided by the **nova-api**
service together with the native interface. There also is a
**nova-api-ec2** service which is used *as a replacement* of
**nova-api** if you only need the EC2 API and you don't want the
native apis, although in our case we need both.

The EC2 compatibility layer, however, need one more configuration
option we didn't define. 

Edit ``/etc/nova/nova.conf`` on the **api-node** and add the following
option::

    keystone_ec2_url=http://auth-node.example.org:5000/v2.0/ec2tokens

Please note that this is an url pointing to the keystone service, but
with an additional ``ec2tokens``. This is used by the **nova-api**
service to validate ec2-style tokens, and by default points to
localhost.

working with the EC2 interface
++++++++++++++++++++++++++++++

To access an EC2 endpoint you need to get an **access key** and a
**secret key**. These are temporary tokens you can create and delete,
so that you don't have to use your login and password all the time,
and you can actually *lend* them to other people to allow them to run
virtual machines on your behalf without having to give them your login
and password. You can delete them whenever you want.

To create a new pair of ec2 credentials you can run::

    root@api-node:~# keystone ec2-credentials-create
    +-----------+----------------------------------+
    |  Property |              Value               |
    +-----------+----------------------------------+
    |   access  | c22f5770ee924f25b4c7b091f521b15f |
    |   secret  | 78b92ddde8134b46a05dbd91023e27db |
    | tenant_id | acdbdb11d3334ed987869316d0039856 |
    |  user_id  | 13ff2976843649669c4911ec156eaa3f |
    +-----------+----------------------------------+

You can later on delete a pair of ec2 credentials with ``keystone
ec2-credentials-delete --access <access_key>``

If you want to test the EC2 interface the easiest way is to install
the **euca2ools** tool::

    root@api-node:~# apt-get install euca2ools

and then run, for instance, the command::

    root@api-node:~# euca-describe-images \
      --access-key c22f5770ee924f25b4c7b091f521b15f \
      --secret-key 78b92ddde8134b46a05dbd91023e27db \
      -U http://api-node.example.org:8773/services/Cloud
    IMAGE	ami-00000001	None (Cirros-0.3.0-x86_64)	0aacc603e6dd425caa51db0d07957412	available	private			machine				instance-store

There are two things to note about this command:

* the URL we are using this time is *not* the keystone url. This
  because the service providing the EC2 compatibility layer is
  **nova-api** instead, so we have to use the URL we used as endpoint
  for the **ec2** service

* the image id returned by the previous command is *not* directly
  related to the image id used in glance. Instead, it is an ``ami-*``
  id (similar to the IDs used by amazon images). Actually, there is no
  easy way to get the ami id knowing the glance id, so you have to
  use the image name whenever it is possible to identify the right
  image.

Also for the euca2ools and for most of the EC2 libraries, setting the
following environment variables allows you to avoid explicitly specify
access/secret keys and endpoint url::

    root@api-node:~# export EC2_ACCESS_KEY=445f486efe1a4eeea2c924d0252ff269
    root@api-node:~# export EC2_SECRET_KEY=ff98e8529e2543aebf6f001c74d65b17
    root@api-node:~# export EC2_URL=http://api-node.example.org:8773/services/Cloud


`Next: nova-network - Network service - *easy* version <nova_network.rst>`_
