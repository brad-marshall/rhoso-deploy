#!/bin/bash

ssh-keygen -f ./ssh/nova-migration-ssh-key -t ecdsa-sha2-nistp521 -N ''

oc create secret generic nova-migration-ssh-key \
--save-config \
--from-file=ssh-privatekey=./ssh/nova-migration-ssh-key \
--from-file=ssh-publickey=./ssh/nova-migration-ssh-key.pub \
-n openstack \
-o yaml | oc apply -f -
