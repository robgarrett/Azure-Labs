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

resourceGroupName="${labName}"

# Check for existing VMs and stop them.
VM_NAMES=$(az vm list -g $resourceGroupName --show-details --query "[?powerState=='VM running'].{ name: name }" -o tsv)
for NAME in $VM_NAMES
do
    echo "Stopping VM $NAME"
    az vm deallocate -n $NAME -g $resourceGroupName --no-wait
done

