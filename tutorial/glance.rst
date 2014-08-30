Glance - Image Service
======================

``image-node``
--------------

As we did for the auth node before staring it is good to quickly check
if the remote ssh execution of the commands done in the `all nodes
installation <basic_services.rst#all-nodes-installation>`_ section worked without problems. You can again verify
it by checking the ntp installation.

Glance
++++++

**Glance** is the name of the image service of OpenStack. It is
responsible for storing the images that will be used as templates to
start the instances. We will use the default configuration and
only do the minimal changes to match our configuration.

Glance is actually composed of two different services:

* **glance-api** accepts API calls for dicovering the available
  images and their metadata and is used also to retrieve them. It
  supports two protocol versions: v1 and v2; when using v1, it does
  not directly access the database but instead it talks to the
  **glance-registry** service

* **glance-registry** used by **glance-api** to actually retrieve image
  metadata when using the old v1 protocol.

Very good explanation about what glance does is available on `this
blogpost <http://bcwaldon.cc/2012/11/06/openstack-image-service-grizzly.html>`_

glance database and keystone setup
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Similarly to what we did for the keystone service, also for the glance
service we need to create a database and a pair of user and password
for it.

On the **db-node** create the database and the MySQL user::

    root@db-node:~# mysql -u root -p
    mysql> CREATE DATABASE glance;
    mysql> GRANT ALL ON glance.* TO 'glance'@'%' IDENTIFIED BY 'gridka';
    mysql> GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'gridka';
    mysql> FLUSH PRIVILEGES;
    mysql> exit;

On the **auth-node** instead we need to create an **image** service
and an endpoint associated with it. The following commands assume you
already set the environment variables needed to run keystone without
specifying login, password and endpoint all the times.

First of all we create a `glance` user for keystone, belonging to the
`service` tenant. You could also use the `admin` user, but it's better
not to mix things::

    root@auth-node:~# keystone user-create --name=glance --pass=gridka
    +----------+----------------------------------+
    | Property |              Value               |
    +----------+----------------------------------+
    |  email   |                                  |
    | enabled  |               True               |
    |    id    | 36813160162449d7a912548c054a6ef9 |
    |   name   |              glance              |
    | username |              glance              |
    +----------+----------------------------------+ 
    
Then we need to give admin permissions to it::

    root@auth-node:~# keystone user-role-add --tenant=service --user=glance --role=admin

Note that the command does not print any confirmation on successful completion.
Please note that we could have created only one user for all the services, but this is a cleaner solution.

We need then to create the **image** service::

    root@auth-node:~# keystone service-create --name glance --type image \
      --description 'Glance Image Service'
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |       Glance Image Service       |
    |   enabled   |               True               |
    |      id     | 05429191756f4852b935c81c19c21424 |
    |     name    |              glance              |
    |     type    |              image               |
    +-------------+----------------------------------+ 

and the related endpoint::

    root@auth-node:~# keystone endpoint-create --region RegionOne \
        --publicurl 'http://image-node.example.org:9292/v2' \
        --adminurl 'http://image-node.example.org:9292/v2' \
        --internalurl 'http://10.0.0.5:9292/v2' \
        --region RegionOne --service glance
    +-------------+---------------------------------------+
    |   Property  |                 Value                 |
    +-------------+---------------------------------------+
    |   adminurl  |        http://10.0.0.5:9292/v2        |
    |      id     |    3cc1713aaf644c8abf72fadc75697864   |
    | internalurl |        http://10.0.0.5:9292/v2        |
    |  publicurl  | http://image-node.example.org:9292/v2 |
    |    region   |               RegionOne               |
    |  service_id |    05429191756f4852b935c81c19c21424   |
    +-------------+---------------------------------------+

glance installation and configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

On the **image-node** install the **glance** package::

    root@image-node:~# aptitude install glance python-mysqldb

To configure the glance service we need to edit a few files in ``/etc/glance``:

Information on how to connect to the MySQL database is stored in the
``/etc/glance/glance-api.conf`` and ``/etc/glance-registry.conf``
files.  The syntax is similar to the one used in the
``/etc/keystone/keystone.conf`` file, the name of the option is
``connection`` again, in ``[database]`` section. Please edit both
files and change it to (if it's not there, add it to the section)::

    [database]
    ...
    connection = mysql://glance:gridka@10.0.0.3/glance

The Image Service has to be configured to use the message broker. Configuration
information is stored in ``/etc/glance/glance-api.conf``. Please open the file 
and change as follows in the ``[DEFAULT] section``::

     [DEFAULT]
     ...
     rpc_backend = rabbit
     rabbit_host = 10.0.0.3
     rabbit_password = gridka

.. NOTE: I don't think glance is sending notifications at all, as they
   are not needed very often. I think it's used only when you want to
   be notified when an image have been updated.

   Also check `notification_driver` option

Note that by default RabbitMQ is not used by glance, because there
isn't much communication between glance and other services that cannot
pass through the public API. However, if you define this and set the
``notification_driver`` option to ``rabbit``, you can receive
notifications for image creation/deletion.

Also, we need to adjust the ``[keystone_authtoken]`` section so that
it matches the values we used when we created the keystone **glance**
user in both in ``glance-api.conf`` and ``glance-registry.conf``::

    [keystone_authtoken]
    auth_host = 10.0.0.4
    auth_port = 35357
    auth_protocol = http
    admin_tenant_name = service
    admin_user = glance
    admin_password = gridka

Finally, we need to specify which paste pipeline we are using. We are not
entering into details here, just check that the following option is present again
in both ``glance-api.conf`` and ``glance-registry.conf``::

    [paste_deploy]
    flavor = keystone

.. Grizzly note:
   Very interesting: we misspelled the password here, but we only get
   errors when getting the list of VM from horizon. Booting VM from
   nova actually worked!!! 
   
   Found the following explanation here: http://bcwaldon.cc/
   
   glance-registry vs glance-api
   The v1 and v2 Images APIs were implemented with seperate paths to
   the Glance database. The first of which proxies queries through a subsequent
   HTTP service (glance-registry) while the second talks directly to the database. 
   As these two APIs should be talking to an equivalent system, we will be realigning
   their internal paths to talk through the service layer (created with the domain object model)
   directly to the database, effectively deprecating the glance-registry service.


Like we did with keystone, we need to populate the glance database::

    root@image-node:~# glance-manage db_sync

Now we are ready to restart the glance services::

    root@image-node:~# service glance-api restart
    root@image-node:~# service glance-registry restart

As we did for keystone, we can set environment variables in order to
access glance::

    root@image-node:~# export OS_USERNAME=admin
    root@image-node:~# export OS_PASSWORD=gridka
    root@image-node:~# export OS_TENANT_NAME=admin
    root@image-node:~# export OS_AUTH_URL=http://auth-node.example.org:5000/v2.0

Testing glance
~~~~~~~~~~~~~~

First of all, let's download a very small test image::

    root@image-node:~# wget https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img

.. Note that if the --os-endpoint-type is not specified glance will try to use 
   publicurl and if the image-node.example.org is not in /etc/hosts an error 
   will be issued.  

(You can also download an Ubuntu distribution from the official
`Ubuntu Cloud Images <https://cloud-images.ubuntu.com/>`_ website)

The command line tool to manage images is ``glance``. Uploading an image is easy::

    root@image-node:~# glance image-create --name cirros-0.3.0 --is-public=true \
      --container-format=bare --disk-format=qcow2 --file cirros-0.3.0-x86_64-disk.img 
    +------------------+--------------------------------------+
    | Property         | Value                                |
    +------------------+--------------------------------------+
    | checksum         | 50bdc35edb03a38d91b1b071afb20a3c     |
    | container_format | bare                                 |
    | created_at       | 2014-04-24T14:51:50                  |
    | deleted          | False                                |
    | deleted_at       | None                                 |
    | disk_format      | qcow2                                |
    | id               | ee83e7df-a39c-496f-8be4-b604c9594d0e |
    | is_public        | True                                 |
    | min_disk         | 0                                    |
    | min_ram          | 0                                    |
    | name             | cirros-0.3.0                         |
    | owner            | c5709d092e3a46b6b895d31f90593640     |
    | protected        | False                                |
    | size             | 9761280                              |
    | status           | active                               |
    | updated_at       | 2014-04-24T14:51:51                  |
    | virtual_size     | None                                 |
    +------------------+--------------------------------------+

.. Maybe it is worthy to explain all the options we use: 
   * *--name* is the name which will be seen in the Horizon UI 
   * *--is-public* is a binary option which specifies if the uploaded
     image should be publicaly available/visible/used or access should
     be limited to *all* the users of the tenant from where the user 
     uploading the images comes.
   * *--container-format* is the container format of image. It refers to 
     whether the virtual machine image is in a file format that also contains
     metadata about the actual virtual machine. Note that the container format
     string is not currently used by Glance or other OpenStack components, so it
     is safe to simply specify bare as the container format if you are unsure. 
     Acceptable formats: ami, ari, aki, bare, and ovf.
   * *--disk-format* is the disk format of a virtual machine image is the format of
     the underlying disk image. Virtual appliance vendors have different formats for
     laying out the information contained in a virtual machine disk image.  
     Acceptable formats: raw, vhd, vmdk, vdi, iso, qcow2, aki, ari, ami.  

Using ``glance`` command you can also list the images currently
uploaded on the image store::

    root@image-node:~# glance image-list
    +--------------------------------------+--------------+-------------+------------------+---------+--------+
    | ID                                   | Name         | Disk Format | Container Format | Size    | Status |
    +--------------------------------------+--------------+-------------+------------------+---------+--------+
    | 79af6953-6bde-463d-8c02-f10aca227ef4 | cirros-0.3.0 | qcow2       | bare             | 9761280 | active |
    +--------------------------------------+--------------+-------------+------------------+---------+--------+

The cirros image we uploaded before, having an image id of
``79af6953-6bde-463d-8c02-f10aca227ef4``, will be found in::

    root@image-node:~# ls -l /var/lib/glance/images/79af6953-6bde-463d-8c02-f10aca227ef4
    -rw-r----- 1 glance glance 9761280 Apr 24 16:38 /var/lib/glance/images/79af6953-6bde-463d-8c02-f10aca227ef4

You can easily find ready-to-use images on the web. An image for the
`Ubuntu Server 14.04 "Precise" (amd64)
<http://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img>`_
can be found at the `Ubuntu Cloud Images archive
<http://cloud-images.ubuntu.com/>`_, you can download it and upload
using glance as we did before.

If you want to get further information about `qcow2` images, you will
need to install `qemu-utils` package and run `qemu-img info <image
name`.

::
    root@image-node:~# apt-get install -y qemu-utils
    [...]
    root@image-node:~# qemu-img info /var/lib/glance/images/79af6953-6bde-463d-8c02-f10aca227ef4
    image: /var/lib/glance/images/79af6953-6bde-463d-8c02-f10aca227ef4 
    file format: qcow2
    virtual size: 39M (41126400 bytes)
    disk size: 9.3M
    cluster_size: 65536
    Format specific information:
    compat: 0.10


Further improvements
~~~~~~~~~~~~~~~~~~~~

By default glance will store all the images as files in
``/var/lib/glance/images``, but other options are available,
including:

* S3 (Amazon object storage service)
* Swift (OpenStack object storage service)
* RBD (Ceph's remote block device)
* Cinder (Yes, your images can be volumes on cinder!)
* etc...
  
This is changed by the option ``default_store`` in the
``/etc/glance/glance-api.conf`` configuration file, and depending on
the type of store you use, more options are availble to configure it,
like the path for the *filesystem* store, or the access and secret
keys for the s3 store, or rdb configuration options.

Please refer to the official documentation to change these values.

Another improvement you may want to consider in a production environment
is the Glance Image Cache. This option will create a local cache in
the glance server, in order to improve the download speed for most
used images, and reduce the load on the storage backend, possibly
putting multiple glance servers behind a load-balancer like haproxy.

More detailed information can be found `here <http://docs.openstack.org/developer/glance/cache.html>`_  

`[Next: Cinder - Block storage service] <cinder.rst>`_
