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

echo "Creating ${labName}"
resourceGroupName="${labName}-Artifacts"
storageAccountName=$( echo "${resourceGroupName//-/}" | awk '{print tolower($0)}' )
storageContainerName=$( echo "${labName}-stageartifacts" | awk '{print tolower($0)}' )

# Need availability zones, which are currently in Central US.
location="CentralUS"
resourceGroupName="${labName}-Artifacts"
storageAccountName=$( echo "${resourceGroupName//-/}" | awk '{print tolower($0)}' )

echo "Prepping ${labName}"
./deployAzurePrep.sh -n "${labName}" -l "${location}"

echo "Creating ${labName}"
./deployAzureTemplate.sh -a "Common/SP" -g "${labName}" -l CentralUS -e "${labName}/SP/azuredeploy.parameters.json" -s "${storageAccountName}"
