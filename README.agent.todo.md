
# OpenShift Agent Installer PoC Deployment Playbook (Bare-Metal)


## Phase 1: Overcoming QuantaPlex 2019 Firmware Quirks

When booting the OpenShift Agent Installer via native UEFI HTTP Boot on vintage 2019 QuantaPlex hardware, the bootloader fails during the initial memory allocation phase.
• The Symptom: Motherboard initializes, sends an HTTP HEAD request to inspect the file size of the initial RAM disk (initrd.img), and silently drops the connection without ever firing an HTTP GET request. The kernel boots with an empty RAM block, causing a terminal kernel panic: Kernel panic - not syncing: VFS: Unable to mount rootfs on unknown-block(0,0).
• The Root Cause: Hardcoded architectural memory allocation limitations in early 2019 factory UEFI network stacks. The firmware cannot map a single network buffer large enough to ingest OpenShift's massive 1 GB+ base initrd image via its native HTTPClient stack.
• The Remote Work Bottleneck: Streaming the massive multi-gigabyte OpenShift ISO directly via the HTML5 iKVM virtual media applet over a residential VPN connection triggers latency dropouts, dropping the server into a /dev/disk/by-label/ timeout recovery loop.

## The Solution: The Nested KVM Local Staging Bridge

To bypass home network latency and eliminate the firmware's HTTP file-size restrictions, move the deployment execution layer right next to the physical network switch:
1. Provision a lightweight RHEL or Fedora Desktop VM directly on an existing KVM hypervisor node inside the local office data centre LAN.
2. Connect to the VM remotely via a lightweight graphical session (VNC/X2Go).
3. Open the HTML5 BMC console of the physical QuantaPlex servers inside the staging VM's local browser.
4. Mount the OpenShift agent.iso via the HTML5 CD-ROM media icon. Because the file stream happens entirely over the local office LAN, it transfers instantly with zero packet drops, bypassing the 2019 UEFI HTTP stack limitations completely.

## Clean-Slate Checklist for the Next Run (Once DNS is Aligned)

When you are ready to kick off the next deployment cycle, follow these exact steps to guarantee a clean state:

### Step 1: Populate the Red Hat IPA DNS Zone

The underlying etcd clustering engine will endlessly crash and loop if it cannot resolve its peers. Ensure these records are functional before powering on the servers:
• Master Forward Nodes: A records for master-0, master-1, and master-2.
• Master Reverse Nodes: PTR records fully populated for all three static node IPs.
• API VIP: api.<cluster>.<domain> ➔ Points strictly to 10.76.23.30 (Rendezvous IP).
• Internal API VIP: api-int.<cluster>.<domain> ➔ Points strictly to 10.76.23.30 (Crucial for control plane bootstrap).
• Wildcard Ingress: *.apps.<cluster>.<domain> ➔ Points strictly to 10.76.23.30.

### Step 2: Inject the DNS Name Server into agent-config.yaml

Ensure your manual network configuration explicitly targets your IPA server so the nodes don't pull a generic DNS resolver via fallback DHCP:
yaml
    networkConfig:
      dns-resolver:
        config:
          server:
            - <YOUR_RH_IPA_SERVER_IP>

### Step 3: Clear the Installer Workspace Cache

OpenShift binary assets are consumed on run, and stale logging state blocks asset generation. Wipe the scratchpad entirely:
bash

```
# 1. Purge the old workspace folder
rm -rf ./rhoso18-installer

# 2. Re-create the isolated output folder
mkdir -p ./rhoso18-installer

# 3. Pull fresh copies of your golden YAML configurations
cp ./your-backup-dir/*.yaml ./rhoso18-installer/

# 4. Enforce a read-only lock to stop the binary from consuming/deleting your configs
chmod 444 ./rhoso18-installer/*.yaml
```

###Step 4: Re-generate and Boot

1. Run the asset generator: openshift-install agent create image --dir=./rhoso18-installer/
2. Mount the fresh image via your nested KVM workflow.
3. Set the physical nodes to boot via Virtual CD-ROM (ensure local hard disk is moved to the lowest priority in the BIOS configuration).
4. Monitor the live cluster compilation directly from your local laptop over the VPN:
```
openshift-install agent wait-for bootstrap-complete --dir=./rhoso18-installer/ --log-level=info
```

## Post Installation Check

See if the api and api-int addresses, as well as the apps wildcard entries are pointing to a MetalLB address or the rendezvous address (10.76.23.30)
Likely to need to update the dns to point to the MetalLB address.


