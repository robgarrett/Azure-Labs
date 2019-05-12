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
    labName="Functions"
fi

resourceGroupName="${labName}"

# Check for existing Funtions and stop them.
FUNC_NAMES=$(az functionapp list -g $resourceGroupName --query "[?state=='Running'].{ name: name }" -o tsv)
for NAME in $FUNC_NAMES
do
    echo "Stopping $NAME"
    az functionapp stop -n "$NAME" -g "$resourceGroupName"
done

