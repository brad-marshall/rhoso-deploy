NFS Subdir Provisioner
----------------------

Order of deployment:

oc apply -f ./nfs-provisioner-setup.yaml
./nfs-scc.sh
oc apply -f ./nfs-rbac.yaml
oc apply -f ./nfs-storageclass.yaml
oc apply -f ./nfs-deployment.yaml

