#!/usr/bin/bash -l

source ENVS
source scripts/pipeline_cmds.sh
conda activate $ICENET_CONDA

set -o pipefail
set -eu

if [ $# -lt 1 ] || [ "$1" == "-h" ]; then
    echo "Usage $0 <hemisphere> [download=0|1]"
    exit 1
fi

HEMI="$1"
DOWNLOAD=${2:-0}
DRY=${3:-0}

CONFIG_SUFFIX="${DATA_FREQUENCY}.${HEMI}.json"
AMSR2_DATA="data.amsr2"
AMSR2_PROC="proc.amsr2"
ERA5_DATA="data.era5"
ERA5_PROC="proc.era5"

# download-toolbox integration
# This updates our source
if [ $DOWNLOAD -eq 1 ]; then
  # We use --config-path to localise the generation of config to the pipeline rather than the dataset
  pipeline_run download_amsr2 --config-path ${AMSR2_DATA}.${CONFIG_SUFFIX} $DATA_ARGS $HEMI $AMSR2_DATES $AMSR2_VAR_ARGS
  pipeline_run download_cds -i era5 --config-path ${ERA5_DATA}.${CONFIG_SUFFIX} $DATA_ARGS $HEMI $ERA5_DATES $ERA5_VAR_ARGS
fi 2>&1 | tee logs/download.amsr_training.log

[ ! -f ref.amsr2.${HEMI}.nc ] && pipeline_run ln -s $( realpath $( ls data/amsr2_6250/siconca/*/*${HEMI:0:1}6250-*-v5.4.nc | head -n 1 ) ) ref.amsr2.${HEMI}.nc

# Creates a new version of the dataset - processed_data/
if [ ! -f interp.amsr2.$CONFIG_SUFFIX ]; then
  pipeline_run preprocess_missing_time \
    -c ./interp.amsr2.$CONFIG_SUFFIX \
    -n siconca -v $AMSR2_DATA.$CONFIG_SUFFIX $AMSR2_PROC
fi

# Creates a new version of the dataset - processed_data/ so include any lag
# The resulting configuration doesn't care about splits, so it won't carry forward
if [ ! -f regrid.era5.$CONFIG_SUFFIX ]; then
  pipeline_run preprocess_regrid -v -c ./regrid.era5.$CONFIG_SUFFIX \
    -ps "train" -sn "train,val,test" \
    -ss "$TRAIN_START,$VAL_START,$TEST_START" -se "$TRAIN_END,$VAL_END,$TEST_END" \
    -sh `expr $LAG + 1` -st $FORECAST_LENGTH \
    $ERA5_DATA.$CONFIG_SUFFIX ref.amsr2.${HEMI}.nc $ERA5_PROC
fi

##
# AMSR2 ground truth with ERA5
#

PROCESSED_DATASET="${TRAIN_DATA_NAME}.${DATA_FREQUENCY}.${HEMI}"

## Workflow
pipeline_run preprocess_loader_init -v $PROCESSED_DATASET
pipeline_run preprocess_add_mask -v $PROCESSED_DATASET $AMSR2_DATA.$CONFIG_SUFFIX land "icenet.data.masks.nsidc:Masks"

pipeline_run preprocess_dataset $PROC_ARGS_SIC -v \
  -ps "train" -sn "train,val,test" \
  -ss "$TRAIN_START,$VAL_START,$TEST_START" -se "$TRAIN_END,$VAL_END,$TEST_END" \
  -sh `expr $LAG + 1` -st $FORECAST_LENGTH \
  -i "icenet.data.processors.amsr:AMSR2PreProcessor" \
  interp.amsr2.$CONFIG_SUFFIX ${PROCESSED_DATASET}_amsr

pipeline_run preprocess_dataset $PROC_ARGS_ERA5 -v \
  -ps "train" -sn "train,val,test" \
  -ss "$TRAIN_START,$VAL_START,$TEST_START" -se "$TRAIN_END,$VAL_END,$TEST_END" \
  -sh `expr $LAG + 1` -st $FORECAST_LENGTH \
  -i "icenet.data.processors.cds:ERA5PreProcessor" \
  regrid.era5.$CONFIG_SUFFIX ${PROCESSED_DATASET}_era5

pipeline_run preprocess_add_processed -v $PROCESSED_DATASET processed.${PROCESSED_DATASET}_amsr.json processed.${PROCESSED_DATASET}_era5.json

pipeline_run preprocess_add_channel -v $PROCESSED_DATASET interp.amsr2.$CONFIG_SUFFIX sin "icenet.data.meta:SinProcessor"
pipeline_run preprocess_add_channel -v $PROCESSED_DATASET interp.amsr2.$CONFIG_SUFFIX cos "icenet.data.meta:CosProcessor"
pipeline_run preprocess_add_channel -v $PROCESSED_DATASET interp.amsr2.$CONFIG_SUFFIX land_map "icenet.data.masks.nsidc:Masks"

LOADER_CONFIGURATION="loader.${PROCESSED_DATASET}.json"
DATASET_NAME=`basename $( pwd )`"_${HEMI}"

pipeline_run icenet_dataset_create -v -c -p -ob $BATCH_SIZE -w $WORKERS -fl $FORECAST_LENGTH $LOADER_CONFIGURATION $DATASET_NAME

# For when we don't have the preceding data, make sure there's an offset. These will be dropped in generation
if [ $DRY == 0 ]; then
  LAG_DATE=${PLOT_DATE:-`cat ${LOADER_CONFIGURATION} | jq -r '.sources[.sources|keys[0]].splits.train[0]'`}
else
  OFFSET=""
  if [ $DATA_FREQUENCY == "month" ]; then
    # This ensures we're providing the end day of the month
    OFFSET=" + 1 month - 1 day"
  fi
  LAG_DATE=`date --date="$( echo $TRAIN_START | awk -F'|' '{ print $1 }' ) + $( expr $LAG + 1 ) ${DATA_FREQUENCY}s $OFFSET" +%F`
fi
mkdir -p plots
pipeline_run icenet_plot_input -p -v dataset_config.${DATASET_NAME}.json ${LAG_DATE} ./plots/amsr_input.${HEMI}.${LAG_DATE}.png
pipeline_run icenet_plot_input --outputs -v dataset_config.${DATASET_NAME}.json ${LAG_DATE} ./plots/amsr_outputs.${HEMI}.${LAG_DATE}.png
pipeline_run icenet_plot_input --weights -v dataset_config.${DATASET_NAME}.json ${LAG_DATE} ./plots/amsr_weights.${HEMI}.${LAG_DATE}.png

echo -n "To CACHE the dataset, please run: "
echo icenet_dataset_create -v -p -l $LAG -ob $BATCH_SIZE -w $WORKERS -fl $FORECAST_LENGTH $LOADER_CONFIGURATION $DATASET_NAME
