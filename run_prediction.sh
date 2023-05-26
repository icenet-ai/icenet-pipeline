#!/usr/bin/bash

set -e -o pipefail

. ENVS

conda activate $ICENET_CONDA

if [ $# -lt 3 ] || [ "$1" == "-h" ]; then
    echo "$0 <forecast name> <model> <hemisphere> [date_vars] [train_data_name]"
    echo "<forecast_name>   name of forecast"
    echo "<model>           model name"
    echo "<hemisphere>      hemisphere to use"
    echo "[date_vars]       variables for defining start and end dates to forecast"
    echo "[train_data_name] name of data used to train the model"
    echo "Options"
    echo "-m <metrics>      pass in a string of metrics separated by commas (to pass into ./run_forecast_plots.sh), by default \"\""
    echo "-e                compare forecast performance with ECMWF"
    echo "-l                produce leadtime averaged plots"
    echo "-v                produce video using the individual metric plots by stitching them together with ffmpeg"
    exit 1
fi

# obtaining any arguments that should be passed onto run_forecast_plots.sh
METRICS_FLAG=""
E_FLAG=""
V_FLAG=""
L_FLAG=""
OPTIND=1
while getopts "m:elv" opt; do
    case "$opt" in
        m)  METRICS_FLAG="-m ${OPTARG}" ;;
        e)  E_FLAG="-e" ;;
        l)  L_FLAG="-l" ;;
        v)  V_FLAG="-v"
    esac
done

echo "Passing on the following arguments to run_forecast_plots.sh: ${METRICS_FLAG} ${E_FLAG} ${V_FLAG} ${L_FLAG}"

shift $((OPTIND-1))

echo "Leftovers from getopt: $@"

FORECAST="$1"
MODEL="$2"
HEMI="$3"
DATE_VARS="${4:-$FORECAST}"
DATA_PROC="${5:-${TRAIN_DATA_NAME}}_${HEMI}"

# This assumes you're not retraining using the same model name, eek
if [ -d results/networks/$MODEL ]; then
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
echo "Dates from ENVS: $NAME_START and $NAME_END"
PREDICTION_START=${!NAME_START}
PREDICTION_END=${!NAME_END}

if [ -z $PREDICTION_START ] || [ -z $PREDICTION_END ]; then
    echo "Prediction date args not set correctly: \"$PREDICTION_START\" to \"$PREDICTION_END\""
    exit 1
else
    echo "Prediction start arg: $PREDICTION_START"
    echo "Prediction end arg: $PREDICTION_END"
fi

[ ! -z "$PROC_ARGS_ERA5" ] && \
    icenet_process_era5 -r processed/$DATA_PROC/era5/$HEMI \
        $PROC_ARGS_ERA5 \
        -v -l $LAG -ts $PREDICTION_START -te $PREDICTION_END ${FORECAST}_${HEMI} $HEMI

[ ! -z "$PROC_ARGS_ORAS5" ] && \
    icenet_process_oras5 -r processed/$DATA_PROC/oras5/$HEMI \
        $PROC_ARGS_ORAS5 \
        -v -l $LAG -ts $PREDICTION_START -te $PREDICTION_END ${FORECAST}_${HEMI} $HEMI

[ ! -z "$PROC_ARGS_SIC" ] && \
    icenet_process_sic  -r processed/$DATA_PROC/osisaf/$HEMI \
        $PROC_ARGS_SIC \
        -v -l $LAG -ts $PREDICTION_START -te $PREDICTION_END ${FORECAST}_${HEMI} $HEMI

icenet_process_metadata ${FORECAST}_${HEMI} $HEMI
icenet_dataset_create -l $LAG -c ${FORECAST}_${HEMI} $HEMI
./loader_test_dates.sh ${FORECAST}_${HEMI} >${FORECAST}_${HEMI}.csv

./run_predict_ensemble.sh -i $DATASET -f $FILTER_FACTOR -p $PREP_SCRIPT \
    $MODEL ${FORECAST}_${HEMI} ${FORECAST}_${HEMI} ${FORECAST}_${HEMI}.csv

./run_forecast_plots.sh ${METRICS_FLAG} ${E_FLAG} ${V_FLAG} ${L_FLAG} $FORECAST $HEMI
