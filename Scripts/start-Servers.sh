#!/bin/bash -e
while getopts ":n:s:" opt; do
    case $opt in
        n)
            labName=$OPTARG
        ;;
        s)
            subscriptionId=$OPTARG
        ;;
    esac
done

if [[ -z $labName ]]
then
    labName="Lab-SP2019"
fi

if [[ -z $subscriptionId ]]
then
    echo "I need a subscription ID."
    exit
else
    az account set --subscription "${subscriptionId}"
fi

resourceGroupName="${labName}"

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
else
    echo "${labName} resource group does not exist, nothing to do."
fi
