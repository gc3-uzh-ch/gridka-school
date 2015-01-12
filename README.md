Master in HPC 2014-2015 - OpenStack Workshop
============================================

<sub>
   This tutorial is licensed ©2015, licensed under a
   [Creative Commons Attribution/Share-Alike (BY-SA) license](http://creativecommons.org/licenses/by-sa/3.0/).
</sub>

**WARNING WARNING WARNING***
This guide is currently *broken*, and it doesn't work out of the
box. This is **intentional**: studens are requested to find the
bugs!!!

**WARNING WARNING WARNING***

Teacher:

* [Antonio Messina](mailto:antonio.s.messina@gmail.com)


This guide is to be used as reference for the installation of
OpenStack `Juno` during the: `Master in HPC - 2014-2015 - OpenStack Workshop`.

Goal of the tutorial is to end up with a small installation of
OpenStack Juno on a set of different Ubuntu 14.04 virtual
machines.

Since our focus is to explain the most basic components of OpenStack
to ease a later deployment on a production environment, the various
services will be installed on different machines, that is the most
desirable setup on production. Moreover, having different services on
different machines will help to better understand the dependencies
among the various services. Some very useful considerations about OpenStack
services distribution can found [here](http://docs.openstack.org/openstack-ops/content/cloud_controller_design.html).
Moreover, we will try to summarize the best practices for every OpenStack
service considered in this tutorial in its relative section. 

Table of contents
-----------------

* Introduction to OpenStack ([pdf slides](presentations/overview/openstack.pdf?raw=true))
* [Tutorial overview](tutorial/overview.rst)
* [OpenStack overview](tutorial/openstack_overview.rst)
* [Installation of basic services](tutorial/basic_services.rst) (MySQL
  and RabbitMQ) ([pdf slides](presentations/db-rabbit/db-rabbit.pdf?raw=true))
* [Keystone](tutorial/keystone.rst) (Identity service)
* [Glance](tutorial/glance.rst) (Image service) ([pdf slides](presentations/glance/glance.pdf?raw=true))
* [Cinder](tutorial/cinder.rst) (Block storage service) ([pdf slides](presentations/cinder/cinder.pdf?raw=true))
* [Nova API](tutorial/nova_api.rst) (Compute service)
* [nova-network](tutorial/nova_network.rst) (Network service - *easy* version)
* [Nova compute](tutorial/nova_compute.rst) - life of a VM (Compute service)
* [Troubleshooting](tutorial/troubleshooting1.rst)
* [Neutron](tutorial/neutron.rst) (Network service - *hard* version)
  ([pdf slides](presentations/neutron/neutron.pdf?raw=true))
