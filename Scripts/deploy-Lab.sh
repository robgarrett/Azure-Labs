#!/bin/bash -e
SHORT="n:l:t:s:v"
LONG="no-start-vms,debug"
OPTS=$(getopt --options $SHORT --long $LONG --name "$0" -- "$@")
if [ $? != 0 ]; then echo "Failed to parse command-line." >&2; exit 1; fi
eval set -- "$OPTS"

START_VMS=true
DEBUG=false

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
        -s)
            subscriptionId=$2
            shift 2
        ;;
        -v)
            validateOnly=true
            shift
        ;;
        --no-start-vms)
            START_VMS=false
            shift
        ;;
        --debug)
            echo "Operating in debug mode"
            DEBUG=true
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
    location="EastUS2"
fi
if [[ -z $subscriptionId ]] 
then
    echo "I need a subscription Id"
    exit
fi

# Variables
resourceGroupName="${labName}"
stageResourceGroupName="${labName}-Artifacts"
stageStorageAccountName=$( echo "${stageResourceGroupName//-/}" | awk '{print tolower($0)}' )
stageStorageContainerName=${labName}"-stageartifacts"
stageStorageContainerName=$( echo "${stageStorageContainerName:0:63}" | awk '{print tolower($0)}')

# Clean up code.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
buildLoc="${DIR}/../build"
cleanup() { 
    if [ -d "${buildLoc}" ]; then rm -rf "${buildLoc}"; fi 
    if [[ "$DEBUG" == false ]] 
    then
        if [[ $( az group list --query "[?name=='${stageResourceGroupName}']" -o json | jq '. | length' ) > 0 ]]
        then
            echo "Removing Resource Group $stageResourceGroupName"
            az group delete -y -n "$stageResourceGroupName" 1> /dev/null
        fi
    fi 
}

# Call cleanup when we're done.
trap cleanup EXIT ERR INT TERM

# Select the correct subscription.
echo "Checking subscription"
if [[ $( az account list --query "[?id=='${subscriptionId}']" --all | jq '. | length' ) = 0 ]]
then
    echo "I cannot find subscription with id ${subscriptionId}"
    exit
fi
echo "Found subscription ${subscriptionId}"
az account set --subscription "${subscriptionId}" 1> /dev/null

# Copy templates to the build location.
# Include the common templates.
# Named template will supercede common templates.
echo "Copying templates to temp loc: ${buildLoc}"
if [ -d "${buildLoc}" ]; then rm -rf "${buildLoc}"; fi 
mkdir -p "${buildLoc}";
cp -rf "../Templates/Common/." "${buildLoc}"
cp -rf "../LABS/${labName}/." "${buildLoc}"
if [[ ! -z $template ]]
then
    cp -rf "../Templates/${template}/." "${buildLoc}"
fi

# Create a resource group to upload our assets.
echo "Configuring staging resource group: ${stageResourceGroupName}"
if [[ $( az group list --query "[?name=='${stageResourceGroupName}']" -o json | jq '. | length' ) = 0 ]]
then
    echo "Creating Resource Group $stageResourceGroupName"
    az group create -n "$stageResourceGroupName" -l "$location" 1> /dev/null
fi 
az configure --defaults group=$stageResourceGroupName
az configure --defaults location=$location

# Create the artifacts storage account.
echo "Configuring staging storage account: ${stageStorageAccountName}"
if [[ $( az storage account list --query "[?name=='${stageStorageAccountName}']" -o json | jq '. | length' ) = 0 ]]
then
    az storage account create -n "$stageStorageAccountName" --sku "Standard_LRS" 1> /dev/null
fi
# Allow all access for simplicity - ok because the only assets we're uploading are those
# that are on public GitHub.
az storage account update -n "$stageStorageAccountName" \
    --set kind=StorageV2 \
    --default-action Allow \
    --allow-blob-public-access true 1> /dev/null
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
        --account-key "$stageStorageAccountKey" 1> /dev/null
fi
# Allow access to the container.
az storage container set-permission \
        -n "$stageStorageContainerName" \
        --account-name "$stageStorageAccountName" \
        --account-key "$stageStorageAccountKey" \
        --public-access container 1> /dev/null

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
if [[ $defaultLocationValue != *").properties.templateLink.uri"* ]] 
then 
    parameterJson=$( echo "$parameterJson"  | jq "{_artifactsLocation: {value: "\"$blobEndpoint$stageStorageContainerName"\"}} + ." )
fi
templateUri="$blobEndpoint$stageStorageContainerName/$(basename $templateFile)?$sasToken"

# Clean the container.
echo "Uploading files to storage account"
stageDirectory=$( echo "$buildLoc" | sed 's/\/*$//')
stageDirectoryLen=$((${#stageDirectory} + 1))
az storage blob delete-batch \
    --account-name "$stageStorageAccountName" \
    --account-key "$stageStorageAccountKey" \
    --source "$stageStorageContainerName" 1> /dev/null
# Upload files to the container.
for filepath in $( find "$stageDirectory" -type f )
do
    relFilePath=$( echo ${filepath:$stageDirectoryLen} | awk '{print tolower($0)}' )
    if [[ "$relFilePath" != "azuredeploy.parameters.json" ]]
    then
        echo "Uploading file $relFilePath..."
        az storage blob upload \
            -f $filepath \
            --container "$stageStorageContainerName" \
            --name "$relFilePath" \
            --account-name "$stageStorageAccountName" \
            --account-key "$stageStorageAccountKey" 1> /dev/null
    fi
done

# Create a resource group.
echo "Configuring lab resource group ${resourceGroupName}"
if [[ $( az group list --query "[?name=='${resourceGroupName}']" -o json | jq '. | length' ) = 0 ]]
then
    echo "Creating Resource Group $resourceGroupName"
    az group create -n "$resourceGroupName" -l "$location" 1> /dev/null
fi 
az configure --defaults group=$resourceGroupName

if [ "$START_VMS" = true ]; 
then
    # Start servers if we have the resource group for them.
    echo "Starting existing VMs"
    if [[ $( az group list -o json | jq -r '.[].name | select(. == '\"$labName\"')' ) ]]
    then
        # Check for existing VMs and start them.
        echo "Starting existing VMs in $labName"
        VM_NAMES=$(az vm list -g $labName --show-details --query "[?powerState=='VM deallocated'].{ name: name }" -o tsv)
        for NAME in $VM_NAMES
        do
            echo "Starting VM $NAME"
            az vm start -n $NAME -g "$labName" 1> /dev/null
        done
    fi
else
    echo "Skipping starting of existing VMs."
fi

# Get my external IP
myip=$( dig +short myip.opendns.com @resolver1.opendns.com )  
echo "My external IP: ${myip}"
defaultSourceAddressPrefixValue=$( cat "$templateFile" | jq '.parameters.SourceAddressPrefix.defaultValue' )
if [[ $defaultSourceAddressPrefixValue == null ]] 
then 
    parameterJson=$( echo "$parameterJson"  | jq "{SourceAddressPrefix: {value: "\"$myip/32"\"}} + ." )
fi

# Deploy...
if [[ $validateOnly ]]
then
    echo "Validating ${labName}"
    az deployment group validate --template-uri $templateUri --parameters "$parameterJson" --verbose
else
    echo "Deploying ${labName}"
    az deployment group create -n "Lab-Deployment" --template-uri $templateUri --parameters "$parameterJson" --verbose
fi

exit_code=$?
