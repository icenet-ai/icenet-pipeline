#!/bin/bash -l

source ENVS
conda activate $ICENET_CONDA

set -o pipefail
set -eu

if [ $# -lt 1 ] || [ "$1" == "-h" ]; then
    echo "Usage $0 <hemisphere> [download=0|1]"
    exit 1
fi

HEMI="$1"
DOWNLOAD=${2:-0}

# download-toolbox integration
# This updates our source
if [ $DOWNLOAD -eq 1 ]; then
  # download_amsr2 $DATA_ARGS $HEMI $AMSR2_DATES $AMSR2_VAR_ARGS
  download_osisaf $DATA_ARGS $HEMI $OSISAF_DATES $OSISAF_VAR_ARGS
  download_era5 $DATA_ARGS $HEMI $ERA5_DATES $ERA5_VAR_ARGS
  # download_cmip --source MRI-ESM2-0 --member r1i1p1f1 $DATA_ARGS $HEMI $CMIP6_DATES $CMIP6_VAR_ARGS
fi 2>&1 | tee logs/download.training.log

DATASET_CONFIG_NAME="dataset_config.${DATA_FREQUENCY}.hemi.${HEMI}.json"

# preprocess-toolbox integration
# Persistent datasets from the source data store, wherever that is
OSISAF_DATASET="${SOURCE_DATA_STORE}/osisaf/${DATASET_CONFIG_NAME}"
ERA5_DATASET="${SOURCE_DATA_STORE}/era5/${DATASET_CONFIG_NAME}"

# Create links to the central data store datasets for easier "mapping"
[ ! -e data/osisaf ] && [ -d ${SOURCE_DATA_STORE}/osisaf ] && ln -s ${SOURCE_DATA_STORE}/osisaf ./data/osisaf
[ ! -e data/era5 ] && [ -d ${SOURCE_DATA_STORE}/era5 ] && ln -s ${SOURCE_DATA_STORE}/era5 ./data/era5

GROUND_TRUTH_SIC="osi_sic.$TRAIN_DATA_NAME"
ATMOS_PROC="era5_osi.$TRAIN_DATA_NAME"

# Our processed dataset configurations, we localise data when regridding and reprojecting
GROUND_TRUTH_SIC_DSC="${PROCESSED_DATA_STORE}/${GROUND_TRUTH_SIC}/${DATASET_CONFIG_NAME}"
ATMOS_PROC_DSC="${PROCESSED_DATA_STORE}/${ATMOS_PROC}/${DATASET_CONFIG_NAME}"

PROCESSED_DATASET="${TRAIN_DATA_NAME}.${HEMI}"
LOADER_CONFIGURATION="loader.${PROCESSED_DATASET}.json"
DATASET_NAME="tfdata_${HEMI}"

## Workflow
preprocess_loader_init -v $PROCESSED_DATASET

# We CAN supply splits and lead / lag to prevent unnecessarily large copies of datasets
# or interpolation of time across huge spans
# TODO: temporal interpolation limiting
preprocess_missing_time \
#  -ps "train" -sn "train,val,test" -ss "$TRAIN_START,$VAL_START,$TEST_START" -se "$TRAIN_END,$VAL_END,$TEST_END" \
#  -sh $LAG -st $FORECAST_LENGTH \
  -n siconca -v $OSISAF_DATASET $GROUND_TRUTH_SIC

preprocess_add_mask -v $LOADER_CONFIGURATION $GROUND_TRUTH_SIC_DSC land "icenet.data.masks.osisaf:Masks"
preprocess_add_mask -v $LOADER_CONFIGURATION $GROUND_TRUTH_SIC_DSC polarhole "icenet.data.masks.osisaf:Masks"
preprocess_add_mask -v $LOADER_CONFIGURATION $GROUND_TRUTH_SIC_DSC active_grid_cell "icenet.data.masks.osisaf:Masks"

preprocess_missing_spatial \
  -m processed.masks.${HEMI}.json -mp land,inactive_grid_cell,polarhole -n siconca -v $GROUND_TRUTH_SIC_DSC

preprocess_dataset $PROC_ARGS_SIC -v \
  -ps "train" -sn "train,val,test" -ss "$TRAIN_START,$VAL_START,$TEST_START" -se "$TRAIN_END,$VAL_END,$TEST_END" \
  -i "icenet.data.processors.osisaf:SICPreProcessor" \
  -sh $LAG -st $FORECAST_LENGTH \
  $GROUND_TRUTH_SIC_DSC ${PROCESSED_DATASET}_osisaf

HEMI_SHORT="nh"
[ $HEMI == "south" ] && HEMI_SHORT="sh"

icenet_generate_ref_osisaf -v ${PROCESSED_DATA_STORE}/masks/ice_conc_${HEMI_SHORT}_ease2-250_cdr-v2p0_200001021200.nc

preprocess_regrid -v $ERA5_DATASET ref.osisaf.${HEMI}.nc $ATMOS_PROC
preprocess_rotate -n uas,vas -v $ATMOS_PROC_DSC ref.osisaf.${HEMI}.nc

preprocess_dataset $PROC_ARGS_ERA5 -v \
  -ps "train" -sn "train,val,test" -ss "$TRAIN_START,$VAL_START,$TEST_START" -se "$TRAIN_END,$VAL_END,$TEST_END" \
  -i "icenet.data.processors.cds:ERA5PreProcessor" \
  -sh $LAG -st $FORECAST_LENGTH \
  $ATMOS_PROC_DSC ${PROCESSED_DATASET}_era5

preprocess_add_processed -v $LOADER_CONFIGURATION processed.${PROCESSED_DATASET}_osisaf.json processed.${PROCESSED_DATASET}_era5.json

preprocess_add_channel -v $LOADER_CONFIGURATION $GROUND_TRUTH_SIC_DSC sin "icenet.data.meta:SinProcessor"
preprocess_add_channel -v $LOADER_CONFIGURATION $GROUND_TRUTH_SIC_DSC cos "icenet.data.meta:CosProcessor"
preprocess_add_channel -v $LOADER_CONFIGURATION $GROUND_TRUTH_SIC_DSC land_map "icenet.data.masks.osisaf:Masks"

icenet_dataset_create -v -c -p -ob $BATCH_SIZE -w $WORKERS -fl $FORECAST_LENGTH $LOADER_CONFIGURATION $DATASET_NAME

FIRST_DATE=${PLOT_DATE:-`cat ${LOADER_CONFIGURATION} | jq '.sources[.sources|keys[0]].splits.train[0]' | tr -d '"'`}
icenet_plot_input -p -v dataset_config.${DATASET_NAME}.json $FIRST_DATE ./plot/input.${HEMI}.${FIRST_DATE}.png
icenet_plot_input --outputs -v dataset_config.${DATASET_NAME}.json $FIRST_DATE ./plot/outputs.${HEMI}.${FIRST_DATE}.png
icenet_plot_input --weights -v dataset_config.${DATASET_NAME}.json $FIRST_DATE ./plot/weights.${HEMI}.${FIRST_DATE}.png

icenet_dataset_create -v -p -ob $BATCH_SIZE -w $WORKERS -fl $FORECAST_LENGTH $LOADER_CONFIGURATION $DATASET_NAME
