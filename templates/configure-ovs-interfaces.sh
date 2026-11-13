#!/bin/bash
set -euo pipefail

HOSTNAME="$(hostname -s)"

# 1. Define OVS ports and VLAN tags
declare -A VLAN_MAP=(
  ["internalapi"]="20"
  ["storage"]="10"
  ["tenant"]="21"
)

# 2. Map host-specific IP ranges per network
case "${HOSTNAME}" in
  worker1)
    declare -A IP_MAP=(
      ["internalapi"]="172.16.20.10/24"
      ["storage"]="172.16.10.21/24"
      ["tenant"]="172.16.21.10/24"
    )
    ;;
  worker2)
    declare -A IP_MAP=(
      ["internalapi"]="172.16.20.11/24"
      ["storage"]="172.16.10.22/24"
      ["tenant"]="172.16.21.11/24"
    )
    ;;
  worker3)
    declare -A IP_MAP=(
      ["internalapi"]="172.16.20.12/24"
      ["storage"]="172.16.10.23/24"
      ["tenant"]="172.16.21.12/24"
    )
    ;;
  *)
    echo "No OVS IP mappings for ${HOSTNAME}, exiting."
    exit 0
    ;;
esac

# 1. Wait until OVN-Kubernetes initializes br-ex
until ovs-vsctl br-exists br-ex 2>/dev/null; do
  echo "Waiting for br-ex bridge to be created by OVN-Kubernetes..."
  sleep 3
done

# 2. Purge legacy NM connections and kernel interfaces
for netdev in internalapi storage tenant; do
  ip link delete "$netdev" 2>/dev/null || true
  nmcli con delete "$netdev" 2>/dev/null || true
  rm -f /etc/NetworkManager/system-connections/"$netdev"*.nmconnection
done
nmcli con reload

# 3. Provision ports in OVS and configure Linux interfaces
for IFACE in "${!VLAN_MAP[@]}"; do
  VLAN="${VLAN_MAP[$IFACE]}"
  IP="${IP_MAP[$IFACE]:-}"

if [ -n "$IP" ]; then
    # Retry port check & addition until br-ex exists and accepts the port
    until /usr/bin/ovs-vsctl list-ports br-ex 2>/dev/null | grep -q "^${IFACE}$"; do
      echo "Waiting for br-ex to be ready and attach $IFACE..."
      /usr/bin/ovs-vsctl add-port br-ex "$IFACE" \
        -- set Interface "$IFACE" type=internal \
        -- set Port "$IFACE" tag="$VLAN" 2>/dev/null || true
      sleep 1
    done

    # Ensure correct VLAN tag if port is already present
    /usr/bin/ovs-vsctl set Port "$IFACE" tag="$VLAN"

    # Wait for kernel netdev to register before configuring IP/link state
    while [ ! -d "/sys/class/net/$IFACE" ]; do sleep 0.2; done

    # Set loose rp_filter as soon as the interface device exists
    sysctl -w net.ipv4.conf.$IFACE.rp_filter=2

    /usr/sbin/ip addr replace "$IP" dev "$IFACE"
    /usr/sbin/ip link set "$IFACE" up
  fi
done
