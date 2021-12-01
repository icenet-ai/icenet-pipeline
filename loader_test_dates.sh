#!/usr/bin/env bash

if [ $# -ne 2 ]; then
    echo "Usage $0 <loaderName>"
    exit 1
fi

LOADER_NAME="loader.${1}.json"

jq -c '.sources[].dates["test"][]' $LOADER_NAME | sort | uniq | sed -r \
    -e 's/"//g' \
    -e 's/([0-9]{4})_([0-9]{2})_([0-9]{2})/\1-\2-\3/'

exit 0
