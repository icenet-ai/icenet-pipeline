#!/usr/bin/env bash

HEMI=$1
SPLIT=$2
DATASET="$3_$HEMI"
ERROR_FOLDER=network_datasets/${DATASET}/${HEMI}/${SPLIT}.data_errors
CHECK_LOG=logs/check.${DATASET}.${SPLIT}.log

if [ ! -f $CHECK_LOG ]; then
    icenet_dataset_check -s $SPLIT dataset_config.${DATASET}.json 2>&1 | tee $CHECK_LOG
fi

mkdir $ERROR_FOLDER

for FILENAME in $( grep 'WARNING' $CHECK_LOG | sed -r \
  -e 's/^.+([0-9]{8}\.tfrecord).+$/\1/' \
   | uniq ); do
    if [ -f network_datasets/${DATASET}/${HEMI}/${SPLIT}/$FILENAME ]; then
        echo mv -v network_datasets/${DATASET}/${HEMI}/${SPLIT}/$FILENAME $ERROR_FOLDER;
    fi
done

mv -v $CHECK_LOG $ERROR_FOLDER
