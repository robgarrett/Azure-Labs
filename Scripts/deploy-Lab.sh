#!/bin/bash -e
while getopts ":n:l:t:" opt; do
    case $opt in
        n)
            labName=$OPTARG
        ;;
        l)
            location=$OPTARG
        ;;
        t)
            template=$OPTARG
        ;;
    esac
done

if [[ -z $labName ]]
then
    echo "I need a LAB name."
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

echo "Prepping ${labName}"
./deployAzurePrep.sh -n "${labName}" -l "${location}" -t "${template}"

echo "Creating ${labName}"
./deployAzureTemplate.sh \
    -a "${DIR}/../build" \
    -g "${labName}" \
    -l "${location}" \
    -e "${DIR}/../LABS/${labName}/azuredeploy.parameters.json" \
    -s "${storageAccountName}"

exit_code=$?
