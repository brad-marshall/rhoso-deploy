## Debugging

### Dataplane Deployments

Most of the dataplane configuration is in openstack_dataplane_nodeset.yaml.
If you have to update the file, you need to make your changes, then something
along the lines of:

```
$ oc delete openstackdataplanedeployments --all
$ oc apply -f ./openstack_dataplane_nodeset.yaml
$ oc apply -f ./openstack_dataplane_deploy.yaml
```

You can watch the logs via:

```
$ oc logs -f -n openstack -l app=openstackansibleee --max-log-requests=100
```

If it stops, just re-run it.  To see how many have been run:

```
$ oc get jobs
```

To check what the status of the nodesets are:

```
$ oc get openstackdataplanenodeset openstack-worker-nodes -n openstack -o jsonpath='{range .status.conditions[*]}{.type}{"\t"}{.status}{"\t"}{.reason}{"\t"}{.message}{"\n"}{end}'
```

### Control Plane Deployments

To trigger a refresh of the control plane:

```
$ oc annotate openstackcontrolplane openstack-control-plane -n openstack forced-reconcile-at="$(date +%s)" --overwrite
```

To remove the finaliser from a deletion if it hangs, you should be able to delete it.

```
$ oc patch mariadbdatabase neutron -n openstack -p '{"metadata":{"finalizers":null}}' --type=merge
```

To view the deployment logs:

```
$ oc logs -f -n openstack -l app=openstackansibleee --max-log-requests=100
```


### General

To run a tcpdump on a worker node, there's a couple of options:

```
$ oc run netdebug --rm -i --tty   --image=nicolaka/netshoot   --overrides='{"spec": {"nodeName": "worker2", "hostNetwork": true, "securityContext": {"privileged":     true}}}'   -- tcpdump -nn -i any icmp or port 53
```

Or from inside an oc debug node/<node>:
```
$ podman run --rm --net=host quay.io/sysadmin/network-tools tcpdump -n -i any host 172.16.20.13 and port 5671
```

If you have ssh access to the worker:

```
ssh core@nodename "sudo podman run --rm --privileged --net=host nicolaka/netshoot tcpdump -nn -i any port 5671"
```

To see the state of MachineConfig:
```
oc get node <nodename> -o custom-columns=\                                         
     DESIRED:.metadata.annotations.'machineconfiguration\.openshift\.io/desiredConfig',\
     CURRENT:.metadata.annotations.'machineconfiguration\.openshift\.io/currentConfig',\
     STATE:.metadata.annotations.'machineconfiguration\.openshift\.io/state',\       
     REASON:.metadata.annotations.'machineconfiguration\.openshift\.io/reason' 
```

To check if Cluster Operators are ok:

```
$ oc get co | grep -v "True.*False.*False"
```

To debug a VM not booting:

```
# Check the scheduler                                                           
$ oc logs -n openstack -l service=nova-scheduler --tail=150                       
# Check the conductor                                                           
$ oc logs -n openstack statefulset/nova-cell1-conductor -c nova-cell1-conductor-conductor --tail=200
```

# Custom DNS Resolution

If you want to resolve lab dns from a different location, and you have IP connectivity to it:

```
$ cat /etc/systemd/resolved.conf.d/rhlab-dns.conf 
[Resolve]
DNS=10.76.23.243 10.76.23.244 10.76.23.245
Domains=~rhlab.local
```

Then:

```
$ systemctl restart systemd-resolved
$ resolvectl status
```


