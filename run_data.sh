#!/bin/bash

. ENVS

conda activate $ICENET_CONDA

set -o pipefail
set -eu

if [ $# -lt 1 ] || [ "$1" == "-h" ]; then
    echo "Usage $0 <hemisphere> [batch_size] [workers]"
fi

DATANAME="$TRAIN_DATA_NAME"
HEMI="$1"
BATCH_SIZE=${2:-2}
WORKERS=${3:-8}

if [ ! -f loader.${DATANAME}_${HEMI}.json ]; then
    [ ! -z "$PROC_ARGS_ERA5" ] && icenet_process_era5 -v -l $LAG \
        $PROC_ARGS_ERA5 \
        -ns $TRAIN_START -ne $TRAIN_END -vs $VAL_START -ve $VAL_END -ts $TEST_START -te $TEST_END \
        ${DATANAME}_${HEMI} $HEMI

    [ ! -z "$PROC_ARGS_ORAS5" ] && icenet_process_oras5 -v -l $LAG \
        $PROC_ARGS_ORAS5 \
        -ns $TRAIN_START -ne $TRAIN_END -vs $VAL_START -ve $VAL_END -ts $TEST_START -te $TEST_END \
        ${DATANAME}_${HEMI} $HEMI

    [ ! -z "$PROC_ARGS_SIC" ] && icenet_process_sic -v -l $LAG \
        $PROC_ARGS_SIC \
        -ns $TRAIN_START -ne $TRAIN_END -vs $VAL_START -ve $VAL_END -ts $TEST_START -te $TEST_END \
        ${DATANAME}_${HEMI} $HEMI

    icenet_process_metadata ${DATANAME}_${HEMI} $HEMI
else
    echo "Skipping preprocessing as loader.${DATANAME}_${HEMI}.json already exists..."
fi

icenet_dataset_create -v -p -ob $BATCH_SIZE -w $WORKERS -fd $FORECAST_DAYS -l $LAG ${DATANAME}_${HEMI} $HEMI
