#!/bin/bash

oc create secret generic metallb-memberlist   -n openshift-metallb   --from-literal=secretkey="$(openssl rand -base64 128)"
