#!/bin/bash
# Configuration variables - adjust these to match your lab
EXT_NET_NAME="datacentre-ext"
PHYSICAL_NET="datacentre"
VLAN_ID="100"                      # Your lab VLAN ID
CIDR="172.16.20.0/24"              # Your lab subnet
GATEWAY="172.16.20.1"             # Physical gateway IP
POOL_START="172.16.20.100"         # Safe start IP for OpenStack
POOL_END="172.16.20.150"           # Safe end IP for OpenStack

# 1. Create External Network
openstack network create ${EXT_NET_NAME} \
  --external \
  --provider-network-type vlan \
  --provider-physical-network ${PHYSICAL_NET} \
  --provider-segment ${VLAN_ID}

# 2. Create Subnet with Restricted Allocation Pool
openstack subnet create ${EXT_NET_NAME}-subnet \
  --network ${EXT_NET_NAME} \
  --subnet-range ${CIDR} \
  --gateway ${GATEWAY} \
  --allocation-pool start=${POOL_START},end=${POOL_END} \
  --no-dhcp
