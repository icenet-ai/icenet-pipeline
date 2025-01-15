#!/usr/bin/bash -l

set -e -o pipefail

. ENVS

conda activate $ICENET_CONDA

if [ $# -lt 2 ] || [ "$1" == "-h" ]; then
    echo "Usage $0 <prediction_name> <hemisphere> [date_vars] [train_data_name]"
    echo "<prediction_name> name of prediction dataset"
    echo "<hemisphere>      hemisphere to use"
    echo "[date_vars]       variables for defining start and end dates to forecast"
    echo "[train_data_name] name of data used to train the model"
    echo "Options: none"
    exit 1
fi

# obtaining any arguments that should be passed onto run_forecast_plots.sh
OPTIND=1
while getopts "" opt; do
    case "$opt" in
    esac
done

shift $((OPTIND-1))

echo "Leftovers from getopt: $@"

PREDICTION_NAME="$1"
HEMI="$2"
DATE_VARS="${3:-$PREDICTION_NAME}"
DATA_PROC="${4:-${TRAIN_DATA_NAME}}.${HEMI}"

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

PREDICTION_DATASET="prediction.${PREDICTION_NAME}.${HEMI}"
LOADER_CONFIGURATION="loader.${PREDICTION_DATASET}.json"

PRED_DATA_START=`date --date "$PREDICTION_START - $LAG ${DATA_FREQUENCY}s" +%Y-%m-%d`
# download-toolbox integration
(
  # We don't do AMSR2 and CMIP as part of this, but everything is similar if you want to ;)
  # download_amsr2 $DATA_ARGS $HEMI $AMSR2_DATES $AMSR2_VAR_ARGS
  download_osisaf $DATA_ARGS $HEMI $PRED_DATA_START $PREDICTION_END $OSISAF_VAR_ARGS
  download_era5 $DATA_ARGS $HEMI $PRED_DATA_START $PREDICTION_END $ERA5_VAR_ARGS
  # download_cmip --source MRI-ESM2-0 --member r1i1p1f1 $DATA_ARGS $HEMI $CMIP6_DATES $CMIP6_VAR_ARGS
) 2>&1 | tee logs/download.${PREDICTION_DATASET}.log

DATASET_CONFIG_NAME="dataset_config.${DATA_FREQUENCY}.hemi.${HEMI}.json"

# preprocess-toolbox integration
# Persistent datasets from the source data store, wherever that is
OSISAF_DATASET="${SOURCE_DATA_STORE}/osisaf/${DATASET_CONFIG_NAME}"
ERA5_DATASET="${SOURCE_DATA_STORE}/era5/${DATASET_CONFIG_NAME}"

ATMOS_PROC="era5_osi.$PREDICTION_DATASET"
ATMOS_PROC_DSC="${PROCESSED_DATA_STORE}/${ATMOS_PROC}/${DATASET_CONFIG_NAME}"

# Create links to the central data store datasets for easier "mapping"
[ ! -e data/osisaf ] && [ -d ${SOURCE_DATA_STORE}/osisaf ] && ln -s ${SOURCE_DATA_STORE}/osisaf ./data/osisaf
[ ! -e data/era5 ] && [ -d ${SOURCE_DATA_STORE}/era5 ] && ln -s ${SOURCE_DATA_STORE}/era5 ./data/era5

LOADER_CONFIGURATION="loader.${PREDICTION_DATASET}.json"
TRAIN_LOADER_CONFIGURATION="loader.${TRAIN_DATA_NAME}.${HEMI}.json"

preprocess_loader_init -v $PREDICTION_DATASET
preprocess_loader_copy $TRAIN_LOADER_CONFIGURATION loader.${PREDICTION_DATASET}.json masks channels

preprocess_dataset $PROC_ARGS_SIC -v \
  -sn "prediction" -ss "$PREDICTION_START" -se "$PREDICTION_END" \
  -r processed/${DATA_PROC}_osisaf/ \
  -i "icenet.data.processors.osisaf:SICPreProcessor" \
  -sh $LAG -st $FORECAST_LENGTH \
  $OSISAF_DATASET ${PREDICTION_DATASET}_osisaf

if [ ! -f ref.osisaf.${HEMI}.nc ]; then
  echo "Reference OSISAF for regrid should still be available, bailing for the mo"
  exit 1
fi

preprocess_regrid -v \
  -sn "prediction" -ss "$PREDICTION_START" -se "$PREDICTION_END" \
  -sh $LAG -st $FORECAST_LENGTH \
  $ERA5_DATASET ref.osisaf.${HEMI}.nc $ATMOS_PROC
preprocess_rotate -v \
  -n uas,vas $ATMOS_PROC_DSC ref.osisaf.${HEMI}.nc

preprocess_dataset $PROC_ARGS_ERA5 -v \
  -sn "prediction" -ss "$PREDICTION_START" -se "$PREDICTION_END" \
  -r processed/${DATA_PROC}_era5/ \
  -i "icenet.data.processors.cds:ERA5PreProcessor" \
  -sh $LAG -st $FORECAST_LENGTH \
  $ATMOS_PROC_DSC ${PREDICTION_DATASET}_era5

preprocess_add_processed -v $LOADER_CONFIGURATION processed.${PREDICTION_DATASET}_osisaf.json processed.${PREDICTION_DATASET}_era5.json

icenet_dataset_create -v -c -p -fl $FORECAST_LENGTH $LOADER_CONFIGURATION $PREDICTION_DATASET

FIRST_DATE=${PLOT_DATE:-`cat ${LOADER_CONFIGURATION} | jq '.sources[.sources|keys[0]].splits.prediction[0]' | tr -d '"'`}
icenet_plot_input -p -v dataset_config.${PREDICTION_DATASET}.json $FIRST_DATE ./plot/input.${HEMI}.${FIRST_DATE}.png
