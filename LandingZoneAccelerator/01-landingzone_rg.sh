# Important: Tested these scripts only through WSL Terminal. Git Bash doesn't work.

#!/usr/bin/env bash
SUBSCRIPTIONID='ab3c0724-d98d-4a74-917a-29a3ebe0f01e'
HUBRGNAME='hub-aro-rg'
SPOKERGNAME='spoke-aro-rg'
ARCRGNAME='arc-aro-rg'
AZFW_NAME='azfw'
BASTION_NAME='bastion-hub'
LOCATION='eastus'
AROCLUSTER='arocluster'
PULLSECRETLOCATION=@/Users/kevinye/Documents/KevinYe/Openshift/Code/pull-secret.txt
uniqueId=$RANDOM
ACR_NAME='aroacr'$uniqueId
COSMOSDB_NAME='cosmos'$uniqueId
KV_NAME='keyvault'$uniqueId
LAWORKSPACE_NAME='arolw'
AFD_NAME='aroafd'
AFD_PLS_NAME='aro-pls'
AFD_APP_CUSTOM_DOMAIN_NAME='ratingsapp-contoso-com' # Ex: ratingsapp-mydomain-com
ARO_APP_FQDN='ratingsapp.contoso.com' # Ex: ratingsapp.mydomain.com
ARO_AAD_APP_NAME='aro-aad-auth-sp-'$uniqueId

# VNet Name and IP Addresses
HUBVNET_NAME='hub-vnet'
HUBVNET_PREFIX='10.0.0.0/16'
AZFWSUBNET_PREFIX='10.0.0.0/26'
AZUREBASTIONSUBNET_PREFIX='10.0.0.64/26'
VMSUBNET_PREFIX='10.0.1.0/24'
VMSUBNET_NAME=VM-Subnet

SPOKEVNET_NAME='aro-spoke-vnet'
MASTERAROSUBNET_NAME=master-aro-subnet
WORKERAROSUBNET_NAME=worker-aro-subnet
SPOKEVNET_PREFIX='10.1.0.0/16'
MASTERAROSUBNET_PREFIX='10.1.0.0/23'
WORKERAROSUBNET_PREFIX='10.1.2.0/23'
PRIVATERUNNERSUBNET_PREFIX='10.1.4.0/24'
PRIVATERUNNERSUBNET_NAME=PrivateRunner-subnet
APPGWSUBNET_PREFIX='10.1.5.0/27'
APPGWSUBNET_NAME=AppGW-subnet
PRIVATEENDPOINTSUBNET_PREFIX='10.1.6.0/25'
PRIVATEENDPOINTSUBNET_NAME='PrivateEndpoint-subnet'

# Create the resource group
az group create --name $HUBRGNAME --location $LOCATION
az group create --name $SPOKERGNAME --location $LOCATION

# ARO needs minimum of 40 cores, check to make sure your subscription Limit is 40 cores or more
az vm list-usage -l $LOCATION \
--query "[?contains(name.value, 'standardDSv3Family')]" \
-o table

# Register the necessary resource providers
az provider register -n Microsoft.RedHatOpenShift --wait
az provider register -n Microsoft.Compute --wait
az provider register -n Microsoft.Storage --wait
az provider register -n Microsoft.Authorization --wait

# Log Analytics Workspace
az monitor log-analytics workspace create \
  --resource-group $HUBRGNAME \
  -n $LAWORKSPACE_NAME
azlaworkspaceId=$(az monitor log-analytics workspace show -g $HUBRGNAME -n $LAWORKSPACE_NAME --query 'id' -o tsv)