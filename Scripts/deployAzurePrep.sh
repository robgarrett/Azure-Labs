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
            location=$2
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
if [[ -z $location ]]
then
    location="EastUS"
fi

stageResourceGroupName="${labName}-Artifacts"
stageStorageAccountName=$( echo "${stageResourceGroupName//-/}" | awk '{print tolower($0)}' )
stageStorageContainerName=${labName}"-stageartifacts"
stageStorageContainerName=$( echo "${stageStorageContainerName:0:63}" | awk '{print tolower($0)}')

# Copy templates to the build location.
# Include the common templates.
# Named template will supercede common templates.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
buildLoc="${DIR}/../build"
if [ -d "${buildLoc}" ]; then rm -rf "${buildLoc}"; fi 
mkdir -p "${buildLoc}";
cp -rf "../Templates/Common/." "${buildLoc}"
cp -rf "../LABS/${labName}/." "${buildLoc}"
if [[ ! -z $template ]]
then
    cp -rf "../Templates/${template}/." "${buildLoc}"
fi

# Create a storage container to upload our assets.
if [[ $( az group list --query "[?name=='${stageResourceGroupName}']" -o json | jq '. | length' ) = 0 ]]
then
    echo "Creating Resource Group $stageResourceGroupName"
    az group create -n "$stageResourceGroupName" -l "$location" >/dev/null 2>&1
fi 
az configure --defaults group=$stageResourceGroupName
az configure --defaults location=$location

# Create the artifacts storage account.
if [[ $( az storage account list --query "[?name=='${stageStorageAccountName}']" -o json | jq '. | length' ) = 0 ]]
then
    az storage account create -n "$stageStorageAccountName" --sku "Standard_LRS"
fi
# Allow all access for simplicity - ok because the only assets we're uploading are those
# that are on public GitHub.
az storage account update -n "$stageStorageAccountName" \
    --set kind=StorageV2 \
    --default-action Allow \
    --allow-blob-public-access true;
# Create a container.
stageStorageAccountKey=$( az storage account keys list -n "$stageStorageAccountName" -o json | jq -r '.[0].value' )
if [[ $( az storage container list \
    --account-name "$stageStorageAccountName" \
    --account-key "$stageStorageAccountKey" \
    --query "[?name=='${stageStorageContainerName}']" -o json | jq '. | length' ) = 0 ]]
then
    az storage container create \
        -n "$stageStorageContainerName" \
        --account-name "$stageStorageAccountName" \
        --account-key "$stageStorageAccountKey"
fi
# Allow access to the container.
az storage container set-permission \
        -n "$stageStorageContainerName" \
        --account-name "$stageStorageAccountName" \
        --account-key "$stageStorageAccountKey" \
        --public-access container

# Generate SAS token
# Get a 4-hour SAS Token for the artifacts container. Fall back to OSX date syntax if Linux syntax fails.
plusFourHoursUtc=$(date -u -v+4H +%Y-%m-%dT%H:%MZ 2>/dev/null)  || plusFourHoursUtc=$(date -u --date "$dte 4 hour" +%Y-%m-%dT%H:%MZ)
sasToken=$( az storage container generate-sas \
    -n "$stageStorageContainerName" \
    --permissions r \
    --expiry "$plusFourHoursUtc" \
    --account-name "$stageStorageAccountName" \
    --account-key "$stageStorageAccountKey" -o json | sed 's/"//g')

# Patch the parameters file with the SAS token and script location.
templateFile="${buildLoc}/azuredeploy.json"
templateParamsFile="${buildLoc}/azuredeploy.parameters.json"
parameterJson=$( cat "$templateParamsFile" | jq '.parameters' )
_artifactsLocationParameter=$( cat "$templateFile" | jq '.parameters._artifactsLocation' )
_artifactsLocationSasTokenParameter=$( cat "$templateFile" | jq '.parameters._artifactsLocationSasToken' )
parameterJson=$( echo "$parameterJson"  | jq "{_artifactsLocationSasToken: {value: \"?"$sasToken"\"}} + ." )
if [[ $_artifactsLocationParameter == null || $_artifactsLocationSasTokenParameter == null ]]
then
    echo "_artifactsLocationSasToken and/or _artifactsLocation parameters missing in azuredploy.json file."
    exit
fi
blobEndpoint=$( az storage account show -n "$stageStorageAccountName" -o json | jq -r '.primaryEndpoints.blob' )
defaultLocationValue=$( cat "$templateFile" | jq '.parameters._artifactsLocation.defaultValue' )
if [[ $defaultValue != *").properties.templateLink.uri"* ]] 
then 
    parameterJson=$( echo "$parameterJson"  | jq "{_artifactsLocation: {value: "\"$blobEndpoint$stageStorageContainerName/"\"}} + ." )
fi

exit

# Upload files to the container.
stageDirectory=$( echo "$buildLoc" | sed 's/\/*$//')
stageDirectoryLen=$((${#stageDirectory} + 1))
for filepath in $( find "$stageDirectory" -type f )
do
    relFilePath=$( ${filepath:$stageDirectoryLen} | awk '{print tolower($0)} )'
    # TODO: skip parameters file upload.
    echo "Uploading file $relFilePath..."
    az storage blob upload \
        -f $filepath \
        --container $stageStorageContainerName \
        --name $relFilePath \
        --account-name "$stageStorageAccountName" \
        --account-key "$stageStorageAccountKey"
done


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