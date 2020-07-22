#!/bin/bash -e
SHORT="n:l:t:s:"
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
        -s)
            subscriptionId=$2
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
    location="EastUS2"
fi

# Clean up code.
buildLoc="../build"
cleanup() {
    if [ -d "${buildLoc}" ]; then rm -rf "${buildLoc}"; fi
}

# Call cleanup when we're done.
trap cleanup EXIT ERR INT TERM

resourceGroupName="${labName}-Artifacts"
storageAccountName=$( echo "${resourceGroupName//-/}" | awk '{print tolower($0)}' )
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Select the correct subscription.
if [[ $( az account list | jq '. | length' ) > 0 ]]
then
    if [[ -z $subscriptionId ]] 
    then
        echo "I need a subscription Id"
        exit
    fi
    az account set --subscription "${subscriptionId}"
fi

echo "Prepping ${labName}"
if [ "$START_VMS" = true ]; 
then
    ./deployAzurePrep.sh -n "${labName}" -l "${location}" -t "${template}"
else
    ./deployAzurePrep.sh -n "${labName}" -l "${location}" -t "${template}" --no-start-vms
fi

echo "Creating ${labName}"
./deployAzureTemplate.sh \
-a "${DIR}/../build" \
-g "${labName}" \
-l "${location}" \
-e "${DIR}/../LABS/${labName}/azuredeploy.parameters.json" \
-s "${storageAccountName}"

exit_code=$?
