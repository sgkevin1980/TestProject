# HUB VNet creation
az network vnet create \
   --resource-group $HUBRGNAME \
   --name $HUBVNET_NAME \
   --address-prefixes $HUBVNET_PREFIX

# AzureFirewallSubnet
az network vnet subnet create \
  --resource-group $HUBRGNAME \
  --vnet-name $HUBVNET_NAME \
  --name AzureFirewallSubnet \
  --address-prefixes $AZFWSUBNET_PREFIX

# AzureBastionSubnet
az network vnet subnet create \
  --resource-group $HUBRGNAME \
  --vnet-name $HUBVNET_NAME \
  --name AzureBastionSubnet \
  --address-prefixes $AZUREBASTIONSUBNET_PREFIX

# Tools Box VM-Subnet
az network vnet subnet create \
  --resource-group $HUBRGNAME \
  --vnet-name $HUBVNET_NAME \
  --name $VMSUBNET_NAME \
  --address-prefixes $VMSUBNET_PREFIX