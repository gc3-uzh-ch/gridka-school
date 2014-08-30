#!/bin/bash
# @(#)regenerate_vms.sh
#
#
#  Copyright (C) 2014, GC3, University of Zurich. All rights
#  reserved.
#
#  This program is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; either version 2 of the License, or (at your
#  option) any later version.
#
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#

# This script will re-define VMs and re-create instances starting from
# a golden image.

IMAGES=/var/lib/libvirt/images
GOLDEN=$IMAGES/golden.qcow2

## helper functions
PROG="$(basename $0)"
usage () {
cat <<EOF
Usage: $PROG [master|secondary]

This program will re-create the VM instances from scratch.

It WILL DELETE previous image files!

If run with 'master', it will deploy and start the following instances:
* api-node
* db-node
* auth-node
* network-node
* volume-node
* image-node

If run with 'secondary', it will deploy and start the following instances:
* compute-1
* compute-2
* neutron-node

Options:

  --help, -h  Print this help text.

EOF
}

MASTER_NODES="api-node db-node auth-node network-node volume-node image-node"
SECONDARY_NODES="compute-1 compute-2 neutron-node"

case "$1" in
    master)
        NODES=${MASTER_NODES}
        ;;
    secondary)
        NODES=${SECONDARY_NODES}
        ;;
    api-node|db-node|auth-node|network-node|volume-node|image-node|compute-1|compute-2|neutron-node)
        echo "Forcing setting up of node $1, regardless which machine this is"
        NODES=$1
        ;;
    *)
        echo 1>&2 "Missing or wrong argument. Must be either 'master' or 'secondary'" 
        usage
        exit 1
        ;;
esac

echo "Ensure masquerading is set"

if ! iptables-save | grep -q -- "-A POSTROUTING -s 10.0.0.0/24 -j MASQUERADE"
then
    echo "Enabling masquerading"
    iptables -A POSTROUTING -t nat -s 10.0.0.0/24 -j MASQUERADE
fi


echo "First of all, destroy all the instances!"
for node in $NODES
do
    virsh destroy $node 2> /dev/null
done

for node in $NODES
do
    echo "Creating Disk for node $node";
    virsh define /root/$node.xml
    qemu-img create  -b /var/lib/libvirt/images/golden.qcow2 -f qcow2 /var/lib/libvirt/images/$node.img 10G

    if [ $node == "volume-node" ]; then
        echo "Creating extra cinder volume"
        qemu-img create -f qcow2 /var/lib/libvirt/images/volume-node-1.img 10G
    fi

    echo "Starting $node"
    virsh start $node;
    ip=$(getent hosts $node | cut -d ' ' -f1);
    echo -n "Waiting until it's up"
    while ! ping -W 1 -c 1 10.0.0.10 >& /dev/null
    do       
        echo -n '.'
        sleep 1
    done
    echo
    echo -n "Waiting sshd it's up"
    while ! nc -w 1 10.0.0.10 22 >& /dev/null
    do       
        echo -n '.'
        sleep 1
    done
    echo
    echo "Connecting"
    echo "Setting private IP address"
    ssh root@10.0.0.10 -p 22 "echo $node > /etc/hostname; hostname $node; sed -i s/10.0.0.10/$ip/g /etc/network/interfaces;"
    case $node in
        auth-node|api-node|image-node|volume-node|network-node|neutron-node)
            publicip=$(getent hosts $node.example.org | cut -d ' ' -f1)
            ssh root@10.0.0.10 -p 22 "echo -e 'auto eth1\niface eth1 inet static\n  address $publicip\n  netmask 255.255.0.0\n  broadcast 172.16.255.255\n' >> /etc/network/interfaces"
            ;;
    esac
    ssh root@10.0.0.10 -p 22 "poweroff";
    if [ $? -ne 0 ]; then
        echo "Error connecting to host $node. Destroying."
        virsh destroy $node
    else
        echo -n "Shutting down"
        while virsh dominfo $node | egrep ^State | egrep -q ' running$'
        do
            echo -n '.'
            sleep 2
        done
        echo
        virsh start $node
    fi
done
