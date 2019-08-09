#!/bin/bash -e
while getopts ":n:l:s:" opt; do
    case $opt in
        n)
            labName=$OPTARG
        ;;
        l)
            location=$OPTARG
        ;;
        s)
            subscriptionId=$OPTARG
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
-t "SharePoint" \
-s "${subscriptionId}"