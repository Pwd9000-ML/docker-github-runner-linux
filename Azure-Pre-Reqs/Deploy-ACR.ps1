#Log into Azure
#az login

# Setup Variables.
$randomInt = Get-Random -Maximum 9999
$resourceGroupName = "Demo-Azure-Container-Registry"
$region = "uksouth"
$acrName = "pwd9000registry$randomInt"

# Create a resource resourceGroupName
az group create --name "$resourceGroupName" --location "$region"

# Create an ACR (Basic)
az acr create --resource-group "$resourceGroupName" `
    --name "$acrName" `
    --sku "Basic" `
    --admin-enabled "false"