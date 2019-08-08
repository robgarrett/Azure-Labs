#!/bin/bash -e
while getopts ":n:l:" opt; do
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
    labName="Lab-SP2019"
fi
if [[ -z $location ]]
then
    location="CentralUS"
fi

./deploy-Lab.sh \
    -n "${labName}" \
    -l "${location}" \
    -t "SharePoint"