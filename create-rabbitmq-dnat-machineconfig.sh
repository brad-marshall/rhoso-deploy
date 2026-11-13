cat <<EOF > 99-master-rabbitmq-dnat-fix.yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: master
  name: 99-master-rabbitmq-dnat-fix
spec:
  config:
    ignition:
      version: 3.2.0
    storage:
      files:
        - path: /etc/sysctl.d/99-rp-filter.conf
          mode: 420
          overwrite: true
          contents:
            source: data:text/plain;charset=utf-8;base64,$(base64 -w0 templates/99-rp-filter.conf)
        - path: /usr/local/bin/enforce-rabbitmq-dnat.sh
          mode: 493
          overwrite: true
          contents:
            source: data:text/plain;charset=utf-8;base64,$(base64 -w0 templates/enforce-rabbitmq-dnat.sh)
    systemd:
      units:
        - name: rabbitmq-dnat-fix.service
          enabled: true
          contents: |
            [Unit]
            Description=Enforce RabbitMQ VIP DNAT override to routable OVN IP
            After=network-online.target ovs-vswitchd.service
            Wants=network-online.target

            [Service]
            Type=oneshot
            ExecStart=/usr/local/bin/enforce-rabbitmq-dnat.sh
            RemainAfterExit=yes

            [Install]
            WantedBy=multi-user.target
EOF

