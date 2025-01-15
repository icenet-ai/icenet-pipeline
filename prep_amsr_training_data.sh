HEMI="$1"
DOWNLOAD=${2:-0}

source ENVS

##
# TODO: Usable as is for training, but for prediction we need to restrict this to relevant activities and dates
#   ./run_prediction.sh amsr_fc.09_12.2024 amsr_6k_6m_120125.south south

# download-toolbox integration
# This updates our source
if [ $DOWNLOAD -eq 1 ]; then
  download_amsr2 $DATA_ARGS $HEMI $AMSR2_DATES $AMSR2_VAR_ARGS
  download_osisaf $DATA_ARGS $HEMI $OSISAF_DATES $OSISAF_VAR_ARGS
  download_era5 $DATA_ARGS $HEMI $ERA5_DATES $ERA5_VAR_ARGS
  download_cmip --source MRI-ESM2-0 --member r1i1p1f1 $DATA_ARGS $HEMI $CMIP6_DATES $CMIP6_VAR_ARGS
fi 2>&1 | tee logs/download.training.log

DATASET_CONFIG_NAME="dataset_config.${DATA_FREQUENCY}.hemi.${HEMI}.json"

# preprocess-toolbox integration
# Persistent datasets from the source data store, wherever that is
AMSR2_DATASET="${SOURCE_DATA_STORE}/amsr2_6250/${DATASET_CONFIG_NAME}"
CMIP6_DATASET="${SOURCE_DATA_STORE}/cmip6.MRI-ESM2-0.r1i1p1f1/${DATASET_CONFIG_NAME}"
ERA5_DATASET="${SOURCE_DATA_STORE}/era5/${DATASET_CONFIG_NAME}"
OSISAF_DATASET="${SOURCE_DATA_STORE}/osisaf/${DATASET_CONFIG_NAME}"

# Create links to the central data store datasets for easier "mapping"
[ ! -e data/amsr2_6250 ] && [ -d ${SOURCE_DATA_STORE}/amsr2_6250 ] && ln -s ${SOURCE_DATA_STORE}/amsr2_6250 ./data/amsr2_6250
[ ! -e data/era5 ] && [ -d ${SOURCE_DATA_STORE}/era5 ] && ln -s ${SOURCE_DATA_STORE}/era5 ./data/era5
[ ! -e data/cmip6.MRI-ESM2-0.r1i1p1f1 ] && [ -d ${SOURCE_DATA_STORE}/cmip6.MRI-ESM2-0.r1i1p1f1 ] && ln -s ${SOURCE_DATA_STORE}/cmip6.MRI-ESM2-0.r1i1p1f1 ./data/cmip6.MRI-ESM2-0.r1i1p1f1
[ ! -e data/osisaf ] && [ -d ${SOURCE_DATA_STORE}/osisaf ] && ln -s ${SOURCE_DATA_STORE}/osisaf ./data/osisaf

PROCESSED_DATASET="${TRAIN_DATA_NAME}.${HEMI}"
LOADER_CONFIGURATION="loader.${PROCESSED_DATASET}.json"
DATASET_NAME="tfamsr_${HEMI}"

ATMOS_PROC="era5_amsr.$TRAIN_DATA_NAME"
ATMOS_PROC_DSC="${PROCESSED_DATA_STORE}/${ATMOS_PROC}/${DATASET_CONFIG_NAME}"
GROUND_TRUTH_SIC="amsr2_sic.$TRAIN_DATA_NAME"
GROUND_TRUTH_SIC_DSC="${PROCESSED_DATA_STORE}/${GROUND_TRUTH_SIC}/${DATASET_CONFIG_NAME}"

###
# Three stage training
#

##
# Stage #1: CMIP6 ground truth with ERA5
#

##
# Stage #2: OSISAF ground truth with ERA5
#

##
# Stage #3: AMSR2 ground truth with ERA5
#

preprocess_loader_init -v $PROCESSED_DATASET
preprocess_add_mask -v $LOADER_CONFIGURATION $AMSR2_DATASET land "icenet.data.masks.nsidc:Masks"

preprocess_missing_time -n siconca -v $AMSR2_DATASET $GROUND_TRUTH_SIC

preprocess_dataset $PROC_ARGS_SIC -v \
  -ps "train" -sn "train,val,test" -ss "$TRAIN_START,$VAL_START,$TEST_START" -se "$TRAIN_END,$VAL_END,$TEST_END" \
  -i "icenet.data.processors.amsr:AMSR2PreProcessor" \
  -sh $LAG -st $FORECAST_LENGTH \
  $AMSR2_DATASET ${PROCESSED_DATASET}_amsr

# IS THIS NEEDED? icenet_generate_ref_amsr -v ${PROCESSED_DATA_STORE}/masks/ice_conc_${HEMI_SHORT}_ease2-250_cdr-v2p0_200001021200.nc
[ ! -f ref.amsr.${HEMI}.nc ] && ln -s data/amsr2_6250/siconca/2014/asi-AMSR2-s6250-20140630-v5.4.nc ref.amsr.${HEMI}.nc

preprocess_regrid -v \
  -ps "train" -sn "train,val,test" -ss "$TRAIN_START,$VAL_START,$TEST_START" -se "$TRAIN_END,$VAL_END,$TEST_END" \
  $ERA5_DATASET ref.amsr.${HEMI}.nc $ATMOS_PROC

preprocess_dataset $PROC_ARGS_ERA5 -v \
  -ps "train" -sn "train,val,test" -ss "$TRAIN_START,$VAL_START,$TEST_START" -se "$TRAIN_END,$VAL_END,$TEST_END" \
  -i "icenet.data.processors.cds:ERA5PreProcessor" \
  -sh $LAG -st $FORECAST_LENGTH \
  $ATMOS_PROC_DSC ${PROCESSED_DATASET}_era5

preprocess_add_processed -v $LOADER_CONFIGURATION processed.${PROCESSED_DATASET}_amsr.json processed.${PROCESSED_DATASET}_era5.json

preprocess_add_channel -v $LOADER_CONFIGURATION $GROUND_TRUTH_SIC_DSC sin "icenet.data.meta:SinProcessor"
preprocess_add_channel -v $LOADER_CONFIGURATION $GROUND_TRUTH_SIC_DSC cos "icenet.data.meta:CosProcessor"
preprocess_add_channel -v $LOADER_CONFIGURATION $GROUND_TRUTH_SIC_DSC land_map "icenet.data.masks.nsidc:Masks"

icenet_dataset_create -v -c -p -ob $BATCH_SIZE -w $WORKERS -fl $FORECAST_LENGTH $LOADER_CONFIGURATION $DATASET_NAME

FIRST_DATE=${PLOT_DATE:-`cat ${LOADER_CONFIGURATION} | jq '.sources[.sources|keys[0]].splits.train[0]' | tr -d '"'`}
icenet_plot_input -p -v dataset_config.${DATASET_NAME}.json $FIRST_DATE ./plot/input.${HEMI}.${FIRST_DATE}.png
icenet_plot_input --outputs -v dataset_config.${DATASET_NAME}.json $FIRST_DATE ./plot/outputs.${HEMI}.${FIRST_DATE}.png
icenet_plot_input --weights -v dataset_config.${DATASET_NAME}.json $FIRST_DATE ./plot/weights.${HEMI}.${FIRST_DATE}.png

icenet_dataset_create -v -p -ob $BATCH_SIZE -w $WORKERS -fl $FORECAST_LENGTH $LOADER_CONFIGURATION $DATASET_NAME
