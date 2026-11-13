# Creating Credentials

Prerequisite: Generating the Composite Cluster Pull Secret
OpenShift Container Platform (OCP) and Red Hat OpenStack Services on OpenShift (RHOSO) pull container images from different registries with different authorization models. A standard OCP installation pull secret is insufficient for RHOSO Day-2 operations.

Why Two Separate Credentials Are Required
The Base OCP Installation Secret (console.redhat.com):

Source URL: [https://console.redhat.com/openshift/install/pull-secret](https://console.redhat.com/openshift/install/pull-secret)

Scope: Provides temporary OAuth and SSO tokens for cloud.openshift.com (cluster telemetry/registration) and quay.io (core OpenShift platform release images).

Limitation: The registry.redhat.io entry generated here is bound to personal web-SSO credentials. It lacks product entitlement access for licensed layered products like RHOSO.

The Red Hat Registry Service Account Secret (access.redhat.com):

Source URL: [https://access.redhat.com/terms-based-registry/](https://access.redhat.com/terms-based-registry/)

Scope: A dedicated robot/service account bound to your organization's subscription entitlements.

Format: Decodes to a numeric account string with an accepted terms flag (<AccountID>|<ServiceAccountName>:<Token>).

Requirement: Grants authorization to pull product index images such as registry.redhat.io/rhosp-rhel9/openstack-operator-index:18.0.

Step-by-Step: Assembling the Composite Secret
Follow this procedure on your provisioning workstation before generating installation assets:

Download the Base OCP Secret:

Log into console.redhat.com/openshift/install/pull-secret.

Click Download pull secret and save it as ocp-install-pull-secret.json.

Download the Registry Service Account:

Log into access.redhat.com/terms-based-registry/.

Select or create a service account that has RHOSO/RHOSP access enabled.

Creating a new account:

1. At access.redhat.com/terms-based-registry/, click the blue New Service Account button (above the table on the right).

2. Enter a name (e.g., rhoso-agent-installer) and a description.

3. Check the terms acceptance checkbox.

4. Click Create.

5. Upon creation, a modal dialog appears showing:

  * Username: e.g. 12345678|rhoso-agent-installer

  * Password / Token: the generated secret string

  * A direct download link or copyable snippet for the Docker Configuration file (.dockerconfigjson).

6. Download the file or copy the raw JSON to your provisioning host as rh-registry-sa.json.

If the account already exists, you can click on the 3 dots, then Regenerate Token.
As it implies, this will break any existing use of the token.

Verify the Service Account Format:
Ensure the token contains the numeric Account ID prefix required by registry.redhat.io:

```
jq -r '.auths["registry.redhat.io"].auth' rh-registry-sa.json | base64 -d | cut -c 1-30
```

Verification: The string must start with digits before the vertical bar (e.g., 12345678|service-account-name:...). If it starts with | or a raw username, the token is not a valid Registry Service Account.

Merge the Two Files into a Single Composite Secret:
Use jq to overlay the authenticated registry.redhat.io credentials on top of the base OCP secret:

```
jq -s '.[0] * .[1]' ocp-install-pull-secret.json rh-registry-sa.json > composite-pull-secret.json
```

Verify the Combined Result:
Confirm that the merged secret contains keys for both core infrastructure and the service account:

```
jq '.auths | keys' composite-pull-secret.json
Verification: Output must display ["cloud.openshift.com", "quay.io", "registry.redhat.io"].
```

Embed into install-config.yaml:
Compact the composite secret to a single line and write it into the pullSecret field of install-config.yaml:

```
COMPOSITE_SECRET=$(cat composite-pull-secret.json | tr -d '[:space:]')
sed -i "s|pullSecret:.*|pullSecret: '${COMPOSITE_SECRET}'|" install-config.yaml
```

###########

# Hybrid Cloud Console Version

Here is how to generate an enterprise-compliant, customer-ready Registry Service Account via the Hybrid Cloud Console:

Step 1: Navigate to IAM Service Accounts in Console
Open console.redhat.com.

Click the gear icon (Settings) in the top right navigation bar.

Select Identity & Access Management (or go directly to console.redhat.com/iam/service-accounts).

Select Service Accounts from the left-hand navigation menu.

Step 2: Create the Service Account
Click Create service account.

Set a clean, descriptive name (e.g., rhoso-operator-pull).

Set a short description (e.g., Cluster pull secret for RHOSO and layered operator catalogs).

Click Create.

A modal will appear displaying:

Client ID (formatted as a service account UUID or alphanumeric ID)

Client Secret (the token)

Copy both the Client ID and the Client Secret immediately.

Step 3: Grant Registry Entitlement Role
On Hybrid Cloud Console, service accounts start with no default access. You must give it read access to the registry:

Click on the newly created Service Account name in the list.

Under the Permissions or Roles tab, click Add role (or Assign permissions).

Select the role: Registry Access or Registry Read (or ensure it is granted standard image pull permissions for the organization's entitled repositories).

Save the role assignment.

Step 4: Construct the Customer-Clean Secret JSON
Once you have the Client ID and Client Secret, format them into a valid .dockerconfigjson structure:

```
CLIENT_ID="<client_id_from_console>"
CLIENT_SECRET="<client_secret_from_console>"

# Base64 encode the Client ID and Secret pair without line breaks
AUTH_STRING=$(printf "%s:%s" "${CLIENT_ID}" "${CLIENT_SECRET}" | base64 -w 0)

# Write out the clean registry configuration file
cat <<EOF > rh-registry-sa.json
{
  "auths": {
    "registry.redhat.io": {
      "auth": "${AUTH_STRING}"
    }
  }
}
EOF
```

Verification: Inspect the generated file to ensure there is no leading |:

```
jq -r '.auths["registry.redhat.io"].auth' rh-registry-sa.json | base64 -d | cut -c 1-40
```
Expected output: starts directly with your CLIENT_ID followed by : (no pipe delimiter).

Step 5: Test the Official Repository Pull
Validate that the new console-minted service account can authenticate directly against registry.redhat.io:

```
podman pull --authfile rh-registry-sa.json registry.redhat.io/rhosp-rhel9/openstack-operator-index:18.0
```
Verification: The pull should download the manifest layers cleanly without throwing 401 Unauthorized.

Step 6: Update Cluster Pull Secret and Refresh the Pod
Once confirmed locally, merge the new secret into OpenShift and cycle the catalog pod:

Merge the Console Service Account into the active cluster secret:

```
oc get secret pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d > /tmp/base-secret.json
jq -s '.[0] * .[1]' /tmp/base-secret.json rh-registry-sa.json > /tmp/composite-pull-secret.json
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=/tmp/composite-pull-secret.json
```

Update the dedicated secret in openshift-marketplace:

```
oc create secret docker-registry rhoso-pull-secret \
  --from-file=.dockerconfigjson=/tmp/composite-pull-secret.json \
  -n openshift-marketplace --dry-run=client -o yaml | oc apply -f -
```

Bounce the failed pod:

```
oc delete pod -n openshift-marketplace -l olm.catalogSource=openstack-operator-index
```

Verification:

```
oc get pods -n openshift-marketplace -l olm.catalogSource=openstack-operator-index -w
```

The pod will transition to 1/1 Running.


###############################################

# Service accounts

* https://access.redhat.com/terms-based-registry/
* https://console.redhat.com/iam/service-accounts/

# Openshift Pull Secret

https://console.redhat.com/openshift/install/pull-secret

# Subscriptions

https://access.redhat.com/management/subscriptions


