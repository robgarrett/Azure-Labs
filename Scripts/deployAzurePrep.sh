#!/bin/bash -e
SHORT="n:l:t:"
LONG="no-start-vms"

OPTS=$(getopt --options $SHORT --long $LONG --name "$0" -- "$@")
if [ $? != 0 ]; then echo "Failed to parse command-line." >&2; exit 1; fi
eval set -- "$OPTS"

START_VMS=true

while true; do
    case "$1" in
        -n)
            labName=$2
            shift 2
        ;;
        -l)
            location=$2 #location for the deployed resource group
            shift 2
        ;;
        -t)
            template=$2
            shift 2
        ;;
        --no-start-vms)
            START_VMS=false
            shift
        ;;
        --)
            shift
            break
        ;;
        *)
            echo "Internal Error!"
            exit 1
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
# Include the common templates.
# Named template will supercede common templates.
buildLoc="../build"
if [ -d "${buildLoc}" ]; then rm -rf "${buildLoc}"; fi 
mkdir -p "${buildLoc}";
cp -rf "../Templates/Common/." "${buildLoc}"
cp -rf "../Templates/${template}/." "${buildLoc}"

# Create the artifacts storage account because the deploy script won't create
# it if we supply our own name.
if [[ -z $( az storage account list -o json | jq -r '.[].name | select(. == '\"$storageAccountName\"')' ) ]]
then
    echo "Creating Resource Group $resourceGroupName"
    az group create -n "$resourceGroupName" -l "$location"
    az storage account create -l "$location" --sku "Standard_LRS" -g "$resourceGroupName" -n "$storageAccountName" 2>/dev/null
    # Make sure that the storage account is V2.
    az storage account update -g "$resourceGroupName" -n "$storageAccountName" --set kind=StorageV2 2>/dev/null
fi
az storage account update -g "$resourceGroupName" -n "$storageAccountName" --default-action Allow

if [ "$START_VMS" = true ]; 
then
    # Start servers if we have the resource group for them.
    if [[ $( az group list -o json | jq -r '.[].name | select(. == '\"$labName\"')' ) ]]
    then
        # Check for existing VMs and start them.
        echo "Starting existing VMs in $labName"
        VM_NAMES=$(az vm list -g $labName --show-details --query "[?powerState=='VM deallocated'].{ name: name }" -o tsv)
        for NAME in $VM_NAMES
        do
            echo "Starting VM $NAME"
            az vm start -n $NAME -g "$labName"
        done
    fi
else
    echo "Skipping starting of existing VMs."
fi

exit_code=$?