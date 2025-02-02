# Azure KeyVault with Private Link
az keyvault create -n $KV_NAME -g $SPOKERGNAME -l $LOCATION
az keyvault update -n $KV_NAME -g $SPOKERGNAME --default-action deny # Turn on Key Vault Firewall

KEYVAULT_ID=$(az keyvault show -n $KV_NAME -g $SPOKERGNAME --query 'id' -o tsv)

HUB_VNET_ID=$(az network vnet show --name $HUBVNET_NAME --resource-group $HUBRGNAME --query id -o tsv)

# Private Endpoint connection
az network private-endpoint create \
  --name 'kvPvtEndpoint' \
  --resource-group $SPOKERGNAME \
  --vnet-name $SPOKEVNET_NAME \
  --subnet $PRIVATEENDPOINTSUBNET_NAME \
  --private-connection-resource-id $KEYVAULT_ID \
  --group-id 'vault' \
  --connection-name 'kvConnection'

az network private-dns zone create \
  --resource-group $SPOKERGNAME \
  --name 'privatelink.vaultcore.azure.net'

az network private-dns link vnet create \
  --resource-group $SPOKERGNAME \
  --name 'KeyVaultDNSLink' \
  --zone-name 'privatelink.vaultcore.azure.net' \
  --virtual-network $HUB_VNET_ID \
  --registration-enabled false

az network private-endpoint dns-zone-group create \
  --name 'KeyVault-ZoneGroup' \
  --resource-group $SPOKERGNAME \
  --endpoint-name 'kvPvtEndpoint' \
  --private-dns-zone 'privatelink.vaultcore.azure.net' \
  --zone-name 'KEYVAULT'