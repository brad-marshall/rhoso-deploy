# Agent Based RHOSO Installer

We are using the agent based installer for this.  Copy the yaml files from
the agent-setup subdir, then run:

```
$ openshift-install agent create image --dir=./rhoso18-installer
INFO Configuration has 3 master replicas, 0 arbiter replicas, and 0 worker replicas
INFO The rendezvous host IP (node0 IP) is 10.76.23.30
INFO Extracting base ISO from release payload
INFO Base ISO obtained from release and cached at [/home/brmarsha/.cache/agent/image_cache/coreos-x86_64.iso]
INFO Consuming Agent Config from target directory
INFO Consuming Install Config from target directory
INFO Generated ISO at rhoso18-installer/agent.x86_64.iso.
```

Set the openshift nodes to boot from the iso and cross fingers.
The agent-config.yaml should look like the following, just repeat the stanza for
the hostname for each host:

```
apiVersion: v1beta1
kind: AgentConfig
metadata:
  name: rhoso18-poc
hosts:
  # ================= NODE 0 =================
  - hostname: master1.rhoso.rhlab.local
    role: master
    interfaces:
      - name: ens2f0
        macAddress: 54:AB:3A:70:D3:BD
      - name: ens2f1
        macAddress: 54:AB:3A:70:D3:BE
    networkConfig:
      interfaces:
        - name: ens2f0
          type: ethernet
          state: up
        - name: ens2f1
          type: ethernet
          state: up
        - name: bond0
          type: bond
          state: up
          link-aggregation:
            mode: 802.3ad
            options:
              miimon: "100"
              lacp_rate: "fast"
            port: 
              - ens2f0
              - ens2f1
          ipv4:
            enabled: true
            address: 
              - ip: 10.76.23.30
                prefix-length: 24
            dhcp: false
            auto-dns: false
      dns-resolver:
        config:
          server:
            - 10.76.23.245
            - ....
      routes:
        config:
          - destination: 0.0.0.0/0
            next-hop-address: 10.76.23.254
            next-hop-interface: bond0
```

The install-config.yaml should look like:

```
apiVersion: v1
baseDomain: rhoso.rhlab.local
metadata:
  name: rhoso-ocp
compute:
- hyperthreading: Enabled
  name: compute
  replicas: 0
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: 3
networking:
  networkType: OVN-Kubernetes
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  serviceNetwork:
  - 172.30.0.0/16
  machineNetwork:
  - cidr: 10.76.23.0/24
platform:
  none: {}
pullSecret: '{"auths",.....}'
sshKey: 'ssh-ed25519 ....'
```

You can grab the pull secret from the hybrid cloud console in the downloads.

https://console.redhat.com/openshift/overview
Resources | Downloads | Tokens | Pull Secret

The openshift-install binary is from the same page
Resources | Downloads | OpenShift installation  | OpenShift for x86\_64 Installer

For OpenShift use MACs for the OCP Mezzanine card
For OpenStack use the MACs for the PCIe card

Make sure the api and api-int records either point to a load balancer IP - hardware or metal, or are a round robin for the 3 master nodes.
- need to apply agent-setup/manifests/cluster-ingress-default.yaml when building the image or run the following after agent installer and you inevitably forget:
```
oc patch ingresscontroller/default -n openshift-ingress-operator --type=merge -p '{"spec":{"replicas":3}}'
```

Once the install is done, you can get the URL and credentials from

```
openshift-install agent wait-for install-complete --dir=./<installer_dir>
```

It should look something like:

```
INFO cluster bootstrap is complete                
INFO Cluster is installed                         
INFO Install complete!                            
INFO To access the cluster as the system:admin user when using 'oc', run 
INFO     export KUBECONFIG=/path/to/installer/auth/kubeconfig 
INFO Access the OpenShift web-console here: https://console-openshift-console.apps.<domain>
INFO Login to the console with user: "kubeadmin", and password: "<password>" 
```


# PXE Based File Generation

In case you need it, to generate the full pxe files:

```
$ openshift-install agent create pxe-files --dir=./rhoso18-installer/
INFO Configuration has 3 master replicas, 0 arbiter replicas, and 0 worker replicas
INFO The rendezvous host IP (node0 IP) is 10.76.23.30
INFO Extracting base ISO from release payload
INFO Verifying cached file
INFO Using cached Base ISO /home/brmarsha/.cache/agent/image_cache/coreos-x86_64.iso
INFO Consuming Agent Config from target directory 
INFO Consuming Install Config from target directory 
INFO PXE boot artifacts created in: rhoso18-installer/boot-artifacts 
INFO Kernel parameters for PXE boot: rw  ignition.firstboot ignition.platform.id=metal 
```

This generates the following files:

1. agent.x86_64-vmlinuz (The kernel)
2. agent.x86_64-initrd.img (The initial ramdisk)
3. agent.x86_64-rootfs.img (The core filesystem file you need)

It's an exercise for the reader on what you do with it from here if you need to
go down this route.
