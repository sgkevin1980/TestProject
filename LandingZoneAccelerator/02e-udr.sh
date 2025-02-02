# Create UDRs
# UDR for ARO
ARO_UDR_NAME='aro-udr'
azfw_private_ip=$(az network firewall show -n $AZFW_NAME -g $HUBRGNAME -o tsv --query 'ipConfigurations[0].privateIpAddress')
az network route-table create \
  --name $ARO_UDR_NAME \
  --resource-group $HUBRGNAME \
  --location $LOCATION
az network route-table route create \
  --name defaultRoute \
  --route-table-name $ARO_UDR_NAME \
  --resource-group $HUBRGNAME \
  --next-hop-type VirtualAppliance \
  --address-prefix "0.0.0.0/0" \
  --next-hop-ip-address $azfw_private_ip
aro_rt_id=$(az network route-table show -n $ARO_UDR_NAME -g $HUBRGNAME -o tsv --query id)
az network vnet subnet update \
  --resource-group $SPOKERGNAME \
  --vnet-name $SPOKEVNET_NAME \
  --name $MASTERAROSUBNET_NAME \
  --route-table $aro_rt_id
az network vnet subnet update \
  --resource-group $SPOKERGNAME \
  --vnet-name $SPOKEVNET_NAME \
  --name $WORKERAROSUBNET_NAME \
  --route-table $aro_rt_id

# TODO: UDR for VMs/Toolsbox and PrivateRunner