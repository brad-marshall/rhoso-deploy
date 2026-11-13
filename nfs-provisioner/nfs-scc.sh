#!/bin/sh

oc adm policy add-scc-to-user hostmount-anyuid system:serviceaccount:nfs-provisioner:nfs-client-provisioner
