# Red Hat OpenShift & RHOSO: Disconnected (Air-Gapped) Agent Installation Reference

This document outlines the architectural shifts, static infrastructure requirements, and deployment workflows needed to run the OpenShift Agent-based Installer in a fully disconnected environment using the `minimalISO` method.

---

## 1. Architectural Overview

In a connected deployment, the minimal ISO is a tiny (~200MB) boot loader that relies on an active internet connection to download the heavy root file system (`rootfs`) and installation container images directly from Red Hat’s public registries.

In a **disconnected (air-gapped) environment**, all external routes are blocked. The deployment pattern must change so that:
1. The **Minimal ISO** points to a local, trusted HTTP file server to download the `rootfs`.
2. The **OpenShift Engine** points to a local, trusted Container Image Registry to pull down the platform images and the Red Hat OpenShift Services on OpenStack (RHOSO) operators.

---

## 2. Infrastructure Prerequisites

Before generating your installation files, you must stage two foundational services within your isolated network:

### A. Local HTTP File Server (e.g., Nginx, Apache, or Python HTTP module)
* **Purpose**: Hosts the raw `rootfs.img` file.
* **Network Requirement**: Must be accessible by the target nodes (Quanta hardware) on the subnet specified by your NMState configuration during early boot.

### B. Enterprise Container Registry (e.g., Harbor, Quay, or Nexus)
* **Purpose**: Hosts mirrored OpenShift platform images, catalog operators, and RHOSO container payloads.
* **Security Requirement**: Must be configured with valid certificates trusted by your staging machine and the target nodes.

---

## 3. Disconnected Configuration Templates

When transitioning your files, update your active configurations to include local mirror paths and artifact routing.

### `install-config.yaml`
You must add an `imageContentSources` (or `imageDigestMirrors` depending on your exact OCP minor version) configuration block to map public registry paths to your local offline registry.

```yaml
apiVersion: v1
baseDomain: example.com
compute:
- name: worker
  replicas: 3
controlPlane:
  name: master
  replicas: 3
metadata:
  name: rhoso-ocp
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 192.168.126.0/24
  networkType: OVNKubernetes
  serviceNetwork:
  - 172.30.0.0/16
platform:
  none: {}
pullSecret: '{"auths":{"local-registry.internal.lan":{"auth":"YWRtaW46cGFzc3dvcmQ=","email":"admin@lan"}}}'
sshKey: 'ssh-ed25519 AAAAC3...'

# --- Disconnected Additions ---
imageContentSources:
  - mirrors:
      - local-registry.internal.lan/openshift/release
    source: quay.io/openshift-release-dev/ocp-release
  - mirrors:
      - local-registry.internal.lan/openshift/release-images
    source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
```

### `agent-config.yaml`
Activate the minimal ISO parameter and explicitly define the `bootArtifactsBaseURL` pointing to your local web server.

```yaml
apiVersion: v1beta1
kind: AgentConfig
metadata:
  name: rhoso-ocp
rendezvousIP: 192.168.126.10

# --- Disconnected Additions ---
minimalISO: true
bootArtifactsBaseURL: http://internal-webserver.local

hosts:
  - hostname: master-0
    interfaces:
      - name: eth0
        macAddress: 52:54:00:11:22:33
    networkConfig:
      interfaces:
        - name: eth0
          type: ethernet
          state: up
          ipv4:
            enabled: true
            address:
              - ip: 192.168.126.10
                prefix-length: 24
      dns-resolver:
        config:
          search:
            - example.com
          server:
            - 192.168.126.1
    rootDeviceHints:
      deviceName: /dev/sda
```

---

## 4. Extraction & Staging Workflow

Once the configuration files are tailored to your air-gapped network, execute the generation workflow:

1. **Generate the offline assets**:
   ```bash
   openshift-install agent create image --dir .
   ```

2. **Verify Output Structure**:
   The installer detects the `bootArtifactsBaseURL` and extracts the matching root file system payload locally. Your directory will contain:
   * `agent.x86_64.iso` (The tiny ~200MB boot loader payload with embedded local tracking URLs).
   * A `./boot-artifacts/` folder.
   * `boot-artifacts/rootfs.img` (The actual operating system filesystem image).

3. **Stage the File Server Assets**:
   Copy the `rootfs.img` file from your local directory over to your internal web server. Ensure the file path exactly matches the path defined in your configuration:
   ```bash
   scp ./boot-artifacts/rootfs.img user@internal-webserver.local:/var/www/html/ocp-boot/
   ```

4. **Boot the Infrastructure**:
   * Mount the small `agent.x86_64.iso` on your HTTP boot server or via BMC virtual media.
   * Power on the nodes. 
   * The ISO will boot, initialize the static networking defined via NMState, reach out to `http://internal-webserver.localrootfs.img`, download the OS directly into RAM, and smoothly hand off execution to the cluster installer.

