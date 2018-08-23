#!/bin/bash -e
while getopts ":n:" opt; do
    case $opt in
        n)
            labName=$OPTARG
        ;;
    esac
done

if [[ -z $labName ]]
then
    labName="Lab-SP2016"
fi

echo "Creating ${labName}"
resourceGroupName="${labName}-Artifacts"
storageAccountName=$( echo "${resourceGroupName//-/}" | awk '{print tolower($0)}' )

# Create my own storage account.
az group create -n "${resourceGroupName}" -l "CentralUS"
az storage account create -l "CentralUS" --sku "Standard_LRS" -g "${resourceGroupName}" -n "${storageAccountName}"

# Need availability zones, which are currently in Cemntral US.
./deployAzureTemplate.sh -a "Common/AD" -g "${labName}" -l CentralUS -e "${labName}/azuredeploy.parameters.json" -s "${storageAccountName}"
