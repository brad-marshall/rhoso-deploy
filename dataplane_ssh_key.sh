#!/bin/sh

oc create secret generic dataplane-ansible-ssh-private-key-secret \
    --save-config \
    --dry-run=client \
    --from-file=authorized_keys=./ssh/dataplane-ansible-ssh-key.pub \
    --from-file=ssh-privatekey=./ssh/dataplane-ansible-ssh-key \
    --from-file=ssh-publickey=./ssh/dataplane-ansible-ssh-key.pub \
    -n openstack -o yaml | oc apply -f -
