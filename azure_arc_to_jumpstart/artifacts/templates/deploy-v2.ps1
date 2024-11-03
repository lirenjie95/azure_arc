$resourceGroup = "<YOURRESOURCEGROUP>"
$location = "<YOURLOCATION>"
$providerName="Microsoft.ToolchainOrchestrator"

az resource create --resource-group $resourceGroup --resource-type "$providerName/campaigns" -n campaign --is-full-object --properties "@campaigncontainer.json" --api-version "2024-08-01-preview" --verbose
az resource create --resource-group $resourceGroup --namespace "$providerName" -n v1 --resource-type versions --parent "campaigns/campaign" --is-full-object --properties "@campaign.json" --location $location --api-version "2024-08-01-preview" --verbose
az resource create --resource-group $resourceGroup --resource-type "$providerName/activations" -n activation --is-full-object --properties "@activation.json" --api-version "2024-08-01-preview" --verbose
