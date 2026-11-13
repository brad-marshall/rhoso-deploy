# RHOSO 18 Lab Deployment

This repo is for a basic RHOSO 18 lab deployment.  For more details on RHOSO 18 see [the official documentation](https://docs.redhat.com/en/documentation/red_hat_openstack_services_on_openshift/18.0)

It initially only includes the basic services:
* Keystone - Authentication
* Glance - Image Services
* Cinder - Volume Services
* Neutron - Networking Services
* Nova - Compute Services
* and associated support services like rabbitmq, galera etc

## Assumed Hardware

* 3 x Openshift control plane nodes
* 1 x Compute node - needs to have RHEL9 installed on it, and pre-setup with ssh keys

There will almost certainly need to be changes made to the network setup, including IP ranges etc.

For more information on these services please see the the docs at [Red Hat OpenStack Services on Openshift](https://docs.redhat.com/en/documentation/red_hat_openstack_services_on_openshift/18.0)

# Deployment

This deployment methodolgy was initially created by following the documentation available at [official Red Hat documentation](https://docs.redhat.com/en/documentation/red_hat_openstack_services_on_openshift/18.0/html/deploying_red_hat_openstack_services_on_openshift/index).

## Network Topology

We are using the following vlans in the proof of concept installation.  In the labs, the ctlplane and storage networks are existing and have smaller ranges as there are servers already using these networks.  The internalapi and tenant networks (and any others we require) are new.  Need to sort out what we're doing for external network.

| Network name | CIDR | NetConfig allocation range | MetalLB IPAddressPool range | net-attach-def IPAM range | RHOCP worker nncp range | Proposed VLAN
| --- | --- | --- | --- | --- | --- | --- |
| ctlplane | 10.76.23.0/24 | 10.76.23.40 - 10.76.23.43 | 10.76.23.37-10.76.23.39 | 10.76.23.44 - 10.76.23.47| TBD | N/A |
| storage | 172.16.10.0/24 | 172.16.10.30 - 172.16.10.33 | n/a | 172.16.10.38 - 172.16.10.40 | 172.16.10.34 - 172.16.10.37 | TBD | 10 |
| internalapi | 172.16.20.0/24 | 172.16.20.100 - 172.16.20.250 | 172.16.20.80 - 172.16.20.90 | 172.16.20.30 - 172.16.0.70 | 172.16.20.10 - 172.16.20.20 | TBD | 20 |
| tenant | 172.16.21.0/24 | 172.16.21.100 - 172.16.21.250 | n/a | 172.16.21.30 - 172.16.21.70 | 172.16.21.10 - 172.16.21.20 | TBD | 21 |

## Deployment

For the compute node, once a base install has been done, you should make sure its registered with satellite.
```
subscription-manager register --username <username>
subscription-manager release --set=9.4
dnf update
```


The compute node needs a FQDN hostname, the fix when found was:
```
sudo hostnamectl set-hostname compute1.ctlplane.rhoso.rhlab.local
```

### Openshift Deployment

We are using agent based installer for this.  

First, setup the credentials in the agent-setup/install-config.yaml file.  See
the README.creds.md.  This is *very important* to ensure you can access the
registries.  

If you are doing a 3 node compact customer, review the README.ingress-fix.md 
file to set the replicas on ingress to 3, not 2.  If you start seeing connection
refused, see if this is the issue you are seeing.

Copy the yaml files from the agent-setup subdir, then run:

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

To generate the full pxe files, see the following.  This will likely be useful
for a disconnected install, as it has the rootfs needed for the install.

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

This is assuming a 3 node Openshift cluster - to deploy, boot from the minimal ISO file on the "main" controller node, and wait for it to get to a steady state.  Then boot the other 2, one at a time, and let them finish.  

While waiting for the bootstrap to complete, watch something like:

```
openshift-install agent wait-for bootstrap-complete --dir=./<installer_dir> --log-level=info
```

and to see the install finish:

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

### Openstack Deployment

Once the Openshift control plane is deployed, its time to roll out Openstack!

If you are using NFS, the NFS subdir provisioner deployment is in the nfs-provisioner subdirectory.

The following is the expected deployment rollout for the control and data planes:

```
##############
# Set the nfs virt selinux boolean
oc apply -f ./machineconfig-nfs.yaml
# Install NMState Operator
oc apply -f ./openshift-nmstate-namespace.yaml
oc apply -f ./openshift-nmstate-operatorgroup.yaml
oc apply -f ./openshift-nmstate-subscription.yaml
oc apply -f ./openshift-nmstate-instance.yaml
# Install cert-manager
oc apply -f ./openshift-certmanager-namespace.yaml
oc apply -f ./openshift-certmanager-operatorgroup.yaml
oc apply -f ./openshift-certmanager-subscription.yaml
# Install MetalLB operator
# This needs to have the metallb creation split out, maybe an oc wait on the previous metallb steps
oc apply -f ./openshift-metallb-operator.yaml
# Add the openstack subscriptions
oc apply -f ./openstack-subscription.yaml
# Add the catalog source 
oc apply -f ./openstack-catalog-source.yaml
# If the install plan is on manual:
./openstack-subscription-approval.sh
# Create the operator
oc apply -f ./openstack-operator.yaml
# Create new project openstack, ensure has privileged pod creation
oc apply -f ./openstack-project.yaml
# Generate the service secrets
./openstack_service_secret.sh
# Now apply secret
oc apply -f ./openstack_service_secret.yaml
# Now create networks
# https://docs.redhat.com/en/documentation/red_hat_openstack_services_on_openshift/18.0/html/deploying_red_hat_openstack_services_on_openshift/assembly_preparing-rhoso-networks_preparing
# One nncp per host - split into one worker per file
#oc apply -f ./openstack-nncp-worker1.yaml
#oc apply -f ./openstack-nncp-worker2.yaml
#oc apply -f ./openstack-nncp-worker3.yaml
# Consolidate down to one file
oc apply -f ./openstack-nncp.yaml
# This defines the IP ranges for the pods
oc apply -f ./openstack-net-attach-def.yaml
# See https://docs.redhat.com/en/documentation/red_hat_openstack_services_on_openshift/18.0/html/deploying_red_hat_openstack_services_on_openshift/assembly_preparing-rhoso-networks_preparing#proc_preparing-RHOCP-for-RHOSO-network-VIPs_preparing_networks
# This defines the IP ranges for MetalLB load balancers - this is for RHOSO services
oc apply -f ./openstack-ipaddresspools.yaml
# This maps the MetalLB ipaddresspools to an interface
oc apply -f ./openstack-l2advertisement.yaml
# This defines CIDRs, allocation ranges, reserved IPs etc
oc apply -f ./openstack-netconfig.yaml
###### TODO - Setup keystone ldap auth, this needs way more details
#oc create domain <name>
#oc apply -f ./openstack-keystone-domain.yaml
# Setup nfs provisioner
oc apply -f ./nfs-provisioner/nfs-provisioner-setup.yaml
oc apply -f ./nfs-provisioner/nfs-rbac.yaml
./nfs-provisioner/nfs-scc.sh
oc apply -f ./nfs-provisioner/nfs-deployment.yaml
oc apply -f ./nfs-provisioner/nfs-storageclass.yaml
# Create the cinder nfs secret
oc apply -f ./secrets-cinder-nfs.yaml
# Create glance pvc
oc apply -f ./glance-pvc.yaml
# Create the TLS issuers
oc apply -f ./tls-issuers.yaml
# Apply cinder nfs configmap
oc apply -f ./openstack-cinder-nfs-configmap.yaml
oc apply -f ./openstack-cinder-nfs-pvc.yaml
# Create the cinder permissions
oc apply -f ./openstack-cinder-nfs-perms.yaml
# Now create control plane
oc apply -f ./openstack_control_plane.yaml
# Once the control plane is deployed:
oc exec -it openstackclient -n openstack -- openstack domain create idm
# Add a group osp-admin to your LDAP backend
oc exec -it openstackclient -n openstack role add --group osp-admin --group-domain idm --domain idm admin
# To add a ldap group to a openstack project:
#oc exec -it openstackclient -n openstack role add --group osp-member --group-domain idm --project dev-project --project-domain idm member

# Now dataplane
# Create ssh key, registry secret and instance migration key
# Make sure the ssh key in the dataplane-ansible-ssh-private-key-secret is in the
# ansibleUser's authorized_keys and the user has passwordless ssh
./dataplane_ssh_key.sh
./dataplane_instance_migration_key.sh
./secret-metallb-memberlist.sh
oc apply -f ./secret-redhat-registry.yaml
oc apply -f ./secret-subscription-manager.yaml
# Libvirt secret
oc apply -f ./secret-libvirt.yaml
## TEST: changing ansiblee environment
#oc apply -f ./openstack-ansibleee-configmap.yaml
# Logs for deploy
oc apply -f ./openstack_dataplane_logs_pvc.yaml
# Dataplane nodeset
oc apply -f ./openstack_dataplane_nodeset.yaml
# Dataplane deploy
oc apply -f ./openstack_dataplane_deploy.yaml

# Deploy gai.conf to use IPv4 first
oc apply -f ./openstack-compute-gai-conf.yaml
# Deploy external dns masq server for compute nodes to use
oc apply -f ./openstack-dnsmasq-external.yaml
# Apply custom dns to use internal endpoints
# In prod we should use metallb or similar
oc apply -f ./openstack-custom-dnsdata.yaml

### NOTE ###
# This section is no longer needed after changing to Agent Installer
# Generate the machine config
# ./create-ovs-machineconfig.sh
# oc apply -f ./99-worker-ovs-interfaces.yaml
# Hacky fix for rabbitmq routes and forwarding
#./create-rabbitmq-dnat-machineconfig.sh
#oc apply -f ./99-worker-rabbitmq-dnat-fix.yaml
## END SECTION ##

# Create the external IP pools
./create-external-networks.sh
```

## Post Deployment Activities

To see if there are any compute nodes found run:

```
oc exec -n openstack -c nova-cell1-conductor-conductor statefulset/nova-cell1-conductor -- nova-manage cell_v2 list_hosts
```

If there aren't any, you can trigger off a discover:

```
oc exec -n openstack -c nova-cell1-conductor-conductor statefulset/nova-cell1-conductor -- nova-manage cell_v2 list_hosts
```

A very basic deployment would be:

```
curl -L -O https://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img
openstack image create "cirros"   --file cirros-0.6.2-x86_64-disk.img   --disk-format qcow2   --container-format bare   --public
openstack network create int-net
openstack subnet create int-subnet --network int-net --subnet-range 10.0.0.0/24
openstack flavor create --ram 512 --disk 5 --vcpus 1 m1.tiny
openstack server create --flavor m1.tiny --image cirros --network int-net test-vm
```

## Openstack Command Line

To run openstack command line you can setup the normal CLI authentication, or
you can use the provided pod:

```
oc exec -it openstackclient -n openstack -- openstack volume service list
```

## Customizable Locations

There are multiple places you may need to change - there is almost certainly more 
than listed:

* openstack-nnnp.yaml - this is where you define the OCP nodes networking
* openstack-net-attach-def.yaml - defines the multus config for control plane and data plane pods
* openstack-netconfig.yaml - defines the subnets and available IPs for dataplane nodes
* openstack-ipaddresspools.yaml - defines metallb pools
* openstack-l2advertisement.yaml - defines how networks are advertised
* openstack\_control\_plane.yaml - where to even start - cinder nfs server, load balancer IPs,
                                 AD keystone integration, possibly more
* openstack\_dataplane\_nodeset.yaml - dns servers, IPs, all sorts of things
* openstack-custom-dnsdata.yaml - IPs for endpoints required for openstack cli dns resolution

## Status of Deployment

* This is not fully documented in what needs to be changed for a different network
  setup etc.  There is likely to be some missing details in these docs.  There will
  also likely be integration setups required for things like authentication, and
  storage.  These are not covered here.
* There are also likely to be setting that are done for the lab proof of concept,
  things like the network configuration, dns entries required, and doubtless more
  that need to be addressed depending on the architecture of the deployment.
* For production, we will have to investigate using a proper MetalLB route or
  similar to expose the services we want to use to the external networks required,
  and also fix up the DNS so it resolves externally to the deployed cluster.
* Compute node was deployed in lab booting from RHEL ISO and enrolled using
  Brad Marshall's service account credentials.
* Production environment will look very different to lab.  At a minimum will 
  need to have 2 seperate bonds / NICs - one for OCP, and one for the RHOSO networks.
  It will depend on workload and storage bandwidth requirements if splitting
  the storage or any other networks make sense.

### Assisted Installer vs Agent Installer
* The initial deployment was done using Assisted Installer, and later moved to
  Agent installer once it was clearly the better route.  This may mean there is
  some left overs from that older way of doing things that need to be tidied up.
* There are fixes for certain networking issues done using MachineConfig, specifically
  by the create-ovs-machineconfig.sh and create-rabbitmq-dnat-machineconfig.sh scripts.
  These should be addressed by working out a proper NNCP and NetAttachDefinition or
  a proper Agent installer of Openshift, and not reliant on boot scripts.
  *NOTE*: This has been done, we are no longer going to use Assisted Installer,
  rather Agent Installer.  These steps are no longer necessary.
* OCP deployed using Assisted Installer from RH Hybrid Cloud Console, will need
  a different deployment method for production.
  *NOTE*: This has been done, we are no longer going to use Assisted Installer,
  rather Agent Installer.  These steps are no longer necessary.

## TODO Notes

* Get an external network setup so we can do floating / direct attached IPs
* Currently the deploy needs some extra settings to make openstack cli work as we don't have an externally routable network
  * Set OS\_INTERFACE=internal
  * Set OS\_AUTH\_URL=https://keystone-internal.ctlplane.rhoso.rhlab.local:5000/v3
  * Once we have proper routed networks we shouldn't need this
* Change creds for registry - currently using a personal service account
* Fix the file permissions on the nfs fileshare stuff - it was made world writeable
  while doing the initial configuration, figure out what account to use to stop that
* DNS needs to have external domain setup
  * Have done some work on how this can be managed
  * Need to populate DNS records based on the generated hostnames
  * Subnets need to be routable as well - currently internalapi and tenant are not
* openstack-keystone-domain.yaml is currently set to auth against IDM in the labs
  * Need to figure out AD for production - initial draft config in as comments - needs details
  * Import AD's domain controller root certs into control plane's trusted certs
  * Use a dedicated keystone domain for it
  * Use a read only service account to query user and groups
  * Possible useful instructions at [How to Integrate Active Directory with OpenStack for User Management](https://openmetal.io/resources/blog/how-to-integrate-active-directory-with-openstack-for-user-management/)
* Figure out how to do this all disconnected
* Check if jumbo frames will work in the lab
  * Confirm switches are setup for it
  * If it does, need to fix cluster network MTU for OVN-Kubernetes

oc edit network.operator.openshift.io cluster

Set:
```
spec:
  defaultNetwork:
    ovnKubernetesConfig:
      mtu: 8900 # Or 9000 depending on your underlying physical cluster MTU
```
  * Probably a lot else
