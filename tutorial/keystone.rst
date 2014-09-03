Keystone: Identity service
--------------------------

The **auth-node** will run *keystone*, also known as *identity service*.

Keystone performs two main tasks:

* stores information about Authentication and Authorizations (*users*,
  *passwords*, *authorization tokens*, *projects* (also known as
  *tenants*) and *roles*
* stores information about available *services* and the URI of the
  *endpoints*.

Every OpenStack client and service needs to access keystone, first to
discover other services, and then to authenticate and authorize each
request. It is thus the main endpoint of an OpenStack installation, so
that by giving the URL of the keystone service, a client can get all
the information it needs to operate on that specific cloud.

In order to facilitate your understanding during this part we add the 
definitions of some termins you may want to give a glimpse while we
are going on:

* *User* is a user of OpenStack.
* *Service catalog* provides a catalog of available OpenStack services with their APIs.
* *Token* is an arbitrary bit of text used to access resources. Each token has a
  scope which describes which resource are accessible with it.
* *Tenant* A container which is used to group or isolate resources and/or identify objects.
  Depending on the case a tenant may map to customer, account, organization or project.
* *Service* is an OpenStack service, such as Compute, Image service, etc.
* *Endpoint* is a network-accessible address (URL), from where you access an OpenStack service.
* *Role* is a presonality that an user assumes that enables him to perform a specific set of
  operations, basically a set of rights and privileges (usually inside a tenant for example).  

Before starting we can quickly check if the remote ssh execution of
the commands done in the `all nodes installation <basic_services.rst#all-nodes-installation>`_ section worked
without problems::

    root@auth-node:~# dpkg -l ntp
    Desired=Unknown/Install/Remove/Purge/Hold
    | Status=Not/Inst/Conf-files/Unpacked/halF-conf/Half-inst/trig-aWait/Trig-pend
    |/ Err?=(none)/Reinst-required (Status,Err: uppercase=bad)
    ||/ Name                                          Version                     Architecture                Description
    +++-=============================================-===========================-===========================-===============================================================================================
    ii  ntp                                           1:4.2.6.p5+dfsg-3ubuntu2    amd64                       Network Time Protocol daemon and utility programs

which confirmed ntp is installed as required.

Keystone
++++++++

Keystone stores information about different, independent services:

* Users, passwords and tenants
* authorization tokens
* service catalog

These can be stored on different locations, for instance you can store
tokens using `memcached
<http://memcached.org/>`_, user/password/tenant informations on LDAP,
and the service catalog on a file.

However, the easiest way to configure keystone and possibly the most
common is to use MySQL for all of them, therefore this is how we are
going to configure it.

On the **db-node** you need to create a database and a pair of user
and password for the keystone service::

    root@db-node:~# mysql -u root -p
    mysql> CREATE DATABASE keystone;
    mysql> GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'gridka';
    mysql> GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'gridka';
    mysql> FLUSH PRIVILEGES;
    mysql> exit

Please note that almost every OpenStack service will need a private
database, which means that we are going to run commands similar to the
previous one a lot of times.

Go to the **auth-node** and install the keystone package::

    root@auth-node:~# aptitude install keystone python-mysqldb

This step installes also the `keystone-pythonclient` package (as a
dependency of the keystone package) which is the CLI for interactig
with keystone.

..
   **NOTE** Installing keystone *without* installing also
   python-mysqldb can lead to the following error:
   **014-08-20 15:33:20.956 13334 CRITICAL keystone [-] ImportError: No module named MySQLdb**

The default installation will create an SQLite database in
``/var/lib/keystone/keystone.db``, but as we already stated this is
not going to be used and can be safely removed.::

    root@auth-node:~# rm /var/lib/keystone/keystone.db
 
In order to use the MySQL database we just created, update the value
of the ``connection`` option in section ``[database]`` of the
``/etc/keystone/keystone.conf`` file, in order to match the hostname,
database name, user and password we used. The syntax of this option
is::

    connection = <protocol>://<user>:<password>@<host>/<db_name>

So in our case you need to replace the default option with::

    connection = mysql://keystone:gridka@10.0.0.3/keystone

Now you are ready to bootstrap the keystone database using the
following command::

    root@auth-node:~# keystone-manage db_sync

Restart of the keystone service is again required::

    root@auth-node:~# service keystone restart

Keystone by default listens to two different ports::

    root@auth-node:~# netstat -tnlp
    Active Internet connections (servers and established)
    Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
    tcp        0      0 0.0.0.0:35357           0.0.0.0:*               LISTEN      3080/python     
    tcp        0      0 0.0.0.0:5000            0.0.0.0:*               LISTEN      3080/python     
    [...]


**NOTE:** At the time of writing (01-08-2014), in Ubuntu 14.40
keystone does not write to the log file in
``/var/log/keystone/keystone.log``. In order to enable logging, ensure
the following configuration option is defined in
``/etc/keystone/keystone.conf``::

    log_file = /var/log/keystone/keystone.log

By default, only CRITICAL, ERROR and WARNING messages are logged. To
also log INFO messages, add option::

    verbose = True

while to enable also DEBUG messages, add::

    debug = True


The chicken and egg problem
~~~~~~~~~~~~~~~~~~~~~~~~~~~

In order to create users, projects or roles in keystone you need to
access it using an administrative user (which is not automatically
created at the beginning), or you can also use the "*admin token*", a
shared secret that is stored in the keystone configuration file and
can be used to create the initial administrator password.

The default admin token is ``ADMIN``, but you can (and you **should**,
in a production environment) update it by changing the ``admin_token``
option in the ``/etc/keystone/keystone.conf`` file.

Keystone listens on two different ports, one (5000) is for public access,
while the other (35357) is for administrative access. You will usually access
the public one but when using the admin token you can only use the
administrative one.

To specify the admin token and endpoint (or user, password and
endpoint) you can either use the keystone command line options or set
some environment variables. Please note that this behavior is common
to all OpenStack command line tools, although the syntax and the
command line options may change.

In our case, since we don't have an admin user yet and we need to use
the admin token, we will set the following environment variables::

    root@auth-node:~# export OS_SERVICE_TOKEN=ADMIN
    root@auth-node:~# export OS_SERVICE_ENDPOINT=http://auth-node.example.org:35357/v2.0


Creation of the admin user
~~~~~~~~~~~~~~~~~~~~~~~~~~

In order to work with keystone we have to create an admin user and
a few basic projects and roles.

Please note that we will sometimes use the word ``tenant`` instead of
``project``, since the latter is actually the new name of the former,
and while the web interface uses ``project`` most of the commands
still use ``tenant``.

We will now create two tenants: **admin** and **service**. The first
one is used for the admin user, while the second one is used for the
users we will create for the various services (image, volume, nova
etc...). The following commands will work assuming you already set the
correct environment variables::

    root@auth-node:~# keystone tenant-create --name=admin --description='Admin Tenant'
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |           Admin Tenant           |
    |   enabled   |               True               |
    |      id     | f75b3c5ca094466984a412cab500dcde |
    |     name    |              admin               |
    +-------------+----------------------------------+

    root@auth-node:~# keystone tenant-create --name=service --description='Service Tenant'
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |          Service Tenant          |
    |   enabled   |               True               |
    |      id     | a389a8f0d9a54af4ba96dcaa20a828c8 |
    |     name    |             service              |
    +-------------+----------------------------------+

Create the **admin** user::

    root@auth-node:~# keystone user-create --name=admin --pass=gridka --tenant=admin
    +----------+----------------------------------+
    | Property |              Value               |
    +----------+----------------------------------+
    |  email   |                                  |
    | enabled  |               True               |
    |    id    | 96dcaa32ddc049df84b57295466352c6 |
    |   name   |              admin               |
    | tenantId | f75b3c5ca094466984a412cab500dcde |
    | username |              admin               |
    +----------+----------------------------------+

Go on by creating the different roles::

    root@auth-node:~# keystone role-create --name=admin
    +----------+----------------------------------+
    | Property |              Value               |
    +----------+----------------------------------+
    |    id    | 1f4c8a5244f74b5ba3bc29ad5c2ff277 |
    |   name   |              admin               |
    +----------+----------------------------------+     
    

These roles are checked by different services. It is not really easy
to know which service checks for which role, but on a very basic
installation you can just live with ``_member_`` (to be used for all the
standard users) and ``admin`` (to be used for the OpenStack
administrators). ``_member_`` role is defined by default and is already available. 

Roles are assigned to an user **per-tenant**. However, if you have the
admin role on just one tenant **you actually are the administrator of
the whole OpenStack installation!**

Assign administrative roles to the admin and _member_ users::

    root@auth-node:~# keystone user-role-add --user=admin --role=admin --tenant=admin

Note that the command does not print any confirmation on successful completion. 


Creation of the endpoint
~~~~~~~~~~~~~~~~~~~~~~~~

Keystone is not only used to store information about users, passwords
and projects, but also to store a catalog of the available services
the OpenStack cloud is offering. To each service is then assigned an
*endpoint* which basically consists of a set of three URLs (`public`,
`internal`, `admin`). Each set of URLs is associated with a specific
region, so that you can use the same keystone instance to give
information about multiple regions.

Of course keystone itself is a service ("identity") so it needs its
own service and endpoint.

The "**identity**" service is created with the following command::

     root@auth-node:~# keystone service-create --name=keystone --type=identity --description='Keystone Identity Service'
     +-------------+----------------------------------+
     |   Property  |              Value               |
     +-------------+----------------------------------+
     | description |    Keystone Identity Service     |
     |   enabled   |               True               |
     |      id     | 55d743c4f2a646a1905f30b92276da5a |
     |     name    |             keystone             |
     |     type    |             identity             |
     +-------------+----------------------------------+


The following command will create an endpoint associated to this
service::

      root@auth-node:~# keystone endpoint-create \
      --publicurl http://auth-node.example.org:5000/v2.0 \
      --adminurl http://auth-node.example.org:35357/v2.0 \
      --internalurl http://10.0.0.4:5000/v2.0 \
      --region RegionOne --service keystone
      +-------------+----------------------------------------+
      |   Property  |                 Value                  |
      +-------------+----------------------------------------+
      |   adminurl  |       http://10.0.0.4:35357/v2.0       |
      |      id     |    09a7ee7514554e80a6eebb61267a92cb    |
      | internalurl |       http://10.0.0.4:5000/v2.0        |
      |  publicurl  | http://auth-node.example.org:5000/v2.0 |
      |    region   |               RegionOne                |
      |  service_id |    55d743c4f2a646a1905f30b92276da5a    |
      +-------------+----------------------------------------+ 

The argument of the ``--region`` option is the region name. For
simplicity we will always use the name ``RegionOne`` since we only
have one datacenter...

To get a listing of the available services the command is::

    root@auth-node:~# keystone service-list
    +----------------------------------+----------+----------+---------------------------+
    |                id                |   name   |   type   |        description        |
    +----------------------------------+----------+----------+---------------------------+
    | 55d743c4f2a646a1905f30b92276da5a | keystone | identity | Keystone Identity Service |
    +----------------------------------+----------+----------+---------------------------+

while a list of endpoints is shown by the command::

    root@auth-node:~# keystone endpoint-list
    +----------------------------------+-----------+----------------------------------------+---------------------------+----------------------------+----------------------------------+
    |                id                |   region  |               publicurl                |        internalurl        |          adminurl          |            service_id            |
    +----------------------------------+-----------+----------------------------------------+---------------------------+----------------------------+----------------------------------+
    | 09a7ee7514554e80a6eebb61267a92cb | regionOne | http://auth-node.example.org:5000/v2.0 | http://10.0.0.4:5000/v2.0 | http://10.0.0.4:35357/v2.0 | 55d743c4f2a646a1905f30b92276da5a |
    +----------------------------------+-----------+----------------------------------------+---------------------------+----------------------------+----------------------------------+

Some notes on the type of URLs: 

* *publicurl* is the URL of the client API, and it's used by command
  line clients and external applications.
* *internalurl* is similar to the `publicurl`, but it's meant to be
  used by other OpenStack services, that might not have access to the
  public address of the API, but might be able to access directly the
  internal interface of the API node.
* *adminurl* is used to expose the administrative API. For instance,
  in keystone, creation and deletion of an user is considered an
  `administrative` action and therefore will use this URL.

OpenStack command line tools also allow to change the default endpoint
type. Please refer to the manpage of those commands and look for
`endpoint-type`.

From now on, you can access keystone using the admin user either by
using the following command line options::

    root@any-host:~# keystone --os-username admin --os-tenant-name admin \
        --os-password gridka --os-auth-url http://auth-node.example.org:5000/v2.0
                    <subcommand>

or by setting the following environment variables and run keystone
without the previous options::

    root@any-host:~# export OS_USERNAME=admin
    root@any-host:~# export OS_PASSWORD=gridka
    root@any-host:~# export OS_TENANT_NAME=admin
    root@any-host:~# export OS_AUTH_URL=http://auth-node.example.org:5000/v2.0

If you are going to use the last option it is usually a good practice
to insert those environment variables in the root's ``.bashrc`` file,
or even better on a separate file, for instance ``~/os-credentials``,
that you can load whenever you need to with::

    root@any-host:~# . ~/os-credentials

Of course, in this case it would be better **not** to put the password
in the file, so that the various openstack commands will prompt for
the password, and you will not risk saving sensible information on disk...

Please keep the connection to the `auth-node` open as we will need to
operate on it briefly.

Further information about the keystone service can be found at in the
`official documentation <http://docs.openstack.org/icehouse/install-guide/install/apt/content/ch_keystone.html>`_

`Next: Glance - Image Service <glance.rst>`_

.. NOTE:

   OpenStack clients ???
   ~~~~~~~~~~~~~~~~~~~~~
   **TO-DO** Shell we say something about OpenStack clients too?
   Ref `here: <http://docs.openstack.org/icehouse/install-guide/install/apt/content/ch_clients.html>`_.
