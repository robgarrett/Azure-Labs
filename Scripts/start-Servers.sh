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

# Check for existing VMs and start them.
VM_NAMES=$(az vm list -g $labName --show-details --query "[?powerState=='VM deallocated'].{ name: name }" -o tsv)
for NAME in $VM_NAMES
do
    echo "Starting VM $NAME"
    az vm start -n $NAME -g "$labName" --no-wait
done

