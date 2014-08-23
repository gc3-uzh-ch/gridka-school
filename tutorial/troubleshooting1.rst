Troubleshooting challenge session
---------------------------------

The idea of this session is to try to learn how to debug an OpenStack
installation.

Below there is a list of proposed *sabotages* that you can do on your
machines. The idea is that each one of you will perform one or more of
these *sabotages* and then will switch with someone else.

Then, you will have to check that the installation is working
(actually, find what is *not* working as expected) and try to fix the
problem.


proposed sabotages (but you can be creative!)
+++++++++++++++++++++++++++++++++++++++++++++

* Remove the "admin" role from one of the "nova", "glance", "cinder"
  users::

    root@auth-node:~# keystone user-role-remove \
      --user-id <user_id> \
      --role-id fafa8117d1564d8c9ec4fe6dbf985c68 \
      --tenant-id cb0e475306cc4c91b2a43b537b1a848b

  and see what does **not** work anymore.

* remove or replace with an invalid IP address the ``rabbit_host``
  configuration option on one of the configuration file and restart
  the service.

* Fill the ``/var/lib/nova/instances`` directory by creating a big
  file using dd, and try to start a virtual machine

* shutdown one of the services at the time and see what does not work
  anymore:

  - rabbitmq
  - mysql
  - nova-api
  - nova-network
  - glance-api
  - glance-registry
  
  try to start virtual machines both with the ``nova`` command line
  tool and via web interface and check if there are differences.

* Set a *wrong* password in ``/etc/nova/nova.conf`` file on the
  **api-node** for the sql connection, restart all the nova services

* Do the same, but for the **glance-api** service

* Do the same, but for the **glance-registry** service

* Do the same, but for the **cinder** service

* Similarly, try to put the wrong *keystone* password on one of the
  main services.

* Try to remove ``iscsi_ip_address` from ``/etc/cinder/cinder.conf``
  (or just replace the address it with an invalid one) and restart the
  cinder services. Then, try to create a volume and attach it to a
  running instance.

* remove all the floating IPs with the ``nova-manage floating
  delete``. Play also with the ``auto_assign_floating_ip`` option of
  the ``/etc/nova/nova.conf`` configuration file. (if you are very
  mean, you can replace the floating IPs with similar but invalid ones)

List of possible checks
+++++++++++++++++++++++

* upload an image
* start an instance using ``nova``
* start an instance using the web interface
* create a snapshot (both from web and command line)
* create a volume (both from web and command line)
* attach a volume to a running instance (web/CLI)
* connect to the instance using ssh
* connect to the instance on a port different than 22 (hint: use
  netcat or ssh)
* start an instance using ``euca-start-instances`` (note: we didn't
  tell you how to do it)

.. Notes:
   * missing information about the metadata service
   * missing info about the user-data
   * missing detailed information on the security groups
   * missing info about 
   * FIXME: next time, use images with updated software, to avoid a
     long delay when running apt-get upgrade
   * missing info on the ec2 compatible interface
   * not discussion about multi-node/single-node network

.. elasticluster:
   on the node
   (elasticluster)root@gks-246:[~] $ lsb_release -a
   LSB Version:	:base-4.0-amd64:base-4.0-noarch:core-4.0-amd64:core-4.0-noarch:graphics-4.0-amd64:graphics-4.0-noarch:printing-4.0-amd64:printing-4.0-noarch
   Distributor ID:	Scientific
   Description:	Scientific Linux release 6.4 (Carbon)
   Release:	6.4
   Codename:	Carbon

   (elasticluster)root@gks-246:[~] $ pip install elasticluster

   (elasticluster)root@gks-246:[~] $ elasticluster list-templates
   Traceback (most recent call last):
     File "/root/elasticluster/bin/elasticluster", line 8, in <module>
       load_entry_point('elasticluster==1.0.2', 'console_scripts', 'elasticluster')()
     File "/root/elasticluster/lib/python2.6/site-packages/setuptools-0.6c11-py2.6.egg/pkg_resources.py", line 318, in load_entry_point
     File "/root/elasticluster/lib/python2.6/site-packages/setuptools-0.6c11-py2.6.egg/pkg_resources.py", line 2221, in load_entry_point
     File "/root/elasticluster/lib/python2.6/site-packages/setuptools-0.6c11-py2.6.egg/pkg_resources.py", line 1954, in load
     File "/root/elasticluster/lib/python2.6/site-packages/elasticluster/main.py", line 32, in <module>
       from elasticluster.subcommands import Start, SetupCluster
     File "/root/elasticluster/lib/python2.6/site-packages/elasticluster/subcommands.py", line 27, in <module>
       from elasticluster.conf import Configurator
     File "/root/elasticluster/lib/python2.6/site-packages/elasticluster/conf.py", line 33, in <module>
       from elasticluster.providers.gce import GoogleCloudProvider
     File "/root/elasticluster/lib/python2.6/site-packages/elasticluster/providers/gce.py", line 37, in <module>
       from oauth2client.tools import run
     File "/root/elasticluster/lib/python2.6/site-packages/oauth2client/tools.py", line 27, in <module>
       import argparse
   ImportError: No module named argparse


.. elasticluster:
   still problems with default configuration. Comment all the clusters
   but the needed one. If you change the name of the hobbes cloud you
   get a useless configuration error: "c"

   Also remove the id_dsa.cloud.pub key!

.. elasticluster:
   move the cluster sections just below the cloud section.

.. elasticluster: delete an instance, you will get an error and the vm
   appear "building". Instead, it should be removed and re-created.

.. elasticluster on centos: it seems it is not ignoring the
   known_hosts, even though it's saying so. TO TEST
