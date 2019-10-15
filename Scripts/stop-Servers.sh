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
fi

resourceGroupName="${labName}"

# Check for existing VMs and stop them.
VM_NAMES=$(az vm list -g $resourceGroupName --show-details --query "[?powerState=='VM running'].{ name: name }" -o tsv)
for NAME in $VM_NAMES
do
    echo "Stopping VM $NAME"
    az vm deallocate -n $NAME -g $resourceGroupName --no-wait
done

# Stop servers if we have the resource group for them.
if [[ $( az group list -o json | jq -r '.[].name | select(. == '\"$labName\"')' ) ]]
then
    # Check for existing VMs and stop them.
    echo "Starting existing VMs in $labName"
    VM_NAMES=$(az vm list -g $resourceGroupName --show-details --query "[?powerState=='VM running'].{ name: name }" -o tsv)
    for NAME in $VM_NAMES
    do
        echo "Stopping VM $NAME"
        az vm deallocate -n $NAME -g $resourceGroupName --no-wait
    done
fi