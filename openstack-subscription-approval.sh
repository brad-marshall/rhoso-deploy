#!/bin/bash

INSTALL=$(oc get installplan -n openstack-operators -o json | jq -r '.items[] | select(.spec.approval=="Manual" and .spec.approved==false) | .metadata.name' | head -n1)

oc patch installplan $INSTALL -n openstack-operators --type merge -p '{"spec":{"approved":true}}'
