# Below steps must be executed from JumpBox VM

# AAD Integration for RBAC: https://docs.microsoft.com/en-us/azure/openshift/configure-azure-ad-cli
domain=$(az aro show -g $SPOKERGNAME -n $AROCLUSTER --query clusterProfile.domain -o tsv)
location=$(az aro show -g $SPOKERGNAME -n $AROCLUSTER --query location -o tsv)
apiServer=$(az aro show -g $SPOKERGNAME -n $AROCLUSTER --query apiserverProfile.url -o tsv)
webConsole=$(az aro show -g $SPOKERGNAME -n $AROCLUSTER --query consoleProfile.url -o tsv)

oauthCallbackURL=https://oauth-openshift.apps.$domain.$location.aroapp.io/oauth2callback/AAD

# Create an Azure Active Directory application and retrieve the created application identifier.
client_id=$(az ad app create \
  --query appId -o tsv \
  --display-name $ARO_AAD_APP_NAME \
  --web-redirect-uris $oauthCallbackURL)

client_secret=$(az ad app credential reset --id $client_id \
  --append --display-name aro-secret \
  --years 1 \
  --query password --output tsv)  

# Retrieve the tenant ID of the subscription that owns the application.
tenant_id=$(az account show --query tenantId -o tsv)

# Create a manifest.json file to configure the Azure Active Directory application.
cat > manifest.json<< EOF
{
  "idToken": [
    {
      "name": "upn",
      "source": null,
      "essential": false,
      "additionalProperties": []
    },
    {
    "name": "email",
      "source": null,
      "essential": false,
      "additionalProperties": []
    }
  ]
}
EOF

# Update the Azure Active Directory application's optionalClaims with a manifest
az ad app update \
  --optional-claims @manifest.json \
  --id $client_id

# Add permission for the Azure Active Directory Graph.User.Read scope to enable sign in and read user profile.
az ad app permission add \
 --id $client_id \
 --api 00000002-0000-0000-c000-000000000000 \
 --api-permissions 311a71cc-e848-46a1-bdf8-97ff7156d8e6=User.Read

az ad app permission grant \
 --api 00000002-0000-0000-c000-000000000000 \
 --scope User.Read \
 --id $client_id

# The previous command may show the following warning message:
# Invoking "az ad app permission grant --id xxxxxxxxxxxxxx --api 00000002-0000-0000-c000-000000000000" is needed to make the change effective
# It can be safely ignored

# Retrieve the kubeadmin credentials. Run the following command to find the password for the kubeadmin user.
kubeadmin_password=$(az aro list-credentials --name $AROCLUSTER --resource-group $SPOKERGNAME --query kubeadminPassword --output tsv)

# Log in to the OpenShift cluster's API server using the following command.
oc login $apiServer -u kubeadmin -p $kubeadmin_password

# Create an OpenShift secret to store the Azure Active Directory application secret.
oc create secret generic openid-client-secret-azuread --namespace openshift-config --from-literal=clientSecret=$client_secret

cat > oidc.yaml<< EOF
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: AAD
    mappingMethod: claim
    type: OpenID
    openID:
      clientID: $client_id
      clientSecret:
        name: openid-client-secret-azuread
      extraScopes:
      - email
      - profile
      extraAuthorizeParameters:
        include_granted_scopes: "true"
      claims:
        preferredUsername:
        - email
        - upn
        name:
        - name
        email:
        - email
      issuer: https://login.microsoftonline.com/$tenant_id
EOF

# Apply the configuration to the cluster.
oc apply -f oidc.yaml

# Optional step to test sign in using AAD: Add cluster-admin rolebinding to one of the AAD user
# Example: oc create clusterrolebinding umarm-cluster-admin-role --clusterrole=cluster-admin --user=umarm@microsoft.com
oc create clusterrolebinding kevin-cluster-admin-role --clusterrole=cluster-admin --user=keye@redhat.com

# Go to OpenShift Web Console, now you will see Log in option with AAD
# Using AAD option, sign in with the user who we provided cluster-admin role in the previous step