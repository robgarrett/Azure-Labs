#!/bin/bash -e
SHORT="n:l:s:"
LONG="no-start-vms,ha-farm"

OPTS=$(getopt --options $SHORT --long $LONG --name "$0" -- "$@")
if [ $? != 0 ]; then echo "Failed to parse command-line." >&2; exit 1; fi
eval set -- "$OPTS"

START_VMS=true
TEMPLATE="SharePointLite"

while true; do
    case "$1" in
        -n)
            labName=$2
            shift 2
        ;;
        -l)
            location=$2
            shift 2
        ;;
        -s)
            subscriptionId=$2
            shift 2
        ;;
        --no-start-vms)
            START_VMS=false
            shift
        ;;
        --ha-farm)
            TEMPLATE="SharePointHA"
            shift
        ;;
        --)
            shift
            break
        ;;
        *)
            echo "Internal Error!"
            exit 1
        ;;
    esac
done

if [[ -z $labName ]]
then
    echo "I need a lab name."
    exit
fi
if [[ -z $location ]]
then
    location="EastUS2"
fi

if [ "$START_VMS" = true ]; 
then
    ./deploy-Lab.sh \
    -n "${labName}" \
    -l "${location}" \
    -t "${TEMPLATE}" \
    -s "${subscriptionId}"
else
    ./deploy-Lab.sh \
    -n "${labName}" \
    -l "${location}" \
    -t "${TEMPLATE}" \
    -s "${subscriptionId}" \
    --no-start-vms
fi
