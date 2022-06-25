#Log into Azure
#az login

# Setup Variables. (provide your ACR name)
$appName = "GitHub-ACI-Deploy"
$acrName = "<ACRName>"

# Create AAD App and Service Principal and assign to RBAC Role to push and pull images from ACR
$acrId = az acr show --name "$acrName" --query id --output tsv
az ad sp create-for-rbac --name $appName `
    --role "AcrPush" `
    --scopes "$acrId" `
    --sdk-auth
