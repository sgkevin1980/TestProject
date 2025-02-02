# Create SPOKE virtual network
az network vnet create \
   --resource-group $SPOKERGNAME \
   --name $SPOKEVNET_NAME \
   --address-prefixes $SPOKEVNET_PREFIX

# master-aro-subnet
az network vnet subnet create \
  --resource-group $SPOKERGNAME \
  --vnet-name $SPOKEVNET_NAME \
  --name $MASTERAROSUBNET_NAME \
  --address-prefixes $MASTERAROSUBNET_PREFIX \
  --disable-private-link-service-network-policies true

# worker-aro-subnet
az network vnet subnet create \
  --resource-group $SPOKERGNAME \
  --vnet-name $SPOKEVNET_NAME \
  --name $WORKERAROSUBNET_NAME \
  --address-prefixes $WORKERAROSUBNET_PREFIX \
  --disable-private-link-service-network-policies true

# AppGW-subnet
az network vnet subnet create \
  --resource-group $SPOKERGNAME \
  --vnet-name $SPOKEVNET_NAME \
  --name $APPGWSUBNET_NAME \
  --address-prefixes $APPGWSUBNET_PREFIX

# PrivateEndpoint-subnet
az network vnet subnet create \
  --resource-group $SPOKERGNAME \
  --vnet-name $SPOKEVNET_NAME \
  --name $PRIVATEENDPOINTSUBNET_NAME \
  --address-prefixes $PRIVATEENDPOINTSUBNET_PREFIX \
  --disable-private-endpoint-network-policies true

# PrivateRunner-subnet
az network vnet subnet create \
  --resource-group $SPOKERGNAME \
  --vnet-name $SPOKEVNET_NAME \
  --name $PRIVATERUNNERSUBNET_NAME \
  --address-prefixes $PRIVATERUNNERSUBNET_PREFIX