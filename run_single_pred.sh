#!/usr/bin/bash

. /hpcpackages/python/miniconda3/etc/profile.d/conda.sh
conda activate /data/hpcdata/users/$USER/miniconda3/envs/icenet

START="2016-9-1"
END="2016-9-1"
LAG=3
FORECAST="ptest"
LOADER="ptest"
HEMI=north

# If you didn't train the model, use 
#    ln -s /data/hpcdata/users/<train_user>/icenet/pipeline/processed/trainproc/ ./processed/trainproc
# to link the training normalisation parameters
icenet_process_era5 -r processed/era5_$HEMI/era5/$HEMI \
          -v -l $LAG -ts $START -te $END ${FORECAST}_${HEMI} $HEMI
icenet_process_sic  -r processed/era5_$HEMI/osisaf/$HEMI \
          -v -l $LAG -ts $START -te $END ${FORECAST}_${HEMI} $HEMI
icenet_process_metadata ${FORECAST}_${HEMI} $HEMI
icenet_dataset_create -l $LAG -c ${LOADER}_${HEMI} $HEMI
./loader_test_dates.sh ${LOADER}_${HEMI} >${FORECAST}_${HEMI}.csv
./run_predict_ensemble.sh -i ${HEMI}_train.22 -f 1.2 -p bashpc.sh \
        ${HEMI}_hemi ${FORECAST}_${HEMI} ${FORECAST}_${HEMI} ${FORECAST}_${HEMI}.csv

