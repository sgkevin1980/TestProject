# Create Azure Front Door
aro_rgName='aro-'$(az aro show -n $AROCLUSTER -g $SPOKERGNAME --query "clusterProfile.domain" -o tsv)
internal_LbName=$(az network lb list --resource-group $aro_rgName --query "[? contains(name, 'internal')].name" -o tsv)
worker_subnetId=$(az network vnet subnet show -n $WORKERAROSUBNET_NAME -g $SPOKERGNAME --vnet-name $SPOKEVNET_NAME --query "id" -o tsv)
lbconfig_id=$(az network lb frontend-ip list -g $aro_rgName --lb-name $internal_LbName --query "[? contains(subnet.id, 'worker')].id" -o tsv)
lbconfig_ip=$(az network lb frontend-ip list -g $aro_rgName --lb-name $internal_LbName --query "[? contains(subnet.id, 'worker')].privateIPAddress" -o tsv)
azlaworkspaceId=$(az monitor log-analytics workspace show -g $HUBRGNAME -n $LAWORKSPACE_NAME --query 'id' -o tsv)

echo $lbconfig_ip

# Make sure worker subnet has private link service network policies disabled
az network private-link-service create \
  --name $AFD_PLS_NAME \
  --resource-group $SPOKERGNAME \
  --private-ip-address-version IPv4 \
  --private-ip-allocation-method Dynamic \
  --vnet-name $SPOKEVNET_NAME \
  --subnet $WORKERAROSUBNET_NAME \
  --lb-frontend-ip-configs $lbconfig_id

privatelink_id=$(az network private-link-service show -n $AFD_PLS_NAME -g $SPOKERGNAME --query 'id' -o tsv)

az afd profile create \
  --resource-group $SPOKERGNAME \
  --profile-name $AFD_NAME \
  --sku Premium_AzureFrontDoor

afd_id=$(az afd profile show -g $SPOKERGNAME --profile-name $AFD_NAME --query 'id' -o tsv)

az monitor diagnostic-settings create \
  --name 'AfdtoLogAnalytics' \
  --resource $afd_id \
  --workspace $azlaworkspaceId \
  --logs '[{"category":"FrontDoorAccessLog","Enabled":true}, {"category":"FrontDoorHealthProbeLog","Enabled":true}, {"category":"FrontDoorWebApplicationFirewallLog","Enabled":true}]' \
  --metrics '[{"category": "AllMetrics","enabled": true}]'

az afd endpoint create \
  --resource-group $SPOKERGNAME \
  --enabled-state Enabled \
  --endpoint-name 'aro-ilb'$uniqueId \
  --profile-name $AFD_NAME

az afd origin-group create \
  --origin-group-name 'afdorigin' \
  --probe-path '/' \
  --probe-protocol Http \
  --probe-request-type GET \
  --probe-interval-in-seconds 100 \
  --profile-name $AFD_NAME \
  --resource-group $SPOKERGNAME \
  --probe-interval-in-seconds 120 \
  --sample-size 4 \
  --successful-samples-required 3 \
  --additional-latency-in-milliseconds 50

az afd origin create \
  --enable-private-link true \
  --private-link-resource $privatelink_id \
  --private-link-location $LOCATION \
  --private-link-request-message 'Private link service from AFD' \
  --weight 1000 \
  --priority 1 \
  --http-port 80 \
  --https-port 443 \
  --origin-group-name 'afdorigin' \
  --enabled-state Enabled \
  --host-name $lbconfig_ip \
  --origin-name 'afdorigin' \
  --profile-name $AFD_NAME \
  --resource-group $SPOKERGNAME

az afd origin show --origin-group-name 'afdorigin' --origin-name 'afdorigin' --profile-name $AFD_NAME --resource-group $SPOKERGNAME

privatelink_pe_id=$(az network private-link-service show -n $AFD_PLS_NAME -g $SPOKERGNAME --query 'privateEndpointConnections[0].privateEndpoint.id' -o tsv)

# Currently there is a bug in Az CLI that is unable to approve a Private Endpoint in a Private Link Service
# Bug Link: https://github.com/Azure/azure-cli/issues/19908
# Following command expected to fail with 'child_name_1'
# Check out: https://docs.microsoft.com/en-us/azure/frontdoor/standard-premium/concept-private-link
# For now go through Portal, find Private Link Service (under spoke rg) in this case aro-pls, then go to 'Private endpoint connections', select the connection and Approve
# Connection status should change from Pending to Approved
az network private-endpoint-connection approve \
  --description 'Approved' \
  --id $privatelink_pe_id

################################################################################
### Working in proguress
################################################################################
# Command to list/show private endpoint connection that will be used as a reference to approve it
az network private-link-service show -g $SPOKERGNAME -n $AFD_PLS_NAME

az network private-link-service list
az network private-link-service show -g spoke-aro-rg -n aro-pls --query 'privateEndpointConnections[0].privateEndpoint.id' -o tsv

#az network private-endpoint-connection approve \
#  --description 'Approved' \
#  --id "/subscriptions/$SUBSCRIPTIONID/resourceGroups/spoke-aro-rg/providers/Microsoft.Network/privateLinkServices/aro-pls/privateEndpointConnections/xxxxx"

#Get-AzPrivateEndpointConnection -Name 8d50911c-b405-4c81-xxxx -ResourceGroupName spoke-aro-rg -ServiceName aro-pls
#Approve-AzPrivateEndpointConnection -Name 8d50911c-b405-4c81-xxxx -ResourceGroupName spoke-aro-rg -ServiceName aro-pls

################################################################################

az afd custom-domain create \
  --certificate-type ManagedCertificate \
  --custom-domain-name $AFD_APP_CUSTOM_DOMAIN_NAME \
  --host-name $ARO_APP_FQDN \
  --minimum-tls-version TLS12 \
  --profile-name $AFD_NAME \
  --resource-group $SPOKERGNAME

az afd custom-domain show \
  --resource-group $SPOKERGNAME \
  --profile-name $AFD_NAME \
  --custom-domain-name $AFD_APP_CUSTOM_DOMAIN_NAME \
  --query "validationProperties"

# Now you have to validate your domain. You must create a TXT Record using this name for example: _dnsauth.ratingsapp.umar.cloud using validationToken as value.
# To check if the DNS was created in the expected run NSLOOKUP: nslookup -q=TXT _dnsauth.$ARO_APP_FQDN
# This validation process will take some time

az afd route create \
  --endpoint-name 'aro-ilb'$uniqueId \
  --forwarding-protocol HttpOnly \
  --https-redirect Disabled \
  --origin-group 'afdorigin' \
  --profile-name $AFD_NAME \
  --resource-group $SPOKERGNAME \
  --route-name 'aro-route' \
  --supported-protocols Http Https \
  --patterns-to-match '/*' \
  --custom-domains $AFD_APP_CUSTOM_DOMAIN_NAME

# Create a CName record type in your DNS pointing ratingsapp to Azure Front Door endpoint
# For example create ratingsapp.umar.cloud CNAME record pointing to aro-ilb6779.z01.azurefd.net