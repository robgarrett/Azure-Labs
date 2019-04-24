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
    labName="Docker"
fi
if [[ -z $location ]]
then
    location="EastUS2"
fi

resourceGroupName="${labName}-Artifacts"
storageAccountName=$( echo "${resourceGroupName//-/}" | awk '{print tolower($0)}' )
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "Prepping ${labName}"
./deployAzurePrep.sh -n "${labName}" -l "${location}"

echo "Creating ${labName}"
./deployAzureTemplate.sh \
    -a "${DIR}/../Common/VM-Single" \
    -g "${labName}" \
    -l "${location}" \
    -e "${DIR}/../LABS/${labName}/azuredeploy.parameters.json" \
    -s "${storageAccountName}"
