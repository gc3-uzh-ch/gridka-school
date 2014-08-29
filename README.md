GridKa School 2014 - Training Session on OpenStack
==================================================

<sub>
   This tutorial is licensed ©2014, licensed under a
   [Creative Commons Attribution/Share-Alike (BY-SA) license](http://creativecommons.org/licenses/by-sa/3.0/).
</sub>

**WARNING WARNING WARNING***
This guide is currently *broken*, and it doesn't work out of the
box. This is **intentional**: studens are requested to find the
bugs!!!

A new, corrected version will be released after the GridKa school is terminated.
**WARNING WARNING WARNING***

Teachers:

* [Antonio Messina](mailto:antonio.s.messina@gmail.com)
* [Tyanko Aleksiev](mailto:tyanko.alexiev@gmail.com)


This guide is to be used as reference for the installation of
OpenStack `Icehouse` during the: `GridKa School 2014 - Training Session
on OpenStack`.

Goal of the tutorial is to end up with a small installation of
OpenStack Icehouse on a set of different Ubuntu 14.04 virtual
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

* Introduction to OpenStack (slides)
* [Tutorial overview](tutorial/overview.rst)
* [OpenStack overview](tutorial/openstack_overview.rst)
* [Installation of basic services](tutorial/basic_services.rst) (MySQL and RabbitMQ)
* [Keystone](tutorial/keystone.rst) (Identity service)
* [Glance](tutorial/glance.rst) (Image service)
* [Cinder](tutorial/cinder.rst) (Block storage service)
* [Nova API](tutorial/nova_api.rst) (Compute service)
* [nova-network](tutorial/nova_network.rst) (Network service - *easy* version)
* [Nova compute](tutorial/nova_compute.rst) - life of a VM (Compute service)
* [Troubleshooting](tutorial/troubleshooting1.rst)
* [Neutron](tutorial/neutron.rst) (Network service - *hard* version)
