Basic services (MySQL and RabbitMQ)
===================================

``db-node``
-----------

OpenStack components use an SQL database and an AMQP-compatible
system to share the current status of the cloud and to communicate to
each other. Multiple SQL databases are supported, although the most
commonly used is MySQL. Also multiple AMQP systems are supported, but
again, the most common used is RabbitMQ.

Since the architecture is higly distributed, a request done on
an API service (for instance, to start a virtual instance), will
trigger a series of tasks, possibly executed by different services on
different machines. Usually the status of the request is saved on the
database, and whenever some additional task is needed by a different
service, the AMQP system is used to request it.

MySQL and RabbitMQ are therefore very important and very basic
services, used by all the OpenStack components. If something is not
working here, or not working properly, the whole cloud could be
unresponsive or broken.

*(good news is: these services are usually quite reliable, at least
compared to OpenStack)*

update system and install ntp package
+++++++++++++++++++++++++++++++++++++

The following steps need to be done on all the machines. We are going
to execute them step by step on the **db-node** only, and then we will
automate the process on the other nodes.

Connect to the **db-node**::

    root@gks-NNN:[~] $ ssh root@db-node

.. Note: do we actually need to update?

Update the system (can take a while...)::
 
    root@db-nodes:# apt-get update -y
    root@db-nodes:# aptitude upgrade -y

Install the NTP service::

    root@db-nodes:# aptitude install -y ntp

On a production environment, you may want to update ``/etc/ntp.conf``
to point to a local server.


all nodes installation
~~~~~~~~~~~~~~~~~~~~~~

Since those boring steps have to be completed on all the other nodes, we
can run the following script in order to automate this process. This way
the rest of the VMs will have all those steps already done by the time we are
going to work on them. The following command has to run on the **physical machine**::

    root@gks-NNN:[~] $ for host in auth-node image-node api-node \
        network-node volume-node compute-1 compute-2
    do
    ssh -n root@$host "(apt-get update -y; apt-get upgrade -y; aptitude install -y ntp) >& /dev/null &"
    done

**Note:** Icehouse is in the main repository for Ubuntu 14.04. This
means we don't need to add any additional OpenStack repositories. For
info regarding OpenStack and Ubuntu Support Schedule go `here
<https://wiki.ubuntu.com/ServerTeam/CloudArchive>`_.


MySQL installation
++++++++++++++++++

We are going to install both MySQL and RabbitMQ on the same server,
but on a production environment you may want to have them installed on
different servers and/or in HA. The following instructions are
intended to be used for both scenarios.

.. QUESTION: What does it mean "the following instructions are
   intended to be used on both scnearios"? Which schenarios exactly?

Now please move on the db-node where we have to install the MySQL server.
In order to do that please execute::

    root@db-node # aptitude install -y mysql-server python-mysqldb

you will be prompted for a password, it is better to specify a *good*
one, since the MySQL server will be accessible also via internet. You
can use the `pwgen` command to generate random passwords with
reasonable entropy.

For security reasons the MySQL daemon listens on localhost only,
port 3306. This has to be changed in order to make the server
accessible from the all the OpenStack services. Edit the
``/etc/mysql/my.cnf`` file and ensure that it contains the following line::

    bind-address            = 10.0.0.3

This will make the MySQL daemon listen only on the *private*
interface. Please note that in this way you will not be able to
contact it using the *public* interface (172.16.0.3), but this is
usually what you want in a production environment.

The OpenStack official guide states that some of the options of InnoDB
storage engine must be set in the configuration file. In order to do
that add the following lines in the ``[mysqld]`` section of the
``/etc/mysql/my.cf`` file::

    [mysqld]
    # ...
    # This is already the default on MySQL 5.5
    # default-storage-engine = innodb
    collation-server = utf8_general_ci
    init-connect = 'SET NAMES utf8'
    character-set-server = utf8

After changing this line you have to restart the MySQL server::

    root@db-node # service mysql restart

By default Ubuntu 14.04 allows access also from the network. This is a
security risk, so you may want to disable it.

There is a script called ``mysql_secure_installation`` that helps you
modifying some of the defaults found in standard installations, we
would suggest you to run it before proceeding::

    root@db-node:~# mysql_secure_installation
    [...]
    Change the root password? [Y/n] n
    [...]
    Remove anonymous users? [Y/n] Y
    [...]
    Disallow root login remotely? [Y/n] Y
    [...]
    Remove test database and access to it? [Y/n] Y
    [...]
    Reload privilege tables now? [Y/n] Y
    [...]

..
   See `here <http://docs.openstack.org/icehouse/install-guide/install/apt/content/basics-database-controller.html>`_ for info on 
   TO-DO. 

Check that MySQL is actually running and listening on all the interfaces
using the ``netstat`` command. 3306 is the port MySQL listens to::

    root@db-node:~# netstat -nlp|grep 3306
    tcp        0     10 0.0.0.3:3306            0.0.0.0:*               LISTEN      21926/mysqld    


RabbitMQ
++++++++

RabbitMQ is an implementation of the AMQP (Advanced Message Queuing
Protocol), a networking protocol that enables conforming client
applications to communicate with conforming messaging middleware
brokers.

Install RabbitMQ from the ubuntu repository::

    root@db-node:~# aptitude install -y rabbitmq-server
        
RabbitMQ does not need any specific configuration. On a production
environment, however, you might need to create a specific user for
OpenStack services. We are not covering in this tutorial, so please
refer to the `official documentation <http://www.rabbitmq.com/documentation.html>`_.

To check if the RabbitMQ server is running use the ``rabbitmqctl``
command::

    root@db-node:~# rabbitmqctl status
    Status of node 'rabbit@db-node' ...
    [{pid,22806},
     {running_applications,[{rabbit,"RabbitMQ","2.7.1"},
                            {mnesia,"MNESIA  CXC 138 12","4.5"},
                            {os_mon,"CPO  CXC 138 46","2.2.7"},
                            {sasl,"SASL  CXC 138 11","2.1.10"},
                            {stdlib,"ERTS  CXC 138 10","1.17.5"},
                            {kernel,"ERTS  CXC 138 10","2.14.5"}]},
     {os,{unix,linux}},
     {erlang_version,"Erlang R14B04 (erts-5.8.5) [source] [64-bit] [rq:1] [async-threads:30] [kernel-poll:true]\n"},
     {memory,[{total,24098760},
              {processes,9740136},
              {processes_used,9735768},
              {system,14358624},
              {atom,1124433},
              {atom_used,1120213},
              {binary,103368},
              {code,11134393},
              {ets,708784}]},
     {vm_memory_high_watermark,0.39999999980957235},
     {vm_memory_limit,840214118}]
    ...done.

Please keep the connection to the db-node open as we will need to
operate on it briefly.

The message broker uses guest as default user name and password. You
can change that password by simply doing::
 
    root@db-node:~# rabbitmqctl change_password guest gridka

This will change the default password to **gridka**. On a production
environment, **please**, choose a better password (again, you can use
`pwgen` to generate one).

By default RabbitMQ listens on port 5672, on all the available
interfaces::

    root@db-node:~# netstat -tnlp | grep 5672
    tcp6       0      0 :::5672                 :::*                    LISTEN      27903/beam      

In order to prevent this, create (or modify, if it's already there)
the file ``/etc/rabbitmq/rabbitmq-env.conf`` and add the following
line::

    RABBITMQ_NODE_IP_ADDRESS=10.0.0.3

Whenever you update this file, restart the daemon::

    root@db-node:~# service rabbitmq-server restart

and check again::

    root@db-node:~# netstat -tnlp | grep 5672
    tcp        0      0 10.0.0.3:5672           0.0.0.0:*               LISTEN      28661/beam      

Now we will proceed with the other services, but since most of the
services need to create a MySQL account and database, you probably
want to keep a shell opened on the `db-node`.

`Next: Keystone - Identity service <keystone.rst>`_
