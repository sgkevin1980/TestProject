# ACR in Spoke VNET with Private Endpoint
az acr create \
  --resource-group $SPOKERGNAME \
  --name $ACR_NAME \
  --sku Premium \
  --public-network-enabled false \
  --admin-enabled true

REGISTRY_ID=$(az acr show -n $ACR_NAME --query 'id' -o tsv)

# Private Endpoint connection
az network private-endpoint create \
  --name 'acrPvtEndpoint' \
  --resource-group $SPOKERGNAME \
  --vnet-name $SPOKEVNET_NAME \
  --subnet $PRIVATEENDPOINTSUBNET_NAME \
  --private-connection-resource-id $REGISTRY_ID \
  --group-id 'registry' \
  --connection-name 'acrConnection'

az network private-dns zone create \
  --resource-group $SPOKERGNAME \
  --name 'privatelink.azurecr.io'

az network private-dns link vnet create \
  --resource-group $SPOKERGNAME \
  --name 'AcrDNSLink' \
  --zone-name 'privatelink.azurecr.io' \
  --virtual-network $HUB_VNET_ID \
  --registration-enabled false

az network private-endpoint dns-zone-group create \
  --name 'ACR-ZoneGroup' \
  --resource-group $SPOKERGNAME \
  --endpoint-name 'acrPvtEndpoint' \
  --private-dns-zone 'privatelink.azurecr.io' \
  --zone-name 'ACR'