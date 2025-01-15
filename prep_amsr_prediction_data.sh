HEMI="$1"
DOWNLOAD=${2:-0}

source ENVS

##
# TODO: Usable as is for training, but for prediction we need to restrict this to relevant activities and dates
#   ./run_prediction.sh fc.09_12.2024 amsr_6k_6m_120125.south south

# TODO: assuming monthly?
# TODO: shift the FORECAST_START into the past for LAG
export FORECAST_START="2024-09-01"
export FORECAST_END="2024-12-31"
export HEMI=south
export FORECAST_NAME="fc.09_12.2024"

# download-toolbox integration
# This updates our source
if [ $DOWNLOAD -eq 1 ]; then
  download_amsr2 $DATA_ARGS $HEMI $FORECAST_START $FORECAST_END $AMSR2_VAR_ARGS
  download_era5 $DATA_ARGS $HEMI $FORECAST_START $FORECAST_END $ERA5_VAR_ARGS
fi 2>&1 | tee logs/download.prediction.log

SOURCE_CONFIG_NAME="dataset_config.${DATA_FREQUENCY}.hemi.${HEMI}.json"

AMSR2_DATASET="${SOURCE_DATA_STORE}/amsr2_6250/${SOURCE_CONFIG_NAME}"
ERA5_DATASET="${SOURCE_DATA_STORE}/era5/${SOURCE_CONFIG_NAME}"
AMSR2_PROCESSED="processed.${TRAIN_DATA_NAME}.${HEMI}_amsr.json"
ERA5_PROCESSED="processed.${TRAIN_DATA_NAME}.${HEMI}_era5.json"

# preprocess-toolbox integration
# Persistent datasets from the source data store, wherever that is
FORECAST_DATASET="prediction.${FORECAST_NAME}.${HEMI}"
LOADER_CONFIGURATION="loader.${FORECAST_DATASET}.json"

ATMOS_PROC="${TRAIN_DATA_NAME}.${HEMI}_era5"
ATMOS_PROC_DIR="processed/${ATMOS_PROC}"
GROUND_TRUTH_SIC="${TRAIN_DATA_NAME}.${HEMI}_amsr"
GROUND_TRUTH_SIC_DIR="processed/${GROUND_TRUTH_SIC}"


preprocess_loader_init -v $FORECAST_DATASET
preprocess_add_mask -v $LOADER_CONFIGURATION $AMSR2_DATASET land "icenet.data.masks.nsidc:Masks"

preprocess_dataset $PROC_ARGS_SIC -v \
  -r $GROUND_TRUTH_SIC_DIR \
  -sn "prediction" -ss "$FORECAST_START" -se "$FORECAST_END" \
  -i "icenet.data.processors.amsr:AMSR2PreProcessor" \
  -sh $LAG \
  $AMSR2_DATASET ${FORECAST_NAME}_amsr

preprocess_regrid -v \
  -sn "prediction" -ss "$FORECAST_START" -se "$FORECAST_END" \
  $ERA5_DATASET ref.amsr.${HEMI}.nc ${FORECAST_NAME}_era5

preprocess_dataset $PROC_ARGS_ERA5 -v \
  -r $ATMOS_PROC_DIR \
  -sn "prediction" -ss "$FORECAST_START" -se "$FORECAST_END" \
  -i "icenet.data.processors.cds:ERA5PreProcessor" \
  -sh $LAG \
  ${PROCESSED_DATA_STORE}/${FORECAST_NAME}_era5/${SOURCE_CONFIG_NAME} ${FORECAST_NAME}_era5

preprocess_add_processed -v $LOADER_CONFIGURATION processed.${FORECAST_NAME}_amsr.json processed.${FORECAST_NAME}_era5.json

preprocess_add_channel -v $LOADER_CONFIGURATION $AMSR2_DATASET sin "icenet.data.meta:SinProcessor"
preprocess_add_channel -v $LOADER_CONFIGURATION $AMSR2_DATASET cos "icenet.data.meta:CosProcessor"
preprocess_add_channel -v $LOADER_CONFIGURATION $AMSR2_DATASET land_map "icenet.data.masks.nsidc:Masks"

icenet_dataset_create -v -c -p -ob $BATCH_SIZE -w $WORKERS -fl $FORECAST_LENGTH $LOADER_CONFIGURATION $FORECAST_DATASET

FIRST_DATE=${PLOT_DATE:-`cat ${LOADER_CONFIGURATION} | jq '.sources[.sources|keys[0]].splits.prediction[0]' | tr -d '"'`}
icenet_plot_input -p -v dataset_config.${FORECAST_DATASET}.json $FIRST_DATE ./plot/input.${HEMI}.${FIRST_DATE}.png

