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
storageContainerName=$( echo "${labName}-stageartifacts" | awk '{print tolower($0)}' )

# Check for existing VMs and start them.
VM_NAMES=$(az vm list -g $resourceGroupName --show-details --query "[?powerState=='VM deallocated'].{ name: name }" -o tsv)
for NAME in $VM_NAMES
do
    echo "Starting VM $NAME"
    az vm start -n $NAME -g $resourceGroupName --no-wait
done

# Create my own storage account.
az group create -n "${resourceGroupName}" -l "CentralUS"
az storage account create -l "CentralUS" --sku "Standard_LRS" -g "${resourceGroupName}" -n "${storageAccountName}"

# Need availability zones, which are currently in Central US.
#./deployAzureTemplate.sh -a "Common/AD" -g "${labName}" -l CentralUS -e "${labName}/AD/azuredeploy.parameters.json" -s "${storageAccountName}"

# Create the SP Servers.
az storage blob delete-batch --account-name "${storageAccountName}" --source "${storageContainerName}"
./deployAzureTemplate.sh -a "Common/SP" -g "${labName}" -l CentralUS -e "${labName}/SP/azuredeploy.parameters.json" -s "${storageAccountName}"
