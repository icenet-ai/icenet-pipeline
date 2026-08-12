#!/usr/bin/bash -l

OLD_PREFIX=$PREFIX
export PREFIX="RUN_OSI"
source ENVS
source scripts/pipeline_cmds.sh
conda activate $ICENET_CONDA

# We have to manually override the dates
export ERA5_DATES=$OSISAF_DATES

set -o pipefail
set -eu

if [ $# -lt 1 ] || [ "$1" == "-h" ]; then
    echo "Usage $0 <hemisphere> [download=0|1] [dry=0|1]"
    exit 1
fi

HEMI="$1"
SIC_TYPE="amsr2"
DOWNLOAD=${2:-0}
DRY=${3:-0}

PROCESSED_DATASET="pretrain.${DATA_FREQUENCY}.${HEMI}"
CONFIG_SUFFIX="${PROCESSED_DATASET}.json"
SIC_TRUTH_DATA="data.$SIC_TYPE"
HEMI_SHORT="nh"
[ $HEMI == "south" ] && HEMI_SHORT="sh"

if [ ! -f ${SIC_TRUTH_DATA}.${DATA_FREQUENCY}.${HEMI}.json ]; then
  echo "${SIC_TRUTH_DATA}.${DATA_FREQUENCY}.${HEMI}.json missing: this needs to be run AFTER you've prepared your main run data!"
  exit 1
fi

echo -e "\n=============================================\n"
OSISAF_DATA="data.osisaf"
OSISAF_PROC="proc.osisaf"
ERA5_DATA="data.era5"
ERA5_PROC="proc.era5"

LOADER_CONFIGURATION="loader.${PROCESSED_DATASET}.json"
DATASET_NAME=`basename $( pwd )`"_pretrain.${HEMI}"

# download-toolbox integration
# This updates our source
if [ $DOWNLOAD -eq 1 ]; then
  pipeline_run download_osisaf --config-path ${OSISAF_DATA}.${CONFIG_SUFFIX} $DATA_ARGS $HEMI $OSISAF_DATES $OSISAF_VAR_ARGS
  pipeline_run download_cds -i era5 --config-path ${ERA5_DATA}.${CONFIG_SUFFIX} $DATA_ARGS $HEMI $ERA5_DATES $ERA5_VAR_ARGS
fi

if [ ! -f $LOADER_CONFIGURATION ]; then
  pipeline_run preprocess_loader_init -v $PROCESSED_DATASET

  # TODO: do we use NSIDC or OSISAF masks? defaulting to OSISAF as it covers product gaps
  #   pipeline_run preprocess_add_mask -v $PROCESSED_DATASET $SIC_TRUTH_DATA.$CONFIG_SUFFIX land "icenet.data.masks.nsidc:Masks"
  pipeline_run preprocess_add_mask -v $PROCESSED_DATASET $OSISAF_DATA.$CONFIG_SUFFIX land "icenet.data.masks.osisaf:Masks"
  pipeline_run preprocess_add_mask -v $PROCESSED_DATASET $OSISAF_DATA.$CONFIG_SUFFIX polarhole "icenet.data.masks.osisaf:Masks"
  pipeline_run preprocess_add_mask -v $PROCESSED_DATASET $OSISAF_DATA.$CONFIG_SUFFIX active_grid_cell "icenet.data.masks.osisaf:Masks"

  if [ ! -f interp.osisaf.${CONFIG_SUFFIX} ]; then
    pipeline_run preprocess_missing_time \
      -ps "train" -sn "train" \
      -ss "$TRAIN_START" -se "$TRAIN_END" \
      -sh `expr $LAG + 1` -st $FORECAST_LENGTH \
      -c ./interp.osisaf.${CONFIG_SUFFIX} \
      -n siconca -v $OSISAF_DATA.$CONFIG_SUFFIX $OSISAF_PROC

    # FIXME: masks are not working for transfer learning
    pipeline_run preprocess_missing_spatial \
      -m processed.masks.osisaf.${HEMI}.json -mp land,inactive_grid_cell,polarhole \
      -n siconca -v interp.osisaf.${CONFIG_SUFFIX}
  fi

  if [ ! -f regrid.osisaf.${CONFIG_SUFFIX} ]; then
    pipeline_run preprocess_regrid -v -c ./regrid.osisaf.${CONFIG_SUFFIX} \
      -cp "icenet.data.processors.osisaf:amsr_coordinate_regrid" \
      -ca `ls data/osisaf/siconca/*/*${HEMI_SHORT}*.nc | head -n 1` \
      interp.osisaf.${CONFIG_SUFFIX} ref.${SIC_TYPE}.${HEMI}.nc ${PROCESSED_DATASET}_osisaf
  fi

  if [ ! -f processed.${PROCESSED_DATASET}_osisaf.json ]; then
    pipeline_run preprocess_dataset $PROC_ARGS_SIC -v \
      -ps "train" -sn "train" \
      -ss "$TRAIN_START" -se "$TRAIN_END" \
      -sh `expr $LAG + 1` -st $FORECAST_LENGTH \
      -i "icenet.data.processors.osisaf:SICPreProcessor" \
      -sh $LAG -st $FORECAST_LENGTH \
      regrid.osisaf.${CONFIG_SUFFIX} ${PROCESSED_DATASET}_osisaf
  fi

  if [ ! -f regrid.era5.${CONFIG_SUFFIX} ]; then
    # TODO: For OSISAF we are rotating the SIC dataset on it's axis, see GH#34
    pipeline_run preprocess_regrid -v -c ./regrid.era5.${CONFIG_SUFFIX} \
      -ps "train" -sn "train" \
      -ss "$TRAIN_START" -se "$TRAIN_END" \
      -sh `expr $LAG + 1` -st $FORECAST_LENGTH \
      $ERA5_DATA.$CONFIG_SUFFIX ref.amsr2.${HEMI}.nc $ERA5_PROC
  fi

  if [ ! -f processed.${PROCESSED_DATASET}_era5.json ]; then
    pipeline_run preprocess_dataset $PROC_ARGS_ERA5 -v \
      -ps "train" -sn "train" \
      -ss "$TRAIN_START" -se "$TRAIN_END" \
      -sh `expr $LAG + 1` -st $FORECAST_LENGTH \
      -i "icenet.data.processors.cds:ERA5PreProcessor" \
      regrid.era5.${CONFIG_SUFFIX} ${PROCESSED_DATASET}_era5
  fi

  pipeline_run preprocess_add_processed -v $PROCESSED_DATASET processed.${PROCESSED_DATASET}_osisaf.json processed.${PROCESSED_DATASET}_era5.json

  pipeline_run preprocess_add_channel -v $PROCESSED_DATASET regrid.osisaf.${CONFIG_SUFFIX} sin "icenet.data.meta:SinProcessor"
  pipeline_run preprocess_add_channel -v $PROCESSED_DATASET regrid.osisaf.${CONFIG_SUFFIX} cos "icenet.data.meta:CosProcessor"
  pipeline_run preprocess_add_channel -v $PROCESSED_DATASET regrid.osisaf.${CONFIG_SUFFIX} land_map "icenet.data.masks.osisaf:Masks"

  pipeline_run icenet_regrid_osisaf_masks -v ref.amsr2.${HEMI}.nc processed/masks.osisaf.${HEMI} `ls data/osisaf/siconca/*/*${HEMI_SHORT}*.nc | head -n 1`
fi

pipeline_run icenet_dataset_create -v -c -p -ob $BATCH_SIZE -w $WORKERS -fl $FORECAST_LENGTH $LOADER_CONFIGURATION $DATASET_NAME

if [ ! $DRY ] || [ -f $LOADER_CONFIGURATION ]; then
  LAG_DATE=${PLOT_DATE:-`cat ${LOADER_CONFIGURATION} | jq '.sources[.sources|keys[0]].splits.train[0]' | tr -d '"'`}
else
  OFFSET=""
  if [ $DATA_FREQUENCY == "month" ]; then
    OFFSET=" + 1 month - 1 day"
  fi
  LAG_DATE=`date --date="$( echo $TRAIN_START | awk -F'|' '{ print $1 }' ) + $( expr $LAG + 1 ) ${DATA_FREQUENCY}s $OFFSET" +%F`
fi
mkdir -p plots
pipeline_run icenet_plot_input -p -v dataset_config.${DATASET_NAME}.json $LAG_DATE ./plots/input.pretrain.${HEMI}.${LAG_DATE}.png
pipeline_run icenet_plot_input --outputs -v dataset_config.${DATASET_NAME}.json $LAG_DATE ./plots/outputs.pretrain.${HEMI}.${LAG_DATE}.png
pipeline_run icenet_plot_input --weights -v dataset_config.${DATASET_NAME}.json $LAG_DATE ./plots/weights.pretrain.${HEMI}.${LAG_DATE}.png

echo -n "To CACHE the dataset, please run: "
echo icenet_dataset_create -v -p -l $LAG -ob $BATCH_SIZE -w $WORKERS -fl $FORECAST_LENGTH $LOADER_CONFIGURATION $DATASET_NAME

# TODO: here is where we nick the val and test splits from the ground truth
#  datasets prepared in the alternative script. icenet_train can then be used
#  with MultiLoaderDataSet or whatever I called it, to pretrain the model
#  prior to the full run (TODO 2: this will need adapting to the OSI -> AMSR recipe)

unset PREFIX
export PREFIX=$OLD_PREFIX

if [ ! ${DRY:+1} ] || [ $DRY -eq 0 ]; then
  source ENVS

  # 1. Copy dataset_config.monthly.cmip_osi_north.json, with referred loader configuration
  GROUND_TRUTH_DATASET="dataset_config.`basename $( pwd )`_${HEMI}.json"
  # We can copy it from the monthly.amsr runs, so check
  if [ ! -f $GROUND_TRUTH_DATASET ]; then
    GROUND_TRUTH_DATASET="dataset_config.monthly.amsr_${HEMI}.json"
  fi
  GROUND_TRUTH_LOADER=`pwd .`/$( basename `jq -r '.loader_config' $GROUND_TRUTH_DATASET` )
  PRETRAIN_DATASET="dataset_config.pretrain_eval.`basename $( pwd )`_${HEMI}.json"
  PRETRAIN_LOADER="loader.pretrain.${PREFIX,,}.${DATA_FREQUENCY}.${HEMI}.json"

  jq --arg loader `realpath $PRETRAIN_LOADER` '.loader_config=$loader | .counts.train = 0' $GROUND_TRUTH_DATASET > $PRETRAIN_DATASET

  # 2. Strip out the split train dates from ground truth loader configuration

  jq '.sources[].splits.train = [] | .sources[].source_files.train = []' $GROUND_TRUTH_LOADER > $PRETRAIN_LOADER

  # 3. TEST with icenet_train
fi