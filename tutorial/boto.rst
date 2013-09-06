Experimental tutorial Python and boto library
=============================================

.. class:: small

   This tutorial is licensed ©2013, licensed under a `Creative
   Commons Attribution/Share-Alike (BY-SA) license
   <http://creativecommons.org/licenses/by-sa/3.0/>`__.


basic configuration
-------------------

For Python developers and users, there is a very convenient command
that allows you to create a sandbox where you can install all the
optional software you want as regular user, in a clean way. The
command is called `virtualenv
<https://pypi.python.org/pypi/virtualenv>`_, it is available on `PyPI
<http://pypi.python.org>`_ but it is usually available also as
standard package on most distributions. Let's install it using *yum*::

    root@gks-246:[~] $ yum install python-virtualenv

Now we are going to use ``virtualenv`` to create a directory called
``tutorial``. virtualenv will install a few wrapper scripts and a bash
scriptso that after *loading* the environment we will be able to
call **pip** to install packages on our own environment, and to make
the software we install automatically available::

    root@gks-246:[~] $ virtualenv tutorial
    New python executable in tutorial/bin/python
    Installing setuptools............done.
    Installing pip...............done.

    root@gks-246:[~] $ . tutorial/bin/activate

The last command will *enable* the environment. You will notice that
the prompt is changed. To install the boto library just run::

    (tutorial)root@gks-246:[~] $ pip install boto

Now we can start the python interpreter. Since we loaded the
*tutorial* environment, where boto is installed, we will be able to
import the **boto** module::

    (tutorial)root@gks-246:[~] $ python
    Python 2.6.6 (r266:84292, Feb 21 2013, 19:26:11) 
    [GCC 4.4.7 20120313 (Red Hat 4.4.7-3)] on linux2
    Type "help", "copyright", "credits" or "license" for more information.
    >>> import boto

We will also need a class from the ``boto.ec2.regioninfo`` module::


    >>> from boto.ec2.regioninfo import RegionInfo

Set some variables to hold the access key, the host, port and path of
the endpoint::

    >>> ec2access='445f486efe1a4eeea2c924d0252ff269'
    >>> ec2secret='ff98e8529e2543aebf6f001c74d65b17'
    >>> ec2host='api-node.example.org'
    >>> ec2port=8773
    >>> ec2path='/services/Cloud'

We need to create a ``RegionInfo`` class with::

    >>> region = RegionInfo(name="nova", endpoint=ec2host)

And now we can create the main connection object::

    >>> conn = boto.connect_ec2(aws_access_key_id=ec2access, aws_secret_access_key=ec2secret, is_secure=False, port=ec2port, host=ec2host, path=ec2path, region=region)

The object returned is a ``boto.ec2.connection.EC2Connection``
class. Please note that this command will not actually connect to the
API endpoint, so you cannot just check for the return status of the
``connect_ec2`` function to ensure that the connection was successful.

Whenever you call a method, however, a new connection is created if
needed::

    >>> conn.get_all_regions()
    [RegionInfo:nova]

To get a list of all the available keypairs, you can run::

    >>> conn.get_all_key_pairs()
    [KeyPair:gridka-api-node]

This method (as many others) returns a list, even if it only contain a
single element. Let's try to access it::

    >>> keypairs = conn.get_all_key_pairs()
    >>> keypairs[0].name
    u'gridka-api-node'
    >>> keypairs[0].fingerprint
    u'89:37:b8:f2:32:2f:aa:52:06:55:c2:ad:66:83:3a:d6'

However, the Nova implementation of the EC2 apis is not complete. In
fact, if you try to access the actual *data* of the keypair, you will
get no data at all::

    >>> keypairs[0].material
    >>> 

The boto library also allow to get a list of all the available
images::

    >>> images = conn.get_all_images()
    >>> len(images)
    1
    >>> images[0].name
    u'Cirros-0.3.0-x86_64'
    >>> images[0].id
    u'ami-00000001'

You can start a virtual machine starting from the image too::

    >>> res = images[0].run(key_name='gridka-api-node', instance_type='m1.tiny')

The object returned is called *reservation*. There is no concept of
reservation on OpenStack, but everytime you get a list of instances
actually a list of reservations is returned. Each reservation object
has a ``instances`` list object containing all the instances, so in
our case we can access the instance object by running::

    >>> vm = res.instances[0]
    >>> vm.state
    u'pending'

You can update the status of the instance object by calling its
``update()`` method::

    >>> vm.update()
    >>> vm.state
    u'running'

You can terminate the instance by using the ``terminate()`` method::

    >>> vm.terminate()
    >>> vm.state
    u'terminated'

A list of all running instances is accessible using::

    >>> res = images[0].run(key_name='gridka-api-node', instance_type='m1.small')
    >>> reservations = conn.get_all_instances()
    >>> reservations
    [Reservation:r-377mzb0g]

You can also fill a new list with just the instance objects::

    >>> vms = []
    >>> for res in reservations: vms += res.instances


This is the signature of the ``run`` method of the image object::

    run(self, min_count=1, max_count=1, key_name=None, security_groups=None, user_data=None, addressing_type=None, instance_type='m1.small', placement=None, kernel_id=None, ramdisk_id=None, monitoring_enabled=False, subnet_id=None, block_device_map=None, disable_api_termination=False, instance_initiated_shutdown_behavior=None, private_ip_address=None, placement_group=None, security_group_ids=None, additional_info=None, instance_profile_name=None, instance_profile_arn=None, tenancy=None) method of boto.ec2.image.Image instance

However, please note that not all the options are actually compatible
with OpenStack.

Starting a couple VMs at the same time is quite easy now::

    >>> for i in range(10): images[0].run(key_name='gridka-api-node')
