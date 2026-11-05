#!/usr/bin/bash -l

source ENVS
source scripts/pipeline_cmds.sh
conda activate $ICENET_CONDA

set -o pipefail
set -eu

HEMI="$1"
FORECAST_NAME="$2"
FORECAST_START=${3:-"2025-01-01"}
FORECAST_END=${4:-${FORECAST_START}}
DRY=${5:-0}

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

INPUT_START_DATE=$( date --date="${FORECAST_START} - `expr $LAG + 2` ${DATA_FREQUENCY}s" +%F )
INPUT_END_DATE=$( date --date="${FORECAST_END} - 1 ${DATA_FREQUENCY}s" +%F)

if [ $DATA_FREQUENCY == "month" ]; then
  # FIXME: This is horrible, use a non-bash method
  INPUT_END_DATE=$( date --date="${FORECAST_END} + 1 day" +%F )
  INPUT_END_DATE=$( date --date="${INPUT_END_DATE} - 1 month" +%F )
  INPUT_END_DATE=$( date --date="${INPUT_END_DATE} - 1 day" +%F )
fi

CONFIG_SUFFIX="${FORECAST_NAME}.${HEMI}.json"

DATASET_NAME=`basename $( pwd )`"_${HEMI}"
SOURCE_CONFIG_NAME="dataset_config.${DATASET_NAME}.json"

##
# TODO: Usable as is for training, but for prediction we need to restrict this to relevant activities and dates
#   ./run_prediction.sh fc.09_12.2024 amsr_6k_6m_120125.south south

# Forecast dates are the FIRST date of SIC you expect, so we download and prepare from t-1 onwards


# download-toolbox integration
# This updates our source
pipeline_run download_osisaf --config-path data.prediction.osisaf.${CONFIG_SUFFIX} $DATA_ARGS $HEMI $INPUT_START_DATE $INPUT_END_DATE $OSISAF_VAR_ARGS
pipeline_run download_cds -i era5 --config-path data.prediction.era5.${CONFIG_SUFFIX} $DATA_ARGS $HEMI $INPUT_START_DATE $INPUT_END_DATE $ERA5_VAR_ARGS
# Download ORAS5 prediction data (if available/needed)
# pipeline_run download_oras5 --config-path data.prediction.oras5.${CONFIG_SUFFIX} $DATA_ARGS $HEMI $INPUT_START_DATE $INPUT_END_DATE $ORAS5_VAR_ARGS
# Alternatively, while download not implemented, generate congif from contents of existing data archive.

# Only generate ORAS5 config if it doesn't exist (should exist from training)
if [ ! -f data.oras5.${DATA_FREQUENCY}.${HEMI}.json ]; then
  pipeline_run python scripts/generate_oras5_config.py --config-path data.oras5.${DATA_FREQUENCY}.${HEMI}.json --hemisphere $HEMI
fi

FORECAST_DATASET="prediction.${FORECAST_NAME}.${HEMI}"
LOADER_CONFIGURATION="loader.${FORECAST_DATASET}.json"

# Creates our LOADER_CONFIGURATION file
pipeline_run preprocess_loader_init -v $FORECAST_DATASET
pipeline_run preprocess_add_mask -v $FORECAST_DATASET data.prediction.osisaf.${CONFIG_SUFFIX} land "icenet.data.masks.osisaf:Masks"
pipeline_run preprocess_add_mask -v $FORECAST_DATASET data.prediction.osisaf.${CONFIG_SUFFIX} polarhole "icenet.data.masks.osisaf:Masks"
pipeline_run preprocess_add_mask -v $FORECAST_DATASET data.prediction.osisaf.${CONFIG_SUFFIX} active_grid_cell "icenet.data.masks.osisaf:Masks"

if [ ! -f ref.osisaf.${HEMI}.nc ]; then
  HEMI_SHORT="nh"
  [ $HEMI == "south" ] && HEMI_SHORT="sh"
  pipeline_run icenet_generate_ref_osisaf -v data/masks.osisaf/ice_conc_${HEMI_SHORT}_ease2-250_cdr-v2p0_200001021200.nc
fi

# ORAS5 regridding with ORCA grid support
pipeline_run preprocess_regrid -v \
  --coord-method preprocess_toolbox.dataset.orca_grid:orca_coord_processing \
  -c proc.prediction.oras5.${CONFIG_SUFFIX} \
  -sn "prediction" -ss $INPUT_START_DATE -se $INPUT_END_DATE -sh $MAX_LAG_SH \
  data.oras5.${DATA_FREQUENCY}.${HEMI}.json ref.osisaf.${HEMI}.nc ${FORECAST_NAME}.${HEMI}_oras5
# Optionalnot implemented: if using currents they need to be roatated
# pipeline_run preprocess_rotate -n uo,vo -v proc.prediction.oras5.${CONFIG_SUFFIX} ref.osisaf.${HEMI}.nc


pipeline_run preprocess_regrid -v \
  -c proc.prediction.era5.${CONFIG_SUFFIX} \
  -sn "prediction" -ss $INPUT_START_DATE -se $INPUT_END_DATE -sh $MAX_LAG_SH \
  data.prediction.era5.${CONFIG_SUFFIX} ref.osisaf.${HEMI}.nc ${FORECAST_NAME}.${HEMI}_era5
pipeline_run preprocess_rotate -n uas,vas -v proc.prediction.era5.${CONFIG_SUFFIX} ref.osisaf.${HEMI}.nc

pipeline_run preprocess_dataset $PROC_ARGS_ORAS5 -v \
  -r processed/${TRAIN_DATA_NAME}.${DATA_FREQUENCY}.${HEMI}_oras5 \
  -sn "prediction" -ss "$FORECAST_START" -se "$FORECAST_END" -sh $MAX_LAG_SH \
  -i "icenet.data.processors.cmems:ORAS5PreProcessor" \
  proc.prediction.oras5.${CONFIG_SUFFIX} ${FORECAST_NAME}.${HEMI}_oras5

pipeline_run preprocess_dataset $PROC_ARGS_ERA5 -v \
  -r processed/${TRAIN_DATA_NAME}.${DATA_FREQUENCY}.${HEMI}_era5 \
  -sn "prediction" -ss "$FORECAST_START" -se "$FORECAST_END" -sh $MAX_LAG_SH \
  -i "icenet.data.processors.cds:ERA5PreProcessor" \
  proc.prediction.era5.${CONFIG_SUFFIX} ${FORECAST_NAME}.${HEMI}_era5

pipeline_run preprocess_dataset $PROC_ARGS_SIC -v \
  -r processed/${TRAIN_DATA_NAME}.${DATA_FREQUENCY}.${HEMI}_osisaf \
  -sn "prediction" -ss "$FORECAST_START" -se "$FORECAST_END" -sh $MAX_LAG_SH \
  -i "icenet.data.processors.osisaf:SICPreProcessor" \
  data.prediction.osisaf.${CONFIG_SUFFIX} ${FORECAST_NAME}.${HEMI}_osisaf

#pipeline_run preprocess_add_processed -v $FORECAST_DATASET processed.${FORECAST_NAME}_osisaf.json processed.${FORECAST_NAME}_era5.json
pipeline_run preprocess_add_processed -v $FORECAST_DATASET processed.${FORECAST_NAME}.${HEMI}_osisaf.json processed.${FORECAST_NAME}.${HEMI}_era5.json processed.${FORECAST_NAME}.${HEMI}_oras5.json

pipeline_run preprocess_add_channel -v $FORECAST_DATASET data.prediction.osisaf.${CONFIG_SUFFIX} sin "icenet.data.meta:SinProcessor"
pipeline_run preprocess_add_channel -v $FORECAST_DATASET data.prediction.osisaf.${CONFIG_SUFFIX} cos "icenet.data.meta:CosProcessor"
pipeline_run preprocess_add_channel -v $FORECAST_DATASET data.prediction.osisaf.${CONFIG_SUFFIX} land_map "icenet.data.masks.osisaf:Masks"

pipeline_run icenet_dataset_create -v -c -p -l $LAG -ob $BATCH_SIZE -fl $FORECAST_LENGTH $LOADER_CONFIGURATION $FORECAST_DATASET

FIRST_DATE=${PLOT_DATE:-`cat ${LOADER_CONFIGURATION} | jq -r '.sources[.sources|keys[0]].splits.prediction[0]'`}
pipeline_run icenet_plot_input -p -v dataset_config.${FORECAST_DATASET}.json $FIRST_DATE ./plots/prediction_input.${HEMI}.${FIRST_DATE}.png

