#!/usr/bin/bash -l

OLD_PREFIX=$PREFIX
export PREFIX="PRETRAIN_CMIP"
source ENVS
source scripts/pipeline_cmds.sh
conda activate $ICENET_CONDA

set -o pipefail
set -eu

if [ $# -lt 2 ] || [ "$1" == "-h" ]; then
    echo "Usage $0 <hemisphere> [osisaf|amsr2] [download=0|1] [dry=0|1]"
    exit 1
fi

HEMI="$1"
SIC_TYPE="$2"
SIC_TYPE=${SIC_TYPE,,}  # Make sure we're lowercase
DOWNLOAD=${3:-0}
DRY=${4:-0}

# This is particularly useful for CMIP transfer, so that we can seed data in one lump
PROCESSING=${PROCESSING:-1}

CONFIG_SUFFIX="${DATA_FREQUENCY}.${HEMI}.json"
SIC_TRUTH_DATA="data.$SIC_TYPE"

if [ ! -f ${SIC_TRUTH_DATA}.${CONFIG_SUFFIX} ]; then
  echo "This needs to be run AFTER you've prepared your main run data!"
  exit 1
fi

for SOURCE in ${!CMIP6_SOURCES[@]}; do
  for MEMBER in ${CMIP6_SOURCES[$SOURCE]}; do
    CMIP_ID="cmip_${SIC_TYPE}.${SOURCE}.${MEMBER}"
    CMIP_DATA="data.$CMIP_ID"
    CMIP_PROC="proc.$CMIP_ID"
    PROCESSED_DATASET="pretrain.${CMIP_ID}.${DATA_FREQUENCY}.${HEMI}"
    LOADER_CONFIGURATION="loader.${PROCESSED_DATASET}.json"
    DATASET_NAME=`basename $( pwd )`"_pretrain.${CMIP_ID}.${HEMI}"

    [ -f dataset_config.${DATASET_NAME}.json ] && continue

    echo -e "\n=============================================\n"

    # download-toolbox integration
    # This updates our source
    if [ $DOWNLOAD -eq 1 ]; then
      echo "SOURCE: $SOURCE - MEMBER: $MEMBER"
      if [ ! -f ${CMIP_DATA}.${CONFIG_SUFFIX} ]; then
        pipeline_run download_cmip --config-path ${CMIP_DATA}.${CONFIG_SUFFIX} $DATA_ARGS --source $SOURCE --member $MEMBER $HEMI $CMIP6_DATES $CMIP6_VAR_ARGS $CMIP6_SEARCH_NODE $CMIP6_EXCLUDE_NODES 2>&1 | tee logs/download.cmip_${HEMI}.${SOURCE}.${MEMBER}.log
      fi
    fi

    # A hack to get the downloads done, if this is set in the environment don't process
    [ $PROCESSING -eq 0 ] && continue

    # Overriding the experiments that don't present ssp245 data
    if [ "$SOURCE" == "MRI-ESM2-0" ] && [ "$MEMBER" != "r1i1p1f1" ]; then
      TRAIN_END="2014-12-31"
    fi

    if [ ! -f $LOADER_CONFIGURATION ]; then
      pipeline_run preprocess_loader_init -v $PROCESSED_DATASET

      if [ $SIC_TYPE == "osisaf" ]; then
        pipeline_run preprocess_add_mask -v $PROCESSED_DATASET $SIC_TRUTH_DATA.$CONFIG_SUFFIX land "icenet.data.masks.osisaf:Masks"
        pipeline_run preprocess_add_mask -v $PROCESSED_DATASET $SIC_TRUTH_DATA.$CONFIG_SUFFIX polarhole "icenet.data.masks.osisaf:Masks"
        pipeline_run preprocess_add_mask -v $PROCESSED_DATASET $SIC_TRUTH_DATA.$CONFIG_SUFFIX active_grid_cell "icenet.data.masks.osisaf:Masks"
      elif [ $SIC_TYPE == "amsr2" ]; then
        pipeline_run preprocess_add_mask -v $PROCESSED_DATASET $SIC_TRUTH_DATA.$CONFIG_SUFFIX land "icenet.data.masks.nsidc:Masks"
      fi

      if [ ! -f regrid.$CMIP_DATA.$CONFIG_SUFFIX ]; then
        pipeline_run preprocess_regrid -v -c ./regrid.$CMIP_DATA.$CONFIG_SUFFIX \
          -ps "train" -sn "train" \
          -ss "$TRAIN_START" -se "$TRAIN_END" \
          -sh `expr $LAG + 1` -st $FORECAST_LENGTH \
          $CMIP_DATA.$CONFIG_SUFFIX ref.${SIC_TYPE}.${HEMI}.nc $CMIP_PROC
      fi

      if [ ! -f processed.${PROCESSED_DATASET}_${CMIP_DATA}.json ]; then
        pipeline_run preprocess_dataset $PROC_ARGS_CMIP -v \
          -ps "train" -sn "train" \
          -ss "$TRAIN_START" -se "$TRAIN_END" \
          -sh `expr $LAG + 1` -st $FORECAST_LENGTH \
          -i "icenet.data.processors.cmip:CMIP6PreProcessor" \
          regrid.$CMIP_DATA.$CONFIG_SUFFIX ${PROCESSED_DATASET}_${CMIP_DATA}
      fi

      pipeline_run preprocess_add_processed -v $PROCESSED_DATASET processed.${PROCESSED_DATASET}_${CMIP_DATA}.json

      pipeline_run preprocess_add_channel -v $PROCESSED_DATASET regrid.${CMIP_DATA}.${CONFIG_SUFFIX} sin "icenet.data.meta:SinProcessor"
      pipeline_run preprocess_add_channel -v $PROCESSED_DATASET regrid.${CMIP_DATA}.${CONFIG_SUFFIX} cos "icenet.data.meta:CosProcessor"

      if [ $SIC_TYPE == "osisaf" ]; then
        pipeline_run preprocess_add_channel -v $PROCESSED_DATASET regrid.${CMIP_DATA}.${CONFIG_SUFFIX} land_map "icenet.data.masks.osisaf:Masks"
      elif [ $SIC_TYPE == "amsr2" ]; then
        pipeline_run preprocess_add_channel -v $PROCESSED_DATASET regrid.${CMIP_DATA}.${CONFIG_SUFFIX} land_map "icenet.data.masks.nsidc:Masks"
      fi
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
    pipeline_run icenet_plot_input -p -v dataset_config.${DATASET_NAME}.json $LAG_DATE ./plots/input.${CMIP_ID}.${HEMI}.${LAG_DATE}.png
    pipeline_run icenet_plot_input --outputs -v dataset_config.${DATASET_NAME}.json $LAG_DATE ./plots/outputs.${CMIP_ID}.${HEMI}.${LAG_DATE}.png
    pipeline_run icenet_plot_input --weights -v dataset_config.${DATASET_NAME}.json $LAG_DATE ./plots/weights.${CMIP_ID}.${HEMI}.${LAG_DATE}.png

    echo -n "To CACHE the dataset, please run: "
    echo icenet_dataset_create -v -p -l $LAG -ob $BATCH_SIZE -w $WORKERS -fl $FORECAST_LENGTH $LOADER_CONFIGURATION $DATASET_NAME
  done
done

# TODO: here is where we nick the val and test splits from the ground truth
#  datasets prepared in the alternative script. icenet_train can then be used
#  with MultiLoaderDataSet or whatever I called it, to pretrain the model
#  prior to the full run (TODO 2: this will need adapting to the OSI -> AMSR recipe)

unset PREFIX
export PREFIX=$OLD_PREFIX

if [ ! ${DRY:+1} ] || [ $DRY -eq 0 ]; then
  [ $PROCESSING -eq 0 ] && exit 0
  source ENVS

  # 1. Copy dataset_config.monthly.cmip_osi_north.json, with referred loader configuration
  GROUND_TRUTH_DATASET="dataset_config.`basename $( pwd )`_${HEMI}.json"
  GROUND_TRUTH_LOADER=`jq -r '.loader_config' $GROUND_TRUTH_DATASET`
  PRETRAIN_DATASET="dataset_config.pretrain_eval.`basename $( pwd )`_${HEMI}.json"
  PRETRAIN_LOADER="loader.pretrain.${PREFIX,,}.${DATA_FREQUENCY}.${HEMI}.json"

  jq --arg loader `realpath $PRETRAIN_LOADER` '.loader_config=$loader | .counts.train = 0' $GROUND_TRUTH_DATASET > $PRETRAIN_DATASET

  # 2. Strip out the split train dates from ground truth loader configuration

  jq '.sources[].splits.train = [] | .sources[].source_files.train = []' $GROUND_TRUTH_LOADER > $PRETRAIN_LOADER

  # 3. TEST with icenet_train
fi
