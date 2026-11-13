#!/bin/bash
ETP_RULE=$(iptables-save -t nat | grep "OVN-KUBE-ETP" | grep "dport 5671" | grep "169.254.0.3" | head -n1)

if [[ -z "$ETP_RULE" ]]; then
  exit 0
fi

VIP=$(echo "$ETP_RULE" | grep -oP '(?<=-d )\d+\.\d+\.\d+\.\d+')
NODEPORT=$(echo "$ETP_RULE" | grep -oP '(?<=169\.254\.0\.3:)\d+')
OVN_IP=$(ip -4 addr show dev ovn-k8s-mp0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)

if [[ -z "$VIP" || -z "$NODEPORT" || -z "$OVN_IP" ]]; then
  exit 0
fi

RULE="-d ${VIP}/32 -p tcp -m tcp --dport 5671 -j DNAT --to-destination ${OVN_IP}:${NODEPORT}"

if ! iptables -t nat -C PREROUTING $RULE 2>/dev/null; then
  iptables -t nat -I PREROUTING 1 $RULE
fi

