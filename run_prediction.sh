#!/usr/bin/bash

. ENVS

. /hpcpackages/python/miniconda3/etc/profile.d/conda.sh
conda activate /data/hpcdata/users/$USER/miniconda3/envs/icenet

FORECAST="$1"
HEMI="${2:-$HEMI}"
LOADER="${3:-$FORECAST}"
DO_DATA=${4:-0}

# If you didn't train the model, use
#    ln -s /data/hpcdata/users/<train_user>/icenet/pipeline/processed/trainproc/ ./processed/trainproc
# to link the training normalisation parameters

# FIXME: due to https://github.com/icenet-ai/icenet/issues/53 we assume don't
if [ $DO_DATA == 1 ]; then
    echo "Downloading requried data"
    [ ! -z "$DATA_ARGS_ERA5" ] && \
        icenet_data_era5 $HEMI $START $END -v $DATA_ARGS_ERA5

    [ ! -z "$DATA_ARGS_ORAS5" ] && \
        icenet_data_oras5 $HEMI $START $END -v $DATA_ARGS_ORAS5

    icenet_data_sic $HEMI $PRED_START $PRED_END -v
fi

[ ! -z "$PROC_ARGS_ERA5" ] && \
    icenet_process_era5 -r processed/${PREFIX}_${HEMI}/era5/$HEMI \
        $PROC_ARGS_ERA5 \
        -v -l $LAG -ts $PRED_START -te $PRED_END ${FORECAST}_${HEMI} $HEMI

[ ! -z "$PROC_ARGS_ORAS5" ] && \
    icenet_process_oras5 -r processed/${PREFIX}_${HEMI}/oras5/$HEMI \
        $PROC_ARGS_ORAS5 \
        -v -l $LAG -ts $PRED_START -te $PRED_END ${FORECAST}_${HEMI} $HEMI

[ ! -z "$PROC_ARGS_SIC" ] && \
    icenet_process_sic  -r processed/${PREFIX}_${HEMI}/osisaf/$HEMI \
        $PROC_ARGS_SIC \
        -v -l $LAG -ts $PRED_START -te $PRED_END ${FORECAST}_${HEMI} $HEMI

icenet_process_metadata ${FORECAST}_${HEMI} $HEMI
icenet_dataset_create -l $LAG -c ${FORECAST}_${HEMI} $HEMI
./loader_test_dates.sh ${FORECAST}_${HEMI} >${FORECAST}_${HEMI}.csv
# FIXME: ${HEMI}_hemi as network name needs to be easier to specify
#  as it's $NAME in run_train_ensemble
./run_predict_ensemble.sh -i ${PREFIX}_${HEMI}.22 -f $FILTER_FACTOR -p bashpc.sh \
    ${HEMI}1 ${FORECAST}_${HEMI} ${FORECAST}_${HEMI} ${FORECAST}_${HEMI}.csv
    #${HEMI}_hemi ${FORECAST}_${HEMI} ${FORECAST}_${HEMI} ${FORECAST}_${HEMI}.csv
icenet_plot_sic_error -o plot/sic_error.${FORECAST}.${HEMI}.mp4 -v ${HEMI} results/predict/${FORECAST}_${HEMI}.nc `head -n 1 ${FORECAST}_${HEMI}.csv`
