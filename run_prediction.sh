#!/usr/bin/bash

. /hpcpackages/python/miniconda3/etc/profile.d/conda.sh
conda activate /data/hpcdata/users/$USER/miniconda3/envs/icenet

START="1987-3-1,1987-10-1,1988-3-1,1988-10-1,1989-3-1,1989-10-1,1996-3-1,1996-10-1,1997-3-1,1997-10-1,1998-3-1,1998-10-1,1999-3-1,1999-10-1,2000-3-1,2000-10-1,2001-3-1,2001-10-1,2002-3-1,2002-10-1,2003-3-1,2003-10-1,2004-3-1,2004-10-1,2005-3-1,2005-10-1,2006-3-1,2006-10-1,2015-3-1,2015-10-1,2016-3-1,2016-10-1,2017-3-1,2017-10-1,2018-3-1,2018-10-1,2019-3-1,2019-10-1,2020-3-1,2020-10-1,2021-3-1,2021-10-1"
END="$START"
LAG=3
FORECAST="$1"
LOADER="${2:-$FORECAST}"

for HEMI in north south; do
    icenet_data_era5 $HEMI $START $END -v
    icenet_data_sic $HEMI $START $END -v
    icenet_process_era5 -r processed/era5_$HEMI/era5/$HEMI \
          -v -l $LAG -ts $START -te $END ${FORECAST}_${HEMI} $HEMI
    icenet_process_sic  -r processed/era5_$HEMI/osisaf/$HEMI \
          -v -l $LAG -ts $START -te $END ${FORECAST}_${HEMI} $HEMI
    icenet_process_metadata ${FORECAST}_${HEMI} $HEMI
    icenet_dataset_create -l $LAG -c ${LOADER}_${HEMI} $HEMI
    ./loader_test_dates.sh ${LOADER}_${HEMI} >${FORECAST}_${HEMI}.csv
    ./run_predict_ensemble.sh -i ${HEMI}_train.22 -f `cat FILTER_FACTOR | tr -d '\n'` -p bashpc.sh \
        ${HEMI}_hemi ${FORECAST}_${HEMI} ${FORECAST}_${HEMI} ${FORECAST}_${HEMI}.csv
done
