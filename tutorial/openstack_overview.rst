

OpenStack overview
------------------

This tutorial will show how to install the main components of
OpenStack, specifically:

.. image:: ../images/openstack-conceptual-arch.small.png


MySQL
    MySQL database is used together with the RabbitMQ messaging system
    for storing and sharing information about the status of the
    cloud. Alternatively the PostgreSQL software can be also used as
    database backend. We will use default one: MySQL.

RabbitMQ
    Messaging service used for inter-process communication among
    various OpenStack components. Alternatives to RabbitMQ are the
    Qpid and ZeroMQ softwares, in this tutorial we will again use the
    default one: RabbitMQ.

Keystone
    OpenStack service which provides the authentication service and
    works as a catalog of the various services available on the
    cloud. Different backends can be used: in our setup we will store
    login, password and tokens in a MySQL db. 

nova
    OpenStack *orchestrator*: it works as a main API endpoint for
    Horizon and for command line tools, schedule the requests,
    talks to the other OpenStack components to provide the requested
    resources, setup and run the OpenStack instances. It is thus 
    composed of multiple services: **nova-api**, **nova-scheduler**,
    **nova-conductor**, **nova-cert**, ect.

nova-network
    OpenStack service used to configure the network of the instances
    and to optionally provide the so-called *Floating IPs*. IPs that
    can be *attached* and *detached* from an instance while it is
    already running. Those IPs are usually used for accessing the
    instances from outside world.

nova-compute
    OpenStack service which runs on the compute node and is
    responsible of actual managing the OpenStack instances. It 
    supports different hypervisors. The complete list bellow can be found `here
    <http://docs.openstack.org/trunk/openstack-compute/admin/content/selecting-a-hypervisor.html>`_.
    The commonly used one is KVM but due to limitation in our setup we
    will use qemu.

glance
    OpenStack imaging service. It is used to store virtual disks
    used to start the instances. It is split in two different
    services: **glance-api** and **glance-registry**

cinder
    OpenStack volume service. It is used to create persistent volumes which
    can be attached to a running instances later on. It is split
    in three different services: **cinder-api**, **cinder-scheduler**
    and **cinder-volume**

Horizon
    OpenStack Web Interface.

**TODO**: add something more
