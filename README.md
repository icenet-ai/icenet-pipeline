# IceNet-Pipeline
Tools for operational execution of the IceNet model

## Overview

The structure of this repository is to provide CLI commands that allow you to
 run the icenet model end-to-end, allowing you to make daily sea ice 
 predictions.
 
## Example run of the pipeline



Obviously we can substitute south/north as required
```bash
LAG=1

conda env create --file environment.yml
conda activate icenet2

icenet_data_masks south
# Training and val
icenet_data_era5 south 1990-1-1 1990-2-14
icenet_data_sic south 1990-1-1 1990-2-14
# Test
icenet_data_hres south 2020-2-1 2020-2-4
icenet_data_sic south 2020-2-1 2020-2-4

icenet_process_era5 laptop south \
    -ns 2010-1-2,2010-2-2 \
    -ne 2010-1-20,2010-2-14 \
    -vs 2010-1-22 -ve 2010-1-31 -l $LAG 
icenet_process_sic laptop south \
    -ns 2010-1-2,2010-2-2 \
    -ne 2010-1-20,2010-2-14 \
    -vs 2010-1-22 -ve 2010-1-31 -l $LAG

# TODO: this is where we're picking up no files
icenet_process_hres -v -l $LAG -ts 2020-2-1 -te 2020-2-4 forecast north

icenet_process_metadata laptop south
icenet_process_metadata forecast south

icenet_dataset_create -l $LAG -ob 4 -w 16 laptop south
icenet_dataset_create -l $LAG -fn test_forecast -ob 1 -w 4 forecast south

# Pipeline specific

run_train_ensemble.sh LOADER DATASET NAME 

run_predict_ensemble.sh
# TODO: predict_dates.csv

./install_env.sh icenet
conda activate icenet

icenet_data_masks south

icenet_data_era5 -v -w 16 south 1990-1-1 1999-12-31 2>&1 | tee logs/era5.log
icenet_data_sic -v south 1990-1-1 1999-12-31 2>&1 | tee logs/sic.log

icenet_data_era5 -v -w 8 south 2021-1-1 2021-10-31 2>&1 | tee logs/test.era5.log
icenet_data_hres -v south 2021-1-1 2021-10-31 2>&1 | tee logs/test.hres.log
icenet_data_sic -v south 2021-1-1 2021-10-31 2>&1 | tee logs/test.sic.log

icenet_data_era5 -v -w 16 south 2000-1-1 2009-12-31 2>&1 | tee logs/era5.log
icenet_data_sic -v south 2000-1-1 2009-12-31 2>&1 | tee logs/sic.log

for FILENAME in $( find . -type f -a -name '*.nc' -print | grep -v 'latlon_' ); do DEST=`echo "$FILENAME" | sed -r 's/\/[a-z0-9]+_/\//g'`; echo mv -v $FILENAME $DEST; done

icenet_process_era5 90s south \
    -ns 1990-1-1 \
    -ne 1998-12-31 \
    -vs 1999-1-1 -ve 1999-7-31 \
    -ts 1999-8-1 -te 1999-12-31 -l 3 2>&1 | tee logs/era5.90s.log 
icenet_process_sic 90s south \
    -ns 1990-1-1 \
    -ne 1998-12-31 \
    -vs 1999-1-1 -ve 1999-7-31 \
    -ts 1999-8-1 -te 1999-12-31 -l 3 2>&1 | tee logs/sic.90s.log 
icenet_process_metadata -v 90s south

icenet_dataset_create -l 3 -ob 4 -w 16 90s south 2>&1 | tee logs/ds.90s.log

# TODO: additional flag/template for picking up existing networks using sed 
# Usage ./run_train_ensemble.sh LOADER DATASET NAME
./run_train_ensemble.sh \
    -b 4 -e 20 -f 1.2 -g 2 -n node022 -p bashpc.sh -q 8 -s mirrored \
    90s 90s_22 south_90s

# icenet_train DATASET NAME SEED
#./results/networks/NAME/NAME.network_DATASET.SEED.h5

# TODO: create some better date generation mechanism, but this will be
#  under the users control, I just dislike stuffing it in the batch dir
# Usage ./run_predict_ensemble.sh NETWORK DATASET NAME
mkdir ensemble/south_90s_forecast
ln -s ../../90s_test_dates.csv ensemble/south_90s_forecast/predict_dates.csv

# icenet_predict [-h] [-n N_FILTERS_FACTOR] [-o] [-t] [-v] dataset network_name output_name seed datefile

./run_predict_ensemble.sh -f 1.2 -p bashpc.sh south_90s 90s_22 90s_testset 90s_test_dates.csv




# To account for the short partition using non-localised dataset
for I in $( seq 42 1 46 ); do ln -s south_90s.$I.network_90s_22.$I.h5 south_90s.$I/south_90s.$I.network_90s.$I.h5; done


### TESTING
# TODO: add capability to pick up normalisation/climatology automatically 
#  from another processed set 
icenet_process_hres antarctic_test south \
    -ts 2021-1-1 -te 2021-10-31 -l 3 2>&1 | tee logs/antarctic.hres.log
rmdir processed/antarctic_test/mars.hres/sh/normalisation.scale/
ln -s `realpath processed/90s/era5/sh/normalisation.scale/` processed/antarctic_test/mars.hres/sh/normalisation.scale
ln -s `realpath processed/90s/era5/sh/params/` processed/antarctic_test/mars.hres/sh/params
icenet_process_hres antarctic_test south \
    -ts 2021-1-1 -te 2021-10-31 -l 3 2>&1 | tee logs/antarctic.hres.log
icenet_process_metadata -v antarctic_test south
icenet_dataset_create -l 3 -c antarctic_test south 2>&1 | tee logs/ds.2021.log

./run_predict_ensemble.sh -f 1.2 -p bashpc.sh -i 90s -l south_90s antarctic_test antarctic_hres_2021_test antarctic_test.csv
```


### Fixed rlds table number 

## Training mainline model


This is going to be a full 1979-2015 training run, 2016-2018 validation, 
2019-2020 test from OSISAF and ERA5 data, in both hemispheres.

```bash

conda activate icenet

for HEMI in north south; do 
    nohup icenet_data_masks -v ${HEMI} >logs/masks.${HEMI}.log 2>&1 & 
    nohup icenet_data_era5 -v ${HEMI} 1979-1-1 2020-12-31 >logs/era5.${HEMI}.log 2>&1 & 
    nohup icenet_data_sic -v ${HEMI} 1979-1-1 2020-12-31 >logs/sic.${HEMI}.log 2>&1 &
done

TODO

LAG=3

for HEMI in north south; do 
    PROC_NAME="${HEMI}_10"
    RATIO=0.1
    
    nohup icenet_process_era5 -v ${PROC_NAME} ${HEMI} \
        -ns 1979-1-1 -ne 2015-12-31 \
        -vs 2016-1-1 -ve 2018-12-31 \
        -ts 2019-1-1 -te 2020-12-31 \
        -l ${LAG} -d ${RATIO} >logs/proc_era5.${PROC_NAME}.log 2>&1 &
    nohup icenet_process_sic -v ${PROC_NAME} ${HEMI} \
        -ns 1979-1-1 -ne 2015-12-31 \
        -vs 2016-1-1 -ve 2018-12-31 \
        -ts 2019-1-1 -te 2020-12-31 \
        -l ${LAG} -d ${RATIO} >logs/proc_sic.${PROC_NAME}.log 2>&1 &
    nohup icenet_process_metadata -v ${PROC_NAME} ${HEMI} \
        >logs/proc_meta.${PROC_NAME}.log 2>&1 &
done

icenet_dataset_create -v -l 3 -ob 4 -w 16 -fn north_testrun \
    north_10 north 2>&1 | tee logs/ds.north_testrun.log
icenet_dataset_create -v -l 3 -ob 4 -w 16 -fn south_testrun \
    south_10 south 2>&1 | tee logs/ds.south_testrun.log
    
# bslws04 - bs == ob
./run_train_ensemble.sh \
    -b 4 -e 200 -f 1.2 -n node022 -p bashpc.sh -q 4 -g 2 -s mirrored -j 3 \
    north_10 north_test22 north_hemi
# bslws07
./run_train_ensemble.sh \
    -b 2 -e 200 -f 1.2 -n node022 -p bashpc.sh -q 4 -g 2 -s mirrored -j 3 \
    south_10 south_test22 south_hemi


./loader_test_dates.sh north_10 north_testpred
./run_predict_ensemble.sh \
    -b 1 -f 1.2 -p bashpc.sh -i north_test22 \
    north_hemi north_testrun north_testpred predict.north_10.csv north_10

./loader_test_dates.sh south_10 south_testpred
./run_predict_ensemble.sh \
    -b 1 -f 1.2 -p bashpc.sh -i south_test22 \
    south_hemi south_testrun south_testpred predict.south_10.csv south_10
    
```

TODO
We'll then use 2021 HRES data to produce a comparitive forecast against 
downloaded 2021 ERA5/OSISAF reference dataset.

```bash
# bslws04
ICENET_END=`date --date="yesterday" +%F`
nohup icenet_data_era5 -v -w 8 north 2021-1-1 $ICENET_END >logs/north.era5.log &
nohup icenet_data_hres -v north 2021-1-1 $ICENET_END >logs/north.hres.log &
nohup icenet_data_sic -v north 2021-1-1 $ICENET_END >logs/north.sic.log &
# bslws07
ICENET_END=`date --date="yesterday" +%F`
nohup icenet_data_era5 -v -w 8 south 2021-1-1 $ICENET_END >logs/south.era5.log &
nohup icenet_data_hres -v south 2021-1-1 $ICENET_END >logs/south.hres.log &
nohup icenet_data_sic -v south 2021-1-1 $ICENET_END >logs/south.sic.log &

#north
for HEMI in  south; do 
    PROC_NAME="${HEMI}_forecast"
    
    nohup icenet_process_era5 -v ${PROC_NAME} ${HEMI} \
        -ts 2021-1-1 -te $ICENET_END \
        -r processed/${HEMI}_10/era5/sh \
        -l 0 >logs/proc_era5.${PROC_NAME}.log 2>&1 &
    nohup icenet_process_sic -v ${PROC_NAME} ${HEMI} \
        -ts 2021-1-1 -te $ICENET_END \
        -r processed/${HEMI}_10/osisaf/sh \
        -l 0 >logs/proc_sic.${PROC_NAME}.log 2>&1 &
    nohup icenet_process_metadata -v ${PROC_NAME} ${HEMI} \
        >logs/proc_meta.${PROC_NAME}.log 2>&1 &
done

## SAME FOR BOTH HRES AND ERA (see below)
PROC_NAME="south_forecast"
LAG=3
icenet_dataset_create -c -l $LAG -ob 1 -w 4 $PROC_NAME south
./loader_test_dates.sh $PROC_NAME | tail -n 28 >predict.${PROC_NAME}.csv
./run_predict_ensemble.sh \
    -b 1 -f 1.2 -p bashpc.sh -l -i south_test22 \
    south_hemi $PROC_NAME $PROC_NAME predict.${PROC_NAME}.csv 

#NOW HRES
```
```python

### Replacing rlds with new data
def fillin():
    hres = HRESDownloader(
        var_names=["rlds",],
        pressure_levels=[None],
        dates=[pd.to_datetime(date).date() for date in
               pd.date_range("2021-1-1", "2021-11-30",
                             freq="D")],
        north=False,
        south=True
    )
    hres.download()
    hres.regrid()
    hres.rotate_wind_data()
```
%HERE
```bash

PROC_NAME="south_rt_forecast"
icenet_process_metadata -v ${PROC_NAME} south \
        2>&1 | tee logs/${PROC_NAME}.meta.log 
icenet_process_hres -v ${PROC_NAME} south \
    -ts 2021-1-1 -te $ICENET_END -l 0 \
    -r processed/south_10/era5/sh \
    2>&1 | tee logs/${PROC_NAME}.hres.log
LAG=3
# NOTE THE -c - we only produce configuration here...
icenet_dataset_create -c -l $LAG -ob 1 -w 4 $PROC_NAME south
./loader_test_dates.sh $PROC_NAME | tail -n 28 >predict.${PROC_NAME}.csv
# NOTE THE -l - we use the loader directly
./run_predict_ensemble.sh \
    -b 1 -f 1.2 -p bashpc.sh -l -i south_test22 \
    south_hemi $PROC_NAME $PROC_NAME predict.${PROC_NAME}.csv 

```

TODO
Finally, we'll set a daily run off that downloads the additional daily HRES 
forecast to produce the newest forecast automatically. We'll also download up
 to date OSISAF data for comparison as far as we can.
 

