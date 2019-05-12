#!/bin/bash -e
while getopts ":n:l:f:" opt; do
    case $opt in
        n)
            labName=$OPTARG
        ;;
        l)
            location=$OPTARG
        ;;
        f)
            functionApp=$OPTARG
        ;;
    esac
done

if [[ -z $labName ]]
then
    labName="Functions"
fi
if [[ -z $location ]]
then
    location="EastUS2"
fi
if [[ -z $functionApp ]]
then
    echo "I need a function app name!"
    exit
fi

echo "Creating ${labName} Lab."
if [[ -z $( az group list -o json | jq -r '.[].name | select(. == '\"$labName\"')' ) ]]
then
    echo "Creating Resource Group ${labName}."
    az group create -n "$labName" -l "$location"
fi

if [[ -z $( az storage account list -o json | jq -r '.[].name | select(. == '\"rdgfuncs\"')' ) ]]
then
    echo "Creating storage account."
    az storage account create -l "$location" --sku "Standard_LRS" -g "$labName" -n "rdgfuncs" 2>/dev/null
fi

if [[ -z $( az appservice plan list -o json | jq -r '.[].name | select(. == '\"rdg-funcs-svc\"')' ) ]]
then
    echo "Creating App Service Plan."
    az appservice plan create -l "$location" -g "$labName" -n "rdg-funcs-svc" --is-linux --sku B1
fi

if [[ -z $( az functionapp list -o json | jq -r '.[].name | select(. == '\"$functionApp\"')' ) ]]
then
    echo "Creating Function App ${functionApp}."
    az functionapp create \
        -g "$labName" \
        -n "rdg-funcs-$functionApp" \
        -p "rdg-funcs-svc" \
        -s "rdgfuncs" \
        --runtime "node" \
        --os-type "Linux"
fi
