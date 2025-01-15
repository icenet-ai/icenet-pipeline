#!/usr/bin/bash -l

set -e -o pipefail

. ENVS

conda activate $ICENET_CONDA

if [ $# -lt 3 ] || [ "$1" == "-h" ]; then
    echo "Usage $0 <prediction_name> <model> <hemisphere> [date_vars] [train_data_name]"
    echo "<prediction_name> name of prediction]"
    echo "<model>           model name"
    echo "<hemisphere>      hemisphere to use"
    echo "Options: none"
    exit 1
fi

PREDICTION_NAME="prediction.$1"
MODEL="$2"
HEMI="$3"
EXTRA_ARGS="${4:-""}"

# This assumes you're not retraining using the same model name, eek
if [ -d results/networks/${MODEL}.${HEMI} ]; then
    SAVEFILE=`ls results/networks/${MODEL}.${HEMI}/${MODEL}.${HEMI}.*.h5 | head -n 1`
    DATASET=`echo $SAVEFILE | perl -lpe's/.+\.network_(.+)\.[0-9]+\.h5/$1/'`
    echo "First model file: $SAVEFILE"
    echo "Dataset model was trained on: $DATASET"
else
    echo "Model $MODEL doesn't exist"
    exit 1
fi

LOADER_NAME="loader.${PREDICTION_NAME}.${HEMI}.json"
jq -c '.sources[].splits["prediction"][]' $LOADER_NAME | sort | uniq | sed -r \
    -e 's/"//g' \
    -e 's/([0-9]{4})_([0-9]{2})_([0-9]{2})/\1-\2-\3/' >${PREDICTION_NAME}.${HEMI}.csv

./run_predict_ensemble.sh $EXTRA_ARGS -i $DATASET -f $FILTER_FACTOR -p $PREP_SCRIPT \
    ${MODEL}.${HEMI} ${PREDICTION_NAME}.${HEMI} ${PREDICTION_NAME}.${HEMI} ${PREDICTION_NAME}.${HEMI}.csv
