param (
    [string]$clientId,
    [string]$identityName,
    [string]$subscriptionId,
    [string]$resourceGroup,
    [string]$azureLocation,
    [string]$clusterName,
    [string]$extensionName,
    [string]$customLocationName,
    [string]$extensionVersion,
    [string]$templateBaseUrl
)

# Create path
Write-Output "Create deployment path"
$tempDir = "C:\Temp"
$currentTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
New-Item -Path $tempDir -ItemType directory -Force
Start-Transcript "$tempDir\Bootstrap_$currentTime.log"
$ErrorActionPreference = "Stop"

# Install Azure CLI
$azCommand = Get-Command az -ErrorAction Ignore
if ($null -eq $azCommand)
{
    Write-Host "Installing Azure CLI"
    Invoke-WebRequest -Uri https://aka.ms/installazurecliwindowsx64 -OutFile .\AzureCLI.msi
    Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'
    Remove-Item .\AzureCLI.msi
 
    # Apply PATH to current session right away as the auto-updated system PATH won't take effect until next session
    if (-not $env:Path.Contains("C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin")) {
        $env:Path="$env:Path;C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin"
    }
    # Re-check if az command is available
    $azCommand = Get-Command az -ErrorAction Ignore
    if ($null -eq $azCommand) {
        Write-Host "Azure CLI installation failed" -ForegroundColor Red
        exit 1
    }
}
else
{
    Write-Host "Azure CLI is already installed"
}

# Install kubectl
$kubectlCommand = Get-Command kubectl -ErrorAction Ignore
if ($null -eq $kubectlCommand) {
    Write-Host "Installing kubectl"
    New-Item -Path "C:\Program Files\kubectl" -ItemType directory -Force
    Invoke-WebRequest -Uri "https://dl.k8s.io/release/v1.31.0/bin/windows/amd64/kubectl.exe" -OutFile "C:\Program Files\kubectl\kubectl.exe"
    if (-not $env:Path.Contains("C:\Program Files\kubectl")) {
        $env:Path="$env:Path;C:\Program Files\kubectl"
    }
    # Re-check if kubectl command is available
    $kubectlCommand = Get-Command kubectl -ErrorAction Ignore
    if ($null -eq $kubectlCommand) {
        Write-Host "kubectl installation failed" -ForegroundColor Red
        exit 1
    }
}
else
{
    Write-Host "kubectl is already installed"
}
# Install helm
$helmCommand = Get-Command helm -ErrorAction Ignore
if ($null -eq $helmCommand)
{
    Write-Host "Installing helm"
    Invoke-WebRequest -Uri "https://get.helm.sh/helm-v3.11.0-windows-amd64.zip" -OutFile .\helm.zip
    Expand-Archive .\helm.zip -DestinationPath "C:\Program Files\helm"
    Move-Item "C:\Program Files\helm\windows-amd64\helm.exe" -Destination "C:\Program Files\helm\helm.exe"
    Remove-Item .\helm.zip
    if (-not $env:Path.Contains("C:\Program Files\helm")) {
        $env:Path="$env:Path;C:\Program Files\helm"
    }
    # Re-check if helm command is available
    $helmCommand = Get-Command helm -ErrorAction Ignore
    if ($null -eq $helmCommand) {
        Write-Host "helm installation failed" -ForegroundColor Red
        exit 1
    }
}
else
{
    Write-Host "helm is already installed"
}

# Install cert-manager and trust-manager
Write-Output "installing cert-manager"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.3/cert-manager.yaml --wait
Write-Output "waiting for cert-manager to be ready"
kubectl wait --for=condition=Available deployment/cert-manager-webhook -n cert-manager --timeout=300s
Write-Output "Waiting for 30 seconds for cert-manager webhook TLS certs to be ready"
Start-Sleep -Seconds 30
Write-Output "installing trust-manager"
helm repo add jetstack https://charts.jetstack.io --force-update
helm upgrade trust-manager jetstack/trust-manager --install --namespace cert-manager --wait

az --version
# Login as managed identity
az login --identity --username $clientId

az provider register --namespace Microsoft.Kubernetes
az provider register --namespace Microsoft.KubernetesConfiguration
az provider register --namespace Microsoft.ExtendedLocation
az provider register --namespace Microsoft.ToolchainOrchestrator

az provider show -n Microsoft.Kubernetes -o table
az provider show -n Microsoft.KubernetesConfiguration -o table
az provider show -n Microsoft.ExtendedLocation -o table
az provider show -n Microsoft.ToolchainOrchestrator -o table

# Installing Azure CLI extensions
Write-Host "`n"
az extension add --name "connectedk8s" -y
az extension add --name "k8s-extension" -y
az extension add --name "customlocation" -y

# Start to arc enable the cluster and install extension
az account set -s $subscriptionId
az aks get-credentials --name $clusterName --resource-group $resourceGroup --overwrite-existing --admin
# Add cert to deal with connection issue in VM
Invoke-WebRequest -Uri https://secure.globalsign.net/cacert/Root-R1.crt -OutFile "$tempDir\globalsignR1.crt"
Import-Certificate -FilePath "$tempDir\globalsignR1.crt" -CertStoreLocation Cert:\LocalMachine\Root 
az connectedk8s connect -g $resourceGroup -n $clusterName --location $azureLocation
az k8s-extension create `
    --resource-group $resourceGroup `
    --cluster-name $clusterName `
    --cluster-type connectedClusters `
    --name $extensionName `
    --extension-type Microsoft.ToolchainOrchestrator `
    --scope cluster `
    --release-train dev `
    --version $extensionVersion `
    --auto-upgrade false `
    --config redis.persistentVolume.enabled=true

az k8s-extension show --resource-group $resourceGroup --cluster-name $clusterName --cluster-type connectedClusters --name $extensionName

az connectedk8s enable-features -n $clusterName -g $resourceGroup --features cluster-connect custom-locations
### By adding --namespace you can bound the namespace to the custom location being created, by default it will use your custom location name.###

$KUBECONFIG = "C:\Windows\System32\config\systemprofile\.kube\config"
# When running in custom script extension, the Username: WORKGROUP\SYSTEM will be used, and the default kubeconfig path is above.
$hostResourceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Kubernetes/connectedClusters/$clusterName"
$clusterExtensionId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Kubernetes/connectedClusters/$clusterName/Providers/Microsoft.KubernetesConfiguration/extensions/$extensionName"
az customlocation create `
    -n $customLocationName `
    -g $resourceGroup `
    --namespace $customLocationName `
    --host-resource-id $hostResourceId `
    --cluster-extension-ids $clusterExtensionId `
    --location $azureLocation `
    --kubeconfig $KUBECONFIG

# Define an array of file URLs
$urls = @(
    "$templateBaseUrl/templates/deploy-v1.ps1",
    "$templateBaseUrl/templates/deploy-v2.ps1",
    "$templateBaseUrl/templates/instance.json",
    "$templateBaseUrl/templates/solution.json",
    "$templateBaseUrl/templates/solutioncontainer.json",
    "$templateBaseUrl/templates/target.json",
    "$templateBaseUrl/templates/campaign.json",
    "$templateBaseUrl/templates/campaigncontainer.json",
    "$templateBaseUrl/templates/activation.json"
)

# Define a hashtable of strings to be replaced and their replacements
$replacements = @{
    "<YOURLOCATION>" = $azureLocation
    "<YOURRESOURCEGROUP>" = $resourceGroup
    "<YOURSUBID>" = $subscriptionId
    "<YOURCUSTOMLOCATION>" = $customLocationName
}

# Download files and perform string replacements
foreach ($url in $urls) {
    # Get the file name
    $fileName = [System.IO.Path]::GetFileName($url)
    # Define the full path to save the file
    $filePath = [System.IO.Path]::Combine($tempDir, $fileName)
    try {
        # Debug information
        Write-Host "Downloading file from URL: $url" -ForegroundColor Yellow
        Write-Host "Saving file to path: $filePath" -ForegroundColor Yellow
        # Download the file
        Invoke-WebRequest -Uri $url -OutFile $filePath -ErrorAction Stop
        # Read the file content
        $content = Get-Content -Path $filePath
        # Perform string replacements
        foreach ($key in $replacements.Keys) {
            $content = $content -replace $key, $replacements[$key]
        }
        # Save the modified file
        Set-Content -Path $filePath -Value $content
    } catch {
        Write-Host "Failed to download or process file: $url" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}