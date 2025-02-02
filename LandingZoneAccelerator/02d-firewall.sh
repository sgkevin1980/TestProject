# Create Azure Firewall
# AZFW_NAME
az network public-ip create \
  --resource-group $HUBRGNAME \
  --name $AZFW_NAME'-pip' \
  --sku standard \
  --allocation-method static \
  --location $LOCATION

azfw_ip=$(az network public-ip show -g $HUBRGNAME -n $AZFW_NAME'-pip' --query ipAddress -o tsv)

az network firewall create \
  --name $AZFW_NAME \
  --resource-group $HUBRGNAME \
  --location $LOCATION \
  --enable-dns-proxy true

azfw_id=$(az network firewall show -n $AZFW_NAME -g $HUBRGNAME -o tsv --query id)

az network firewall ip-config create \
  --firewall-name $AZFW_NAME \
  --name azfw-ipconfig \
  --resource-group $HUBRGNAME \
  --public-ip-address $AZFW_NAME'-pip' \
  --vnet-name $HUBVNET_NAME

az network firewall update \
  --name $AZFW_NAME \
  --resource-group $HUBRGNAME

azfw_private_ip=$(az network firewall show -n $AZFW_NAME -g $HUBRGNAME -o tsv --query 'ipConfigurations[0].privateIpAddress')

# Create Firewall Rules
# Create Network Rules
az network firewall network-rule create \
  --firewall-name $AZFW_NAME -g $HUBRGNAME \
  --collection-name 'Aro-required-ports' \
  --protocols any \
  --destination-addresses '*' \
  --destination-ports 123 \
  --source-addresses $HUBVNET_PREFIX $SPOKEVNET_PREFIX \
  --name NTP \
  --priority 200 \
  --action Allow

# Create Application Rules
# Minimum Required FQDN / application rules
minimum_required_group_target_fqdns="arosvc.$LOCATION.data.azurecr.io *.quay.io registry.redhat.io mirror.openshift.com api.openshift.com arosvc.azurecr.io management.azure.com login.microsoftonline.com gcs.prod.monitoring.core.windows.net *.blob.core.windows.net *.servicebus.windows.net *.table.core.windows.net"
az network firewall application-rule create \
  --firewall-name $AZFW_NAME \
  --resource-group $HUBRGNAME \
  --collection-name 'Minimum-Required-FQDN' \
  --protocols Http=80 Https=443 \
  --target-fqdns $minimum_required_group_target_fqdns \
  --source-addresses $HUBVNET_PREFIX $SPOKEVNET_PREFIX \
  --name minimum_required_group_target_fqdns \
  --priority 200 \
  --action Allow

# FIRST GROUP: INSTALLING AND DOWNLOADING PACKAGES AND TOOLS
first_group_target_fqdns="quay.io registry.redhat.io sso.redhat.com openshift.org"
az network firewall application-rule create \
  --firewall-name $AZFW_NAME \
  --resource-group $HUBRGNAME \
  --collection-name 'Aro-required-urls' \
  --protocols Http=80 Https=443 \
  --target-fqdns $first_group_target_fqdns \
  --source-addresses $HUBVNET_PREFIX $SPOKEVNET_PREFIX \
  --name first_group_target_fqdns \
  --priority 201 \
  --action Allow

# SECOND GROUP: TELEMETRY
second_group_target_fqdns="cert-api.access.redhat.com api.access.redhat.com infogw.api.openshift.com cloud.redhat.com"
az network firewall application-rule create \
  --firewall-name $AZFW_NAME \
  --resource-group $HUBRGNAME \
  --collection-name 'Telemetry-URLs' \
  --protocols Http=80 Https=443 \
  --target-fqdns $second_group_target_fqdns \
  --source-addresses $HUBVNET_PREFIX $SPOKEVNET_PREFIX \
  --name second_group_target_fqdns \
  --priority 202 \
  --action Allow

# THIRD GROUP: CLOUD APIs
third_group_target_fqdns="management.azure.com"
az network firewall application-rule create \
  --firewall-name $AZFW_NAME \
  --resource-group $HUBRGNAME \
  --collection-name 'Cloud-APIs' \
  --protocols Http=80 Https=443 \
  --target-fqdns $third_group_target_fqdns \
  --source-addresses $HUBVNET_PREFIX $SPOKEVNET_PREFIX \
  --name third_group_target_fqdns \
  --priority 203 \
  --action Allow

# FOURTH GROUP: OTHER OPENSHIFT REQUIREMENTS
# Note: *.apps.<cluster_name>.<base_domain> (OR EQUIVALENT ARO URL): When allowlisting domains, this is use in your corporate network to reach applications deployed in OpenShift, or to access the OpenShift console.
fourth_group_target_fqdns="mirror.openshift.com storage.googleapis.com api.openshift.com registry.access.redhat.com"
az network firewall application-rule create \
  --firewall-name $AZFW_NAME \
  --resource-group $HUBRGNAME \
  --collection-name 'OpenShift-URLs' \
  --protocols Http=80 Https=443 \
  --target-fqdns $fourth_group_target_fqdns \
  --source-addresses $HUBVNET_PREFIX $SPOKEVNET_PREFIX \
  --name fourth_group_target_fqdns \
  --priority 204 \
  --action Allow

# FIFTH GROUP: MICROSOFT & RED HAT ARO MONITORING SERVICE
fifth_group_target_fqdns="login.microsoftonline.com gcs.prod.monitoring.core.windows.net *.blob.core.windows.net *.servicebus.windows.net *.table.core.windows.net"
az network firewall application-rule create \
  --firewall-name $AZFW_NAME \
  --resource-group $HUBRGNAME \
  --collection-name 'Monitoring-URLs' \
  --protocols Http=80 Https=443 \
  --target-fqdns $fifth_group_target_fqdns \
  --source-addresses $HUBVNET_PREFIX $SPOKEVNET_PREFIX \
  --name fifth_group_target_fqdns \
  --priority 205 \
  --action Allow

# SIXTH GROUP: ONBOARDING ARO ON TO ARC
sixth_group_target_fqdns="$LOCATION.login.microsoft.com management.azure.com $LOCATION.dp.kubernetesconfiguration.azure.com login.microsoftonline.com login.windows.net mcr.microsoft.com *.data.mcr.microsoft.com gbl.his.arc.azure.com *.his.arc.azure.com *.servicebus.windows.net guestnotificationservice.azure.com *.guestnotificationservice.azure.com sts.windows.net k8connecthelm.azureedge.net"
az network firewall application-rule create \
  --firewall-name $AZFW_NAME \
  --resource-group $HUBRGNAME \
  --collection-name 'Arc-URLs' \
  --protocols Http=80 Https=443 \
  --target-fqdns $sixth_group_target_fqdns \
  --source-addresses $HUBVNET_PREFIX $SPOKEVNET_PREFIX \
  --name sixth_group_target_fqdns \
  --priority 206 \
  --action Allow

# SEVENTH GROUP: Azure Monitor Container Insights extension for Arc
seventh_group_target_fqdns="*.ods.opinsights.azure.com *.oms.opinsights.azure.com dc.services.visualstudio.com *.monitoring.azure.com	login.microsoftonline.com"
az network firewall application-rule create \
  --firewall-name $AZFW_NAME \
  --resource-group $HUBRGNAME \
  --collection-name 'Arc-ContainerInsights-URLs' \
  --protocols Http=80 Https=443 \
  --target-fqdns $seventh_group_target_fqdns \
  --source-addresses $HUBVNET_PREFIX $SPOKEVNET_PREFIX \
  --name seventh_group_target_fqdns \
  --priority 207 \
  --action Allow

# EIGHTH GROUP: Docker HUB, GCR Optional for testing porpuse
eighth_group_target_fqdns="registry.hub.docker.com *.docker.io production.cloudflare.docker.com auth.docker.io *.gcr.io"
az network firewall application-rule create \
  --firewall-name $AZFW_NAME \
  --resource-group $HUBRGNAME \
  --collection-name 'Docker-HUB-URLs' \
  --protocols Http=80 Https=443 \
  --target-fqdns $eighth_group_target_fqdns \
  --source-addresses $HUBVNET_PREFIX $SPOKEVNET_PREFIX \
  --name eighth_group_target_fqdns \
  --priority 208 \
  --action Allow

# NINETH GROUP: Miscellaneous - Optional for testing porpuse
nineth_group_target_fqdns="quayio-production-s3.s3.amazonaws.com"
az network firewall application-rule create \
  --firewall-name $AZFW_NAME \
  --resource-group $HUBRGNAME \
  --collection-name 'Miscellaneous-URLs' \
  --protocols Http=80 Https=443 \
  --target-fqdns $nineth_group_target_fqdns \
  --source-addresses $HUBVNET_PREFIX $SPOKEVNET_PREFIX \
  --name nineth_group_target_fqdns \
  --priority 209 \
  --action Allow

# Optional additional Azure FQDNs
# target_useful_fqdns="ifconfig.co api.snapcraft.io jsonip.com kubernaut.io motd.ubuntu.com"
# target_azure_fqdns="*.azmk8s.io aksrepos.azurecr.io *.blob.core.windows.net mcr.microsoft.com *.cdn.mscr.io management.azure.com login.microsoftonline.com packages.azure.com acs-mirror.azureedge.net *.opinsights.azure.com *.monitoring.azure.com dc.services.visualstudio.com *.ods.opinsights.azure.com *.oms.opinsights.azure.com cloudflare.docker.com data.policy.core.windows.net store.policy.core.windows.net"
# target_registries_fqdns="$LOCATION.data.mcr.microsoft.com $acr_name.azurecr.io *.gcr.io gcr.io storage.googleapis.com *.docker.io quay.io *.quay.io *.cloudfront.net production.cloudflare.docker.com *.hcp.$location.cx.aks.containerservice.azure.us"
# target_fqdns="grafana.net grafana.com stats.grafana.org github.com raw.githubusercontent.com security.ubuntu.com security.ubuntu.com packages.microsoft.com azure.archive.ubuntu.com security.ubuntu.com hack32003.vault.azure.net *.letsencrypt.org usage.projectcalico.org gov-prod-policy-data.trafficmanager.net vortex.data.microsoft.com"

# Add Diagnostic Settings
az monitor diagnostic-settings create -n 'AzFWtoLogAnalytics' \
   --resource $azfw_id \
   --workspace $azlaworkspaceId \
   --logs '[{"category":"AzureFirewallApplicationRule","Enabled":true}, {"category":"AzureFirewallNetworkRule","Enabled":true}, {"category":"AzureFirewallDnsProxy","Enabled":true}]' \
   --metrics '[{"category": "AllMetrics","enabled": true}]'

# Update VNET DNS IP
az network vnet update \
  --resource-group $HUBRGNAME \
  --name $HUBVNET_NAME \
  --dns-servers $azfw_private_ip
az network vnet update \
  --resource-group $SPOKERGNAME \
  --name $SPOKEVNET_NAME \
  --dns-servers $azfw_private_ip