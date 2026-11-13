#!/bin/bash

# Add openstack cloud setup stuff here
oc exec -it pod/openstackclient -n openstack -- openstack volume type create nfs
oc exec -it pod/openstackclient -n openstack -- openstack volume type set --property volume_backend_name=nfs nfs

