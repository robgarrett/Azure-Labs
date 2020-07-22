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
    echo "I need a lab name."
    exit
fi

if [[ -z $subscriptionId ]]
then
    echo "I need a subscription ID."
    exit
else
    az account set --subscription "${subscriptionId}"
fi

resourceGroupName="${labName}"

# Stop servers if we have the resource group for them.
if [[ $( az group list -o json | jq -r '.[].name | select(. == '\"$labName\"')' ) ]]
then
    # Check for existing VMs and stop them.
    echo "Stopping existing VMs in $labName"
    VM_NAMES=$(az vm list -g $labName --show-details --query "[?powerState=='VM running'].{ name: name }" -o tsv)
    for NAME in $VM_NAMES
    do
        echo "Stopping VM $NAME"
        az vm deallocate -n $NAME -g "$labName" --no-wait
    done
else
    echo "${labName} resource group does not exist, nothing to do."
fi