#!/usr/bin/env bash

if [ $# -ne 2 ]; then
    echo "Usage $0 <loaderName> <ensembleName>"
    exit 1
fi

LOADER_NAME="loader.${1}.json"
PREDICT_CSV="predict.${1}.csv"
PREDICT_PATH="ensemble/${2}/predict_dates.csv"

if [ -f $PREDICT_CSV ]; then
    echo "$PREDICT_CSV already exists"
    exit 1
fi

jq -c '.sources[].dates["test"][]' $LOADER_NAME | sort | uniq | sed -r \
    -e 's/"//g' \
    -e 's/([0-9]{4})_([0-9]{2})_([0-9]{2})/\1-\2-\3/' >$PREDICT_CSV

mkdir -p `dirname $PREDICT_PATH`
ln -s `realpath $PREDICT_CSV` $PREDICT_PATH

echo "Created ensemble link at ${PREDICT_PATH}, run_predict_ensemble will pick this up"
exit 0

