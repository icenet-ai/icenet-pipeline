#!/usr/bin/env bash

echo "Cleaning the environment, your results, plots and configurations will be backed up"

BACKUPDIR="backups/`date +%F-%T`"

if [ -d $BACKUPDIR ]; then
    echo "Backup directory $BACKUPDIR already exists, abandoning"
    exit 1
else
    mkdir -p $BACKUPDIR
fi

for BACK_FILE in $( ls dataset_config.*.json loader.*.json 2>/dev/null ); do
    mv -v $BACK_FILE $BACKUPDIR
    rm -v $BACK_FILE
done

for ENSEMBLE_RUN in $( find ensemble/ \
    -maxdepth 1 \
    -type d -a \
    ! -name 'ensemble' -a \
    ! -name 'template' \
    -print ); do 
    find $ENSEMBLE_RUN -type l -a \( -name 'loader.*.json' -o -name 'dataset_config.*.json' \) -delete
    mv -v $ENSEMBLE_RUN $BACKUP_DIR
done

mkdir -p $BACKUPDIR/plot/
mv plot/* $BACKUPDIR/plot/

for NORM_PARAMS in $( find processed/ -name 'normalisation.scale' -o -name 'params' -print ); do
    PROC_PATH=`dirname $NORMED_FILES`

    mkdir -p $BACKUPDIR/$PROC_PATH
    mv -v $NORM_PARAMS $BACKUPDIR/$PROC_PATH/
done

rm -rv logs/*
rm -rv network_datasets/*
rm predict.*.csv
rm -rv processed/*
rm -rv _sicfile/
rm -rv wandb/
