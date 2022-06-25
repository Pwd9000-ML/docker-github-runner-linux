#Log into Azure
#az login

#Add container app extension to Azure-CLI
az extension add --name containerapp

#Variables (ACA)
$randomInt = Get-Random -Maximum 9999
$region = "uksouth"
$acaResourceGroupName = "Demo-ACA-GitHub-Runners-RG" #Resource group created to deploy ACAs
$acaStorageName = "aca2keda2scaler$randomInt" #Storage account that will be used to scale runners/KEDA queue scaling
$acaEnvironment = "gh-runner-aca-env-$randomInt" #Azure Container Apps Environment Name
$acaLaws = "$acaEnvironment-laws" #Log Analytics Workspace to link to Container App Environment
$acaName = "myghprojectpool" #Azure Container App Name

#Variables (ACR) - ACR Admin account needs to be enabled
$acrLoginServer = "registryname.azurecr.io" #The login server name of the ACR (all lowercase). Example: _myregistry.azurecr.io_
$acrUsername = "acrAdminUser" #The Admin Account `Username` on the ACR
$acrPassword = "acrAdminPassword" #The Admin Account `Password` on the ACR
$acrImage = "$acrLoginServer/pwd9000-github-runner-lin:2.293.0" #Image reference to pull

#Variables (GitHub)
$pat = "ghPatToken" #GitHub PAT token
$githubOrg = "Pwd9000-ML" #GitHub Owner/Org
$githubRepo = "docker-github-runner-linux" #Target GitHub repository to register self hosted runners against
$appName = "GitHub-ACI-Deploy" #Previously created Service Principal linked to GitHub Repo (See part 3 of blog series)

# Create a resource group to deploy ACA
az group create --name "$acaResourceGroupName" --location "$region"
$acaRGId = az group show --name "$acaResourceGroupName" --query id --output tsv

# Create an azure storage account and queue to be used for scaling with KEDA
az storage account create `
    --name "$acaStorageName" `
    --location "$region" `
    --resource-group "$acaResourceGroupName" `
    --sku "Standard_LRS" `
    --kind "StorageV2" `
    --https-only true `
    --min-tls-version "TLS1_2"
$storageConnection = az storage account show-connection-string --resource-group "$acaResourceGroupName" --name "$acaStorageName" --output tsv
$storageId = az storage account show --name "$acaStorageName" --query id --output tsv

az storage queue create `
    --name "gh-runner-scaler" `
    --account-name "$acaStorageName" `
    --connection-string "$storageConnection"

#Create Log Analytics Workspace for ACA
az monitor log-analytics workspace create --resource-group "$acaResourceGroupName" --workspace-name "$acaLaws"
$acaLawsId = az monitor log-analytics workspace show -g $acaResourceGroupName -n $acaLaws --query customerId --output tsv
$acaLawsKey = az monitor log-analytics workspace get-shared-keys -g $acaResourceGroupName -n $acaLaws --query primarySharedKey --output tsv

#Create ACA Environment
az containerapp env create --name "$acaEnvironment" `
    --resource-group "$acaResourceGroupName" `
    --logs-workspace-id "$acaLawsId" `
    --logs-workspace-key "$acaLawsKey" `
    --location "$region"

# Grant AAD App and Service Principal Contributor to ACA deployment RG + `Storage Queue Data Contributor` on Storage account
az ad sp list --display-name $appName --query [].appId -o tsv | ForEach-Object {
    az role assignment create --assignee "$_" `
        --role "Contributor" `
        --scope "$acaRGId"

    az role assignment create --assignee "$_" `
        --role "Storage Queue Data Contributor" `
        --scope "$storageId"
}

#Create Container App from docker image (self hosted GitHub runner) stored in ACR
az containerapp create --resource-group "$acaResourceGroupName" `
    --name "$acaName" `
    --image "$acrImage" `
    --environment "$acaEnvironment" `
    --registry-server "$acrLoginServer" `
    --registry-username "$acrUsername" `
    --registry-password "$acrPassword" `
    --secrets gh-token="$pat" storage-connection-string="$storageConnection" `
    --env-vars GH_OWNER="$githubOrg" GH_REPOSITORY="$githubRepo" GH_TOKEN=secretref:gh-token `
    --cpu "1.75" --memory "3.5Gi" `
    --min-replicas 0 `
    --max-replicas 3