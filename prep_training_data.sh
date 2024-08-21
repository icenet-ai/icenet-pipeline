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
fi 2>&1 | tee logs/download.log

DATASET_CONFIG_NAME="dataset_config.${DATA_FREQUENCY}.hemi.${HEMI}.json"

# preprocess-toolbox integration
# Persistent datasets from the source data store, wherever that is
OSISAF_DATASET="${SOURCE_DATA_STORE}/osisaf/${DATASET_CONFIG_NAME}"
ERA5_DATASET="${SOURCE_DATA_STORE}/era5/${DATASET_CONFIG_NAME}"

# Create links to the central data store datasets for easier "mapping"
[ ! -e data/osisaf ] && [ -d ${SOURCE_DATA_STORE}/osisaf ] && ln -s ${SOURCE_DATA_STORE}/osisaf ./data/osisaf
[ ! -e data/era5 ] && [ -d ${SOURCE_DATA_STORE}/era5 ] && ln -s ${SOURCE_DATA_STORE}/era5 ./data/era5
# TODO: AMSR
# TODO: CMIP

GROUND_TRUTH_SIC="osi_sic"
ATMOS_PROC="era5_osi"

# Our processed dataset configurations, we localise data when regridding and reprojecting
GROUND_TRUTH_SIC_DSC="data/${GROUND_TRUTH_SIC}/${DATASET_CONFIG_NAME}"
ATMOS_PROC_DSC="data/${ATMOS_PROC}/${DATASET_CONFIG_NAME}"

PROCESSED_DATASET="training"
LOADER_CONFIGURATION="loader.${PROCESSED_DATASET}.json"
DATASET_NAME="tfdata_cache"

## Workflow
preprocess_loader_init -v $PROCESSED_DATASET

preprocess_add_mask -v $LOADER_CONFIGURATION $OSISAF_DATASET land "icenet.data.masks.osisaf:Masks"
  # TODO: masks is not compatible with dual hemisphere in this form!
preprocess_add_mask -v $LOADER_CONFIGURATION $OSISAF_DATASET polarhole "icenet.data.masks.osisaf:Masks"
preprocess_add_mask -v $LOADER_CONFIGURATION $OSISAF_DATASET active_grid_cell "icenet.data.masks.osisaf:Masks"

preprocess_missing_time -n siconca -v $OSISAF_DATASET $GROUND_TRUTH_SIC
  # TODO: didn't seemingly detect missing months? data/osi_sic/month/hemi.north/siconca.missing_days.csv
  # TODO: undoubtedly need to include the known invalid dates - added these to the osisaf downloader
preprocess_missing_spatial -m processed.masks.json -mp land,active_grid_cell,polarhole -n siconca -v $GROUND_TRUTH_SIC_DSC
  # TODO: Interpolation failing in all cases?
  # TODO: this undoubtedly explains the stray nans present in dataset generation

preprocess_dataset $PROC_ARGS_SIC -v \
  -ps "train" -sn "train,val,test" -ss "$TRAIN_START,$VAL_START,$TEST_START" -se "$TRAIN_END,$VAL_END,$TEST_END" \
  -i "icenet.data.processors.osisaf:SICPreProcessor" \
  $GROUND_TRUTH_SIC_DSC ${PROCESSED_DATASET}_osisaf
  # TODO: plenty of nans contained in here due to failing spatial interpolation - needs investigation

# TODO: icenet_osisaf_ref for geospatial metadata -v data/osisaf/hemi.north/siconca/???.nc ref.osisaf.north.nc
#  this needs to:
#  - ds = xr.open_dataset("./data/osisaf/month/hemi.north/siconca/1978.nc")
#  - ds = ds.drop_vars(["raw_ice_conc_values", "smearing_standard_error", "algorithm_standard_error"])
#  - cube = ds.siconca.to_iris()
#  - cube.coord('projection_x_coordinate').convert_units('meters')
#  - cube.coord('projection_y_coordinate').convert_units('meters')
#  - iris.save("ref.osisaf.nc")

preprocess_regrid -v $ERA5_DATASET ref.osisaf.nc $ATMOS_PROC
  # TODO: get the batcher back in place for multiprocessing this
  # TODO: this should regrid ALL files in the dataset, for some reason 2024.nc did not get wrapped in
preprocess_rotate -n uas,vas -v $ATMOS_PROC_DSC ref.osisaf.nc
  # TODO: get the batcher back in place for multiprocessing this

preprocess_dataset $PROC_ARGS_ERA5 -v \
  -ps "train" -sn "train,val,test" -ss "$TRAIN_START,$VAL_START,$TEST_START" -se "$TRAIN_END,$VAL_END,$TEST_END" \
  -i "icenet.data.processors.cds:ERA5PreProcessor" \
  $ATMOS_PROC_DSC ${PROCESSED_DATASET}_era5
  # TODO: naive copy of "./data/era5_osi/month/hemi.north/uas/2024.nc" earlier is not regridded?
  # TODO: dask multiprocessing cluster with task batcher across multiple variables would be sensible

preprocess_add_processed -v $LOADER_CONFIGURATION processed.${PROCESSED_DATASET}_osisaf.json processed.${PROCESSED_DATASET}_era5.json

preprocess_add_channel -v $LOADER_CONFIGURATION $GROUND_TRUTH_SIC_DSC sin "icenet.data.meta:SinProcessor"
preprocess_add_channel -v $LOADER_CONFIGURATION $GROUND_TRUTH_SIC_DSC cos "icenet.data.meta:CosProcessor"
preprocess_add_channel -v $LOADER_CONFIGURATION $GROUND_TRUTH_SIC_DSC land_map "icenet.data.masks.osisaf:Masks"

icenet_dataset_create -v -c -p -ob $BATCH_SIZE -w $WORKERS -fl $FORECAST_LENGTH $LOADER_CONFIGURATION $DATASET_NAME

# TODO: select a random date from the training set, plot and log so user can double check outputs
icenet_plot_input -p -v dataset_config.${DATASET_NAME}.json 1985-04-30 ./plot/input.png
icenet_plot_input --outputs -v dataset_config.${DATASET_NAME}.json 1985-04-30 ./plot/outputs.png
icenet_plot_input --weights -v dataset_config.${DATASET_NAME}.json 1985-04-30 ./plot/weights.png

icenet_dataset_create -v -p -ob $BATCH_SIZE -w $WORKERS -fl $FORECAST_LENGTH $LOADER_CONFIGURATION $DATASET_NAME
  # TODO: FIXME in here to override the creation of nan containing sets due to earlier issues


# icenet_train_tensorflow -b 1 -e 5 -f 1 -n 0.2 -nw -v dataset_config.${DATASET_NAME}.json test_network 42
# run_train_ensemble