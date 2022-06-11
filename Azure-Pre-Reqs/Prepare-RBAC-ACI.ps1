#Log into Azure
#az login

# Setup Variables.
$aciResourceGroupName = "Demo-ACI-GitHub-Runners-RG"
$appName="GitHub-ACI-Deploy"
$acrName="<ACRName>"
$region = "uksouth"

# Create a resource group to deploy ACIs to
az group create --name "$aciResourceGroupName" --location "$region"
$aciRGId = az group show --name "$aciResourceGroupName" --query id --output tsv

# Create AAD App and Service Principal and assign to RBAC Role to ACI deployment RG
az ad sp create-for-rbac --name $appName `
    --role "Contributor" `
    --scopes "$aciRGId" `
    --sdk-auth

# Assign additional RBAC role to Service Principal to push and pull images from ACR 
$acrId = az acr show --name "$acrName" --query id --output tsv
az ad sp list --display-name $appName --query [].appId -o tsv | ForEach-Object {
    az role assignment create --assignee "$_" `
        --role "AcrPush" `
        --scope "$acrId"
    }
