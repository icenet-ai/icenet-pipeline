#!/usr/bin/bash

set -eu -o pipefail

. ENVS

conda activate $ICENET_CONDA

if [ $# -lt 2 ]; then
  echo "$0 <forecast name> <model> [hemisphere] [loader]"
  exit 1
fi

FORECAST="$1"
MODEL="$2"
HEMI="${3:-$HEMI}"
DATE_VARS="${4:-$FORECAST}"

# This assumes you're not retraining using the same model name, eek
if [ ! -d results/networks/$MODEL ]; then
  SAVEFILE=`ls results/networks/${MODEL}/${MODEL}.*.h5 | head -n 1`
  DATASET=`echo $SAVEFILE | perl -lpe's/.+\.network_(.+)\.[0-9]+\.h5/$1/'`
  echo "First model file: $SAVEFILE"
  echo "Dataset model was trained on: $DATASET"
else
  echo "Model $MODEL doesn't exist"
  exit 1
fi

NAME_START="${DATE_VARS^^}_START"
NAME_END="${DATE_VARS^^}_END"
PREDICTION_START=${!NAME_START}
PREDICTION_END=${!NAME_END}

if [ -z $PREDICTION_START ] || [ -z $PREDICTION_END ]; then
  echo "Prediction date args not set correctly: \"$PREDICTION_START\" to \"$PREDICTION_END\""
  exit 1
else
  echo "Prediction start arg: $PREDICTION_START"
  echo "Prediction end arg: $PREDICTION_END"
fi

# FIXME: due to https://github.com/icenet-ai/icenet/issues/53 we assume don't
#DOWNLOAD=${5:-0}

#if [ $DOWNLOAD == 1 ]; then
#    echo "Downloading required data"
#    [ ! -z "$DATA_ARGS_ERA5" ] && \
#        icenet_data_era5 $HEMI $START $END -v $DATA_ARGS_ERA5
#
#    [ ! -z "$DATA_ARGS_ORAS5" ] && \
#        icenet_data_oras5 $HEMI $START $END -v $DATA_ARGS_ORAS5
#
#    icenet_data_sic $HEMI $PRED_START $PRED_END -v
#fi

# If you didn't train the model, use
#    ln -s /data/hpcdata/users/<train_user>/icenet/pipeline/processed/trainproc/ ./processed/trainproc
# to link the training normalisation parameters
[ ! -z "$PROC_ARGS_ERA5" ] && \
    icenet_process_era5 -r processed/${TRAIN_DATA_NAME}_${HEMI}/era5/$HEMI \
        $PROC_ARGS_ERA5 \
        -v -l $LAG -ts $PRED_START -te $PRED_END ${FORECAST}_${HEMI} $HEMI

[ ! -z "$PROC_ARGS_ORAS5" ] && \
    icenet_process_oras5 -r processed/${TRAIN_DATA_NAME}_${HEMI}/oras5/$HEMI \
        $PROC_ARGS_ORAS5 \
        -v -l $LAG -ts $PRED_START -te $PRED_END ${FORECAST}_${HEMI} $HEMI

[ ! -z "$PROC_ARGS_SIC" ] && \
    icenet_process_sic  -r processed/${TRAIN_DATA_NAME}_${HEMI}/osisaf/$HEMI \
        $PROC_ARGS_SIC \
        -v -l $LAG -ts $PRED_START -te $PRED_END ${FORECAST}_${HEMI} $HEMI

icenet_process_metadata ${FORECAST}_${HEMI} $HEMI
icenet_dataset_create -l $LAG -c ${FORECAST}_${HEMI} $HEMI
./loader_test_dates.sh ${FORECAST}_${HEMI} >${FORECAST}_${HEMI}.csv

./run_predict_ensemble.sh -i $DATASET -f $FILTER_FACTOR -p $PREP_SCRIPT \
    $MODEL ${FORECAST}_${HEMI} ${FORECAST}_${HEMI} ${FORECAST}_${HEMI}.csv

./run_forecast_plots.sh $FORECAST $HEMI
