#!/bin/bash -e
# Need availability zones, which are currently in Cemntral US.
./deployAzureTemplate.sh -a Lab-SP2016 -g Lab-SP2016 -l CentralUS
