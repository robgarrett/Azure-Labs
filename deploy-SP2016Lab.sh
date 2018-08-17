#!/bin/bash -e

labName="Lab-SP2016"
resourceGroupName="${labName}-Artifacts"
storageAccountName=$( echo "${resourceGroupName//-/}" | awk '{print tolower($0)}' )

# Create my own storage account.
az group create -n "${resourceGroupName}" -l "CentralUS"
az storage account create -l "CentralUS" --sku "Standard_LRS" -g "${resourceGroupName}" -n "${storageAccountName}"

# Need availability zones, which are currently in Cemntral US.
./deployAzureTemplate.sh -a "Common/AD" -g Lab-SP2016 -l CentralUS -e "Lab-SP2016/azuredeploy.parameters.json" -s "${storageAccountName}"
