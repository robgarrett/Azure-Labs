#!/bin/bash -e
# Need availability zones, which are currently in Cemntral US.
./deployAzureTemplate.sh -a "Common/AD" -g Lab-SP2016 -l CentralUS -e "Lab-SP2016/azuredeploy.parameters.json"
