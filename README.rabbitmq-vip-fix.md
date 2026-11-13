# Workaround: RabbitMQ VIP (172.16.20.86:5671) Ingress Timeout

## Issue Summary
When connecting from an external OpenStack compute node (`compute1`, IP `172.16.20.13`) to the OpenShift-hosted RabbitMQ service (`rabbitmq-cell1`), packets were experiencing silent drops.

*   **Root Cause:** The Linux kernel enforces RFC 3927 by strictly dropping cross-interface routed packets destined for IPv4 link-local addresses (`169.254.0.0/16`) before they reach `FORWARD` or `conntrack` processing.
*   **Trigger:** The RabbitMQ service is exposed via an OVN-Kubernetes LoadBalancer VIP on port 5671 using `externalTrafficPolicy: Local`. External traffic arrives on the secondary VLAN interface (`internalapi`). OVN-Kubernetes DNATs this traffic to `169.254.0.3` (the NodePort target), causing the kernel to drop it because forwarding link-local traffic across `internalapi` is prohibited.

## Applied Solution
To bypass the link-local destination and DNAT directly to the routable Service ClusterIP, a declarative `MachineConfig` (`99-master-rabbitmq-dnat-fix.yaml`) was deployed.

### Components of the Fix
1.  **Sysctl Updates:** Persists `net.ipv4.conf.all.rp_filter=2` and `net.ipv4.conf.default.rp_filter=2` across OpenShift master nodes to prevent reverse path filtering drops.
2.  **Dynamic DNAT Script:** Deploys a bash script (`/usr/local/bin/enforce-rabbitmq-dnat.sh`) that dynamically discovers:
    *   The active LoadBalancer VIP.
    *   The OVN-assigned NodePort.
    *   The local node's routable `ovn-k8s-mp0` interface IP.
3.  **Systemd Service:** Deploys `rabbitmq-dnat-fix.service` to execute the script during node boot. This service injects an overriding `PREROUTING` DNAT rule that points the VIP directly to the routable OVN interface IP (e.g., `10.128.0.2:31836`) rather than `169.254.0.3`.

This configuration automatically adjusts to pod rescheduling or IP reassignments without hardcoding IPs and persists across reboots.

## Long-term Alternative (Recommended)
While the `MachineConfig` systemd workaround resolves the immediate timeout, relying on custom host-level iptables manipulation is not ideal for long-term production maintenance.

**Native Fix:** Migrate the `rabbitmq-cell1` service to use MetalLB for secondary networks.
*   MetalLB assigns the VIP directly to the physical/VLAN interface (`internalapi`) on the node holding the active pod.
*   This uses L2/BGP advertisement on the `internalapi` network, natively bypassing the `OVN-KUBE-ETP` link-local NAT entirely, thereby eliminating the kernel RFC 3927 drop.
*   This approach removes the need for custom scripts and declarative `MachineConfig` overrides.
