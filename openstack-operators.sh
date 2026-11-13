#!/bin/sh

echo "Approving the install plan..."

INSTALL=$(oc get installplan -n openstack-operators -o json | jq -r '.items[] | select(.spec.approval=="Manual" and .spec.approved==false) | .metadata.name' | head -n1)

oc patch installplan $INSTALL -n openstack-operators --type merge -p '{"spec":{"approved":true}}'

echo "Waiting for it to be installed"

oc wait csv -n openstack-operators -l operators.coreos.com/openstack-operator.openstack-operators="" --for jsonpath='{.status.phase}'=Succeeded

