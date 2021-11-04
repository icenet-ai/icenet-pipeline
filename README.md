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
# TODO: template out ensemble configuration 
# TODO: execute

```

Machines: 

bslws07 - creating env


Running example throughput on laptop 

* [ ] Is missing_dates definitely operational? SIC processing did not update loader configuration
  OSError: [Errno -101] NetCDF: HDF error: b'/data/hpcdata/users/jambyr/icenet
 .south/data/osisaf/sh/siconca/1990/1990_01_09.temp'
* [ ] HRES data regrid error:

```
DEBUG:root:Regridding ./data/mars.hres/nh/siconca/2020/latlon_siconca_2020_02_04.nc
ut_scale(): NULL factor argument
ut_are_convertible(): NULL unit argument
/home/jambyr/anaconda3/envs/icenet2/lib/python3.8/site-packages/iris/fileformats/_nc_load_rules/helpers.py:645: UserWarning: Ignoring netCDF variable 'siconc' invalid units '(0 - 1)'
  warnings.warn(msg)
INFO:root:Saving regridded data to ./data/mars.hres/nh/siconca/2020/siconca_2020_02_04.nc... 
INFO:root:Removing ./data/mars.hres/nh/siconca/2020/latlon_siconca_2020_02_04.nc
```