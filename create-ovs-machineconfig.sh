# This should really be named 99-master-ovs-interfaces.yaml
cat <<EOF > 99-master-ovs-interfaces.yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: master
  name: 99-master-ovs-interfaces
spec:
  config:
    ignition:
      version: "3.2.0"
    storage:
      files:
      - path: /usr/local/bin/configure-ovs-interfaces.sh
        mode: 493 # 0755
        overwrite: true
        contents:
          source: data:text/plain;charset=utf-8;base64,$(base64 -w0 templates/configure-ovs-interfaces.sh)
    systemd:
      units:
      - name: configure-ovs-interfaces.service
        enabled: true
        contents: |
          [Unit]
          Description=Configure Extra OVS Interfaces on br-ex
          After=ovs-vswitchd.service network-online.target
          Wants=ovs-vswitchd.service network-online.target

          [Service]
          Type=oneshot
          RemainAfterExit=yes
          ExecStart=/usr/local/bin/configure-ovs-interfaces.sh

          [Install]
          WantedBy=multi-user.target
EOF
