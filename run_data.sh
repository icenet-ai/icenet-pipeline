#!/bin/bash

. ENVS

conda activate $ICENET_CONDA

set -o pipefail
set -eu

DATANAME="dataset_name"
HEMI="${1:-$HEMI}"
BATCH_SIZE=${2:-2}
WORKERS=${3:-8}

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

icenet_dataset_create -v -p -ob $BATCH_SIZE -w $WORKERS -fd $FORECAST_DAYS -l $LAG ${DATANAME}_${HEMI} $HEMI
