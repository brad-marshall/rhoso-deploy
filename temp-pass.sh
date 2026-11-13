#!/bin/bash

cat <<EOF > temp-pass.yaml
  Cell1DbRootPassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 | tr -d '\n' | base64 | tr -d '\n')"
  PlacementDatabasePassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 | tr -d '\n' | base64 | tr -d '\n')"
  GlanceDatabasePassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 | tr -d '\n' | base64 | tr -d '\n')"
  CinderDatabasePassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 | tr -d '\n' | base64 | tr -d '\n')"
  NeutronDatabasePassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 | tr -d '\n' | base64 | tr -d '\n')"
  NovaAPIDatabasePassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 | tr -d '\n' | base64 | tr -d '\n')"
  NovaCell0DatabasePassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 | tr -d '\n' | base64 | tr -d '\n')"
  NovaCell1DatabasePassword: "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 | tr -d '\n' | base64 | tr -d '\n')"
EOF

