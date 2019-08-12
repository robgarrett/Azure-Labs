#!/bin/bash -e
while getopts ":n:l:t:" opt; do
    case $opt in
        n)
            labName=$OPTARG
        ;;
        l)
            location=$OPTARG #location for the deployed resource group
        ;;
        t)
            template=$OPTARG
        ;;
    esac
done

if [[ -z $labName ]]
then
    echo "I need a lab name."
    exit
fi
if [[ -z $template ]]
then
    echo "I need a template name."
    exit
fi
if [[ -z $location ]]
then
    location="CentralUS"
fi

resourceGroupName="${labName}-Artifacts"
storageAccountName=$( echo "${resourceGroupName//-/}" | awk '{print tolower($0)}' )
storageContainerName=$( echo "${labName}-stageartifacts" | awk '{print tolower($0)}' )

# Copy templates to the build location.
buildLoc="../build"
if [ -d "${buildLoc}" ]; then rm -rf "${buildLoc}"; fi 
mkdir -p "${buildLoc}";
cp -rf "../Templates/${template}/." "${buildLoc}"
cp -rf "../Templates/Common/." "${buildLoc}"

# Create the artifacts storage account because the deploy script won't create
# it if we supply our own name.
if [[ -z $( az storage account list -o json | jq -r '.[].name | select(. == '\"$storageAccountName\"')' ) ]]
then
    echo "Creating Resource Group $resourceGroupName"
    az group create -n "$resourceGroupName" -l "$location"
    az storage account create -l "$location" --sku "Standard_LRS" -g "$resourceGroupName" -n "$storageAccountName" 2>/dev/null
fi

# Start servers if we have the resource group for them.
if [[ $( az group list -o json | jq -r '.[].name | select(. == '\"$labName\"')' ) ]]
then
    # Check for existing VMs and start them.
    echo "Starting existing VMs in $labName"
    VM_NAMES=$(az vm list -g $labName --show-details --query "[?powerState=='VM deallocated'].{ name: name }" -o tsv)
    for NAME in $VM_NAMES
    do
        echo "Starting VM $NAME"
        az vm start -n $NAME -g "$labName" --no-wait
    done
fi


