$resourceGroup = "<YOURRESOURCEGROUP>"
$location = "<YOURLOCATION>"
$providerName="Microsoft.ToolchainOrchestrator"

az resource create --resource-group $resourceGroup --resource-type "$providerName/targets" -n target --is-full-object --properties "@target.json" --api-version "2024-08-01-preview" --verbose
az resource create --resource-group $resourceGroup --resource-type "$providerName/solutions" -n solution --is-full-object --properties "@solutioncontainer.json" --api-version "2024-08-01-preview" --verbose
az resource create --resource-group $resourceGroup --namespace "$providerName" -n v1 --resource-type versions --parent "solutions/solution" --is-full-object --properties "@solution.json" --location $location --api-version "2024-08-01-preview" --verbose
az resource create --resource-group $resourceGroup --resource-type "$providerName/instances" -n instance --is-full-object --properties "@instance.json" --api-version "2024-08-01-preview" --verbose
