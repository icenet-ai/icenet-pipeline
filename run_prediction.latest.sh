#!/usr/bin/bash

. /hpcpackages/python/miniconda3/etc/profile.d/conda.sh
conda activate /data/hpcdata/users/$USER/miniconda3/envs/icenet

START="1990-4-1"
END="1990-4-1"
LAG=1
FORECAST="dufftest"

for HEMI in north south; do
    icenet_data_era5 $HEMI $START $END -v \
        --vars uas,vas,tas,ta,tos,psl,zg --levels ',,,500,,,250|500'
    icenet_data_sic $HEMI $START $END -v -d
    icenet_process_era5 -r processed/current_$HEMI/era5/$HEMI \
        --abs uas,vas --anom tas,ta500,tos,psl,zg500,zg250 \
        -v -l $LAG -ts $START -te $END ${FORECAST}_${HEMI} $HEMI
    icenet_process_sic  -r processed/current_$HEMI/osisaf/$HEMI \
        --abs siconca --trends siconca --trend-lead 1,8,15,22,29,36,43,50,57,64,71,78,85,92 \
        -v -l $LAG -ts $START -te $END ${FORECAST}_${HEMI} $HEMI
    icenet_process_metadata ${FORECAST}_${HEMI} $HEMI
    icenet_dataset_create -l $LAG -c ${FORECAST}_${HEMI} $HEMI
    ./loader_test_dates.sh ${FORECAST}_${HEMI} >${FORECAST}_${HEMI}.csv
    ./run_predict_ensemble.sh -f `cat FILTER_FACTOR | tr -d '\n'` -i current_${HEMI}.22 -p bashpc.sh \
        ${HEMI}1 ${FORECAST}_${HEMI} ${FORECAST}_${HEMI} ${FORECAST}_${HEMI}.csv ${FORECAST}_${HEMI}
    icenet_plot_sic_error -o plot/sic_error.${FORECAST}.${HEMI}.mp4 -v ${HEMI} results/predict/${FORECAST}_${HEMI}.nc `head -n 1 ${FORECAST}_${HEMI}.csv`
done
