#!/usr/bin/bash

. /hpcpackages/python/miniconda3/etc/profile.d/conda.sh
conda activate /data/hpcdata/users/$USER/miniconda3/envs/icenet

START="2022-4-1"
END="2022-4-30"
LAG=3
FORECAST="current"

for HEMI in north south; do
    icenet_data_era5 $HEMI $START $END -v
    icenet_data_sic $HEMI $START $END -v
    icenet_process_era5 -r processed/era5_$HEMI/era5/$HEMI \
          -v -l $LAG -ts $START -te $END ${FORECAST}_${HEMI} $HEMI
    icenet_process_sic  -r processed/era5_$HEMI/osisaf/$HEMI \
          -v -l $LAG -ts $START -te $END ${FORECAST}_${HEMI} $HEMI
    icenet_process_metadata ${FORECAST}_${HEMI} $HEMI
    icenet_dataset_create -l $LAG -c ${FORECAST}_${HEMI} $HEMI
    ./loader_test_dates.sh ${FORECAST}_${HEMI} >${FORECAST}_${HEMI}.csv
    ./run_predict_ensemble.sh -f `cat FILTER_FACTOR | tr -d '\n'` -p bashpc.sh \
        ${HEMI}_hemi ${HEMI}_train.22 ${FORECAST}_${HEMI} ${FORECAST}_${HEMI}.csv ${FORECAST}_${HEMI}
done
