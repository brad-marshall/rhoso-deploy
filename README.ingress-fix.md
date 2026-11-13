# Fixing Replica Count and Round Robin DNS issues

To bake this into the deployment so no manual patching is ever required, you include an IngressController manifest directly in your installer assets before generating the ISO.

Both the standard OpenShift installer and the Agent-Based Installer support injecting Day-0 Custom Resources via an extra-manifests or manifests directory.

Step 1: Create the Ingress Controller Manifest
Create a YAML file specifying replicas: 3:

cluster-ingress-default.yaml

YAML
apiVersion: operator.openshift.io/v1
kind: IngressController
metadata:
  name: default
  namespace: openshift-ingress-operator
spec:
  replicas: 3
Step 2: Inject It into the Installation Workflow
Where you place the file depends on your build stage:

Option A: Using the openshift-install Manifests Workflow (Recommended)
Before creating the agent image, create the manifests directory and drop the manifest in:

Bash
# 1. Have your install-config.yaml and agent-config.yaml ready in <workdir>

# 2. Generate the initial manifests staging directory
./openshift-install agent create manifests --dir=<workdir>

# 3. Copy your custom IngressController manifest into the generated manifests folder
cp cluster-ingress-default.yaml <workdir>/manifests/

# 4. Generate the bootable agent ISO
./openshift-install agent create image --dir=<workdir>
When the installer runs, it merges files in <workdir>/manifests/ into the initial cluster release payloads. When the Ingress Operator boots, it reconciles this object directly to 3 replicas instead of applying its 2-replica default.

Option B: If Using GitOps / Day-0 Automation
If you drive your builds with Ansible, bash, or a pipeline, you can embed the creation step directly:

Bash
mkdir -p <workdir>/manifests
cat <<EOF > <workdir>/manifests/cluster-ingress-default.yaml
apiVersion: operator.openshift.io/v1
kind: IngressController
metadata:
  name: default
  namespace: openshift-ingress-operator
spec:
  replicas: 3
EOF
Why OpenShift Defaults to 2 Replicas
OpenShift targets high availability across standard topologies:

In a 5-node cluster (3 masters + 2 dedicated workers), it schedules 1 router pod per worker (2 total).

In a 3-node compact cluster with round-robin DNS, the 2-replica default leaves an odd node out, creating a 33% chance of routing to a closed port 443 unless you scale it to match your node count or use a load balancer VIP with health checks.

Seeding the manifest with replicas: 3 ensures the router starts as an effective DaemonSet across all three nodes right from the first boot.


# Suggested Bug Report

It feels completely broken when you first run into it, but it stems from OpenShift's legacy assumption about infrastructure.

OpenShift's ingress architecture was designed around two fundamental assumptions:

An external load balancer with active health checks is sitting in front.

In standard enterprise architectures (or cloud IPIs like AWS/GCP/Azure and on-prem F5/HAProxy), you point your DNS to a load balancer VIP. The load balancer health-checks port 443 on all nodes. If an ingress pod isn't running on master1, the load balancer simply doesn't route traffic to master1. From that perspective, running 2 replicas achieves high availability across failure domains without wasting resources on a 3rd pod.

The traditional cluster model separates control plane from compute.

OpenShift was originally strictly 3 masters + N workers. By default, the Ingress Operator has node placement rules targeting the worker role. In a standard deployment with 2+ workers, having 2 replicas makes total sense.

Where the Assumption Breaks
When deploying a compact 3-node cluster (where masters double as workers) and combining it with User-Managed Networking using Round-Robin DNS instead of a VIP/load balancer:

Round-robin DNS is dumb—it has zero concept of health checks or whether a service is actively listening on port 443.

The Ingress Operator detects a 3-node cluster and allows scheduling onto control-plane nodes, but its hardcoded default replica count remains 2.

Mathematically, 2 pods across 3 nodes guarantees 1 node has port 443 closed. Since DNS hands out all 3 IPs equally, roughly 1 out of every 3 requests (including internal operator route health checks) hits the dead node and fails with connection refused.

The operator really should detect a 3-node compact topology without a VIP and automatically set replicas: 3, but because it adheres strictly to its global 2-replica default, it leaves that manual gap for bare-metal round-robin DNS setups. Injecting that Day-0 manifest is the cleanest way to bridge the difference.
