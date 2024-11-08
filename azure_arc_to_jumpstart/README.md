# Jumpstart for Toolchain Orchestrator

## Steps

1. Create a resource group and related [managed identity](https://learn.microsoft.com/en-us/cli/azure/identity?view=azure-cli-latest#az-identity-create). Then assign the contributor role to the managed identity. If you don't have any RSA public key, please also generate one. Examples are shown below.

```powershell
az group create -l eastus2 -n <YOUR_RESOURCE_GROUP>
az identity create --name <YOUR_IDENTITY> --resource-group <YOUR_RESOURCE_GROUP>
az role assignment create --assignee <YOUR_CLIENT_ID> --role Contributor --scope "/subscriptions/<YOUR_SUBSCRIPTION_ID>"
ssh-keygen -t rsa -b 4096
```

2. Download the `azuredeploy.parameters.json` parameter file and edit `clientID`, `identityName` (with the related field from your managed identity), and your RSA public key fields. Then run below command:

```powershell
az deployment group create --resource-group <YOUR_RESOURCE_GROUP> --name tojumpstart --template-uri https://raw.githubusercontent.com/lirenjie95/azure_arc/to-jumpstart/azure_arc_to_jumpstart/azuredeploy.json --parameters azuredeploy.parameters.json
```

3. Log in the client VM created in previous step (You can use RDP). And open the `C:\temp` folder. There will be some json templates and two deployment powershell scripts as shown below.

```txt
solutioncontainer.json
solution.json
target.json
instance.json
campaigncontainer.json
campaign.json
activation.json
deploy-v1.ps1
deploy-v2.ps1
```

4. Run `deploy-v1.ps1` to deploy target, solution and instance. **TODO: how to get IP address**. Open a web browser and type in that IP. Then you can see the first version web application.

5. Run `deploy-v2.ps1` to deploy campaign and activation. The activation will trigger the process of deploying web service v2 and switch the load balancer to bring all traffic to web service v2. After you found the execution of the script is done, you can go back to the web browser, and wait for 1 or 2 minutes to observe the switch.