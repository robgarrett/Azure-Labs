#!/bin/bash -e
while getopts ":n:l" opt; do
    case $opt in
        n)
            labName=$OPTARG
        ;;
        l)
            location=$OPTARG
        ;;
    esac
done

if [[ -z $labName ]]
then
    labName="Lab-AD"
fi
if [[ -z $location ]]
then
    location="CentralUS"
fi

resourceGroupName="${labName}-Artifacts"
storageAccountName=$( echo "${resourceGroupName//-/}" | awk '{print tolower($0)}' )
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "Prepping ${labName}"
./deployAzurePrep.sh -n "${labName}" -l "${location}"

echo "Creating ${labName}"
./deployAzureTemplate.sh -a "${DIR}/../Common/AD" -g "${labName}" -l "${location}" -e "${DIR}/../${labName}/AD/azuredeploy.parameters.json" -s "${storageAccountName}"

