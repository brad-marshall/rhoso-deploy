#!/bin/bash

cat <<EOF > openstack_service_secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: osp-secret
  namespace: openstack
type: Opaque
stringData:
  # Database & Admin
  DbRootPassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"
  DatabasePassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"
  AdminPassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"

  # Service Passwords
  KeystoneDatabasePassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"
  KeystonePassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"
  CinderPassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"
  GlancePassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"
  NeutronPassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"
  NovaPassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"
  PlacementPassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"
  OctaviaPassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"
  SwiftPassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"

  # Agent & Web Secrets
  MetadataSecret: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"
  HorizonSecret: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"

  Cell1DbRootPassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"
  PlacementDatabasePassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"
  GlanceDatabasePassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"
  CinderDatabasePassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"
  NeutronDatabasePassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"
  NovaAPIDatabasePassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"
  NovaCell0DatabasePassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"
  NovaCell1DatabasePassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"

EOF
