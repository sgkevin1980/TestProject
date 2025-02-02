HUB_VNET_ID=$(az network vnet show --name $HUBVNET_NAME --resource-group $HUBRGNAME --query id -o tsv)
# Azure CosmosDB with Private Link
az cosmosdb create \
  --name $COSMOSDB_NAME \
  --resource-group $SPOKERGNAME \
  --kind MongoDB \
  --server-version '4.0' \
  --enable-public-network false \
  --default-consistency-level Eventual

COSMOSDB_ID=$(az cosmosdb show -n $COSMOSDB_NAME -g $SPOKERGNAME --query 'id' -o tsv)

# Private Endpoint connection
az network private-endpoint create \
  --name 'cosmosdbPvtEndpoint' \
  --resource-group $SPOKERGNAME \
  --vnet-name $SPOKEVNET_NAME \
  --subnet $PRIVATEENDPOINTSUBNET_NAME \
  --private-connection-resource-id $COSMOSDB_ID \
  --group-id 'MongoDB' \
  --connection-name 'cosmosdbConnection'

az network private-dns zone create \
  --resource-group $SPOKERGNAME \
  --name 'privatelink.mongo.cosmos.azure.com'

az network private-dns link vnet create \
  --resource-group $SPOKERGNAME \
  --zone-name 'privatelink.mongo.cosmos.azure.com' \
  --name 'CosmosDbDNSLink' \
  --virtual-network $HUB_VNET_ID \
  --registration-enabled false

az network private-endpoint dns-zone-group create \
  --resource-group $SPOKERGNAME \
  --name 'CosmosDb-ZoneGroup' \
  --endpoint-name 'cosmosdbPvtEndpoint' \
  --private-dns-zone 'privatelink.mongo.cosmos.azure.com' \
  --zone-name 'CosmosDB'

# Creating ratingsdb
databaseName='ratingsdb'

# Create a MongoDB API database
az cosmosdb mongodb database create \
  --account-name $COSMOSDB_NAME \
  --resource-group $SPOKERGNAME \
  --name $databaseName