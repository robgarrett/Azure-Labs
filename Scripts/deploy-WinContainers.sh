#!/bin/bash -e
# Containers available in EastUS.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
./deployAzureTemplate.sh -a "${DIR}/../Win-Containers" -g Docker -l EastUS

