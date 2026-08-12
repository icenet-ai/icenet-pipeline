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
OSISAF_DATA="data.osisaf"
OSISAF_PROC="proc.osisaf"
ERA5_DATA="data.era5"
ERA5_PROC="proc.era5"
#%% ADD ORAS5 DATASETS
ORAS5_DATA="data.oras5"
ORAS5_PROC="proc.oras5"

# download-toolbox integration
# This updates our source
if [ $DOWNLOAD -eq 1 ]; then
  # We use --config-path to localise the generation of config to the pipeline rather than the dataset
  pipeline_run download_osisaf --config-path ${OSISAF_DATA}.${CONFIG_SUFFIX} $DATA_ARGS $HEMI $OSISAF_DATES $OSISAF_VAR_ARGS
  pipeline_run download_cds -i era5 --config-path ${ERA5_DATA}.${CONFIG_SUFFIX} $DATA_ARGS $HEMI $ERA5_DATES $ERA5_VAR_ARGS
  # ORAS5 download command doesn't exist in this version of download-toolbox
  # Configuration file has been manually created using scripts/generate_oras5_config.py
  # pipeline_run download_oras5 -n --config-path ${ORAS5_DATA}.${CONFIG_SUFFIX} $DATA_ARGS $HEMI $ORAS5_DATES $ORAS5_VAR_ARGS
fi 2>&1 | tee logs/download.osisaf_training.log

##
# OSISAF ground truth with ERA5 and ORAS5
#

PROCESSED_DATASET="${TRAIN_DATA_NAME}.${DATA_FREQUENCY}.${HEMI}"

# Calculate maximum lag needed for preprocessing, considering VAR_LAG_OVERRIDE
MAX_LAG_SH=`expr $LAG + 1`
if [ -n "$VAR_LAG_OVERRIDE" ] && [ "$VAR_LAG_OVERRIDE" != "{}" ]; then
  # Extract maximum lag value from VAR_LAG_OVERRIDE JSON
  MAX_VAR_LAG=$(echo "$VAR_LAG_OVERRIDE" | jq -r 'to_entries | max_by(.value) | .value')
  if [ $MAX_VAR_LAG -gt $MAX_LAG_SH ]; then
    MAX_LAG_SH=$MAX_VAR_LAG
    echo "Using MAX_LAG_SH=$MAX_LAG_SH from VAR_LAG_OVERRIDE (max variable lag: $MAX_VAR_LAG)"
  fi
fi

## Workflow
pipeline_run preprocess_loader_init -v $PROCESSED_DATASET
pipeline_run preprocess_add_mask -v $PROCESSED_DATASET $OSISAF_DATA.$CONFIG_SUFFIX land "icenet.data.masks.osisaf:Masks"
pipeline_run preprocess_add_mask -v $PROCESSED_DATASET $OSISAF_DATA.$CONFIG_SUFFIX polarhole "icenet.data.masks.osisaf:Masks"
pipeline_run preprocess_add_mask -v $PROCESSED_DATASET $OSISAF_DATA.$CONFIG_SUFFIX active_grid_cell "icenet.data.masks.osisaf:Masks"



# We CAN supply splits and lead / lag to prevent unnecessarily large copies of datasets
# or interpolation of time across huge spans
if [ ! -f interp.osisaf.$CONFIG_SUFFIX ]; then
  pipeline_run preprocess_missing_time \
    -ps "train" -sn "train,val,test" \
    -ss "$TRAIN_START,$VAL_START,$TEST_START" -se "$TRAIN_END,$VAL_END,$TEST_END" \
    -sh $MAX_LAG_SH -st $FORECAST_LENGTH \
    -c ./interp.osisaf.$CONFIG_SUFFIX \
    -n siconca -v $OSISAF_DATA.$CONFIG_SUFFIX $OSISAF_PROC

  pipeline_run preprocess_missing_spatial \
    -m processed.masks.osisaf.${HEMI}.json -mp land,inactive_grid_cell,polarhole \
    -n siconca -v interp.osisaf.$CONFIG_SUFFIX
fi

pipeline_run preprocess_dataset $PROC_ARGS_SIC -v \
  -ps "train" -sn "train,val,test" \
  -ss "$TRAIN_START,$VAL_START,$TEST_START" -se "$TRAIN_END,$VAL_END,$TEST_END" \
  -sh $MAX_LAG_SH -st $FORECAST_LENGTH \
  -i "icenet.data.processors.osisaf:SICPreProcessor" \
  interp.osisaf.$CONFIG_SUFFIX ${PROCESSED_DATASET}_osisaf

HEMI_SHORT="nh"
[ $HEMI == "south" ] && HEMI_SHORT="sh"

pipeline_run icenet_generate_ref_osisaf -v data/masks.osisaf/ice_conc_${HEMI_SHORT}_ease2-250_cdr-v2p0_200001021200.nc

# Creates a new version of the dataset - processed_data/ so include any lag
# The resulting configuration doesn't care about splits, so it won't carry forward

if [ ! -f regrid.era5.$CONFIG_SUFFIX ]; then
  pipeline_run preprocess_regrid -v -c ./regrid.era5.$CONFIG_SUFFIX \
    -ps "train" -sn "train,val,test" \
    -ss "$TRAIN_START,$VAL_START,$TEST_START" -se "$TRAIN_END,$VAL_END,$TEST_END" \
    -sh $MAX_LAG_SH -st $FORECAST_LENGTH \
    $ERA5_DATA.$CONFIG_SUFFIX ref.osisaf.${HEMI}.nc $ERA5_PROC
  pipeline_run preprocess_rotate -n uas,vas -v regrid.era5.$CONFIG_SUFFIX ref.osisaf.${HEMI}.nc
fi

# ORAS5 regridding with ORCA grid support


if [ ! -f regrid.oras5.$CONFIG_SUFFIX ]; then
  pipeline_run preprocess_regrid -v -c ./regrid.oras5.$CONFIG_SUFFIX \
    --coord-method preprocess_toolbox.dataset.orca_grid:orca_coord_processing \
    -ps "train" -sn "train,val,test" \
    -ss "$TRAIN_START,$VAL_START,$TEST_START" -se "$TRAIN_END,$VAL_END,$TEST_END" \
    -sh $MAX_LAG_SH -st $FORECAST_LENGTH \
    $ORAS5_DATA.$CONFIG_SUFFIX ref.osisaf.${HEMI}.nc $ORAS5_PROC
  # Note: ORAS5 currents may need rotation similar to ERA5 winds
  # Uncomment if ocean currents (uo, vo) need to be rotated:
  # pipeline_run preprocess_rotate -n uo,vo -v regrid.oras5.$CONFIG_SUFFIX ref.osisaf.${HEMI}.nc
fi

pipeline_run preprocess_dataset $PROC_ARGS_ERA5 -v \
  -ps "train" -sn "train,val,test" \
  -ss "$TRAIN_START,$VAL_START,$TEST_START" -se "$TRAIN_END,$VAL_END,$TEST_END" \
  -sh $MAX_LAG_SH -st $FORECAST_LENGTH \
  -i "icenet.data.processors.cds:ERA5PreProcessor" \
  regrid.era5.$CONFIG_SUFFIX ${PROCESSED_DATASET}_era5

pipeline_run preprocess_dataset $PROC_ARGS_ORAS5 -v \
  -ps "train" -sn "train,val,test" \
  -ss "$TRAIN_START,$VAL_START,$TEST_START" -se "$TRAIN_END,$VAL_END,$TEST_END" \
  -sh $MAX_LAG_SH -st $FORECAST_LENGTH \
  -i "icenet.data.processors.cmems:ORAS5PreProcessor" \
  regrid.oras5.$CONFIG_SUFFIX ${PROCESSED_DATASET}_oras5

pipeline_run preprocess_add_processed -v $PROCESSED_DATASET processed.${PROCESSED_DATASET}_osisaf.json processed.${PROCESSED_DATASET}_era5.json processed.${PROCESSED_DATASET}_oras5.json

pipeline_run preprocess_add_channel -v $PROCESSED_DATASET interp.osisaf.$CONFIG_SUFFIX sin "icenet.data.meta:SinProcessor"
pipeline_run preprocess_add_channel -v $PROCESSED_DATASET interp.osisaf.$CONFIG_SUFFIX cos "icenet.data.meta:CosProcessor"
pipeline_run preprocess_add_channel -v $PROCESSED_DATASET interp.osisaf.$CONFIG_SUFFIX land_map "icenet.data.masks.osisaf:Masks"

LOADER_CONFIGURATION="loader.${PROCESSED_DATASET}.json"
DATASET_NAME=`basename $( pwd )`"_${HEMI}"

pipeline_run icenet_dataset_create -v -c -p -l $LAG -ob $BATCH_SIZE -w $WORKERS -fl $FORECAST_LENGTH $LOADER_CONFIGURATION $DATASET_NAME

# For when we don't have the preceding data, make sure there's an offset. These will be dropped in generation
if [ $DRY == 0 ]; then
  LAG_DATE=${PLOT_DATE:-`cat ${LOADER_CONFIGURATION} | jq -r '.sources[.sources|keys[0]].splits.train[0]'`}
else
  OFFSET=""
  if [ $DATA_FREQUENCY == "month" ]; then
    OFFSET=" + 1 month - 1 day"
  fi
  LAG_DATE=`date --date="$( echo $TRAIN_START | awk -F'|' '{ print $1 }' ) + $( expr $LAG + 2 ) ${DATA_FREQUENCY}s $OFFSET" +%F`
fi
mkdir -p plots
pipeline_run icenet_plot_input -p -v dataset_config.${DATASET_NAME}.json ${LAG_DATE} ./plots/osisaf_input.${HEMI}.${LAG_DATE}.png
pipeline_run icenet_plot_input --outputs -v dataset_config.${DATASET_NAME}.json ${LAG_DATE} ./plots/osisaf_outputs.${HEMI}.${LAG_DATE}.png
pipeline_run icenet_plot_input --weights -v dataset_config.${DATASET_NAME}.json ${LAG_DATE} ./plots/osisaf_weights.${HEMI}.${LAG_DATE}.png

echo -n "To CACHE the dataset, please run: "
echo icenet_dataset_create -v -p -l $LAG -ob $BATCH_SIZE -w $WORKERS -fl $FORECAST_LENGTH $LOADER_CONFIGURATION $DATASET_NAME
