# Create Peering
SPOKE_VNET_ID=$(az network vnet show --name $SPOKEVNET_NAME --resource-group $SPOKERGNAME --query id -o tsv)
HUB_VNET_ID=$(az network vnet show --name $HUBVNET_NAME --resource-group $HUBRGNAME --query id -o tsv)

az network vnet peering create \
  --resource-group $HUBRGNAME \
  --name $HUBVNET_NAME'To'$SPOKEVNET_NAME \
  --vnet-name $HUBVNET_NAME \
  --remote-vnet $SPOKE_VNET_ID \
  --allow-vnet-access \
  --allow-forwarded-traffic

az network vnet peering create \
  --resource-group $SPOKERGNAME \
  --name $SPOKEVNET_NAME'To'$HUBVNET_NAME \
  --vnet-name $SPOKEVNET_NAME \
  --remote-vnet $HUB_VNET_ID \
  --allow-vnet-access \
  --allow-forwarded-traffic