#!/usr/bin/env bash

source ENVS
conda activate $ICENET_CONDA

set -u -o pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage $0 PREDICTION_NETWORK"
    exit 1
fi

PREDICTION_NETWORK="$1"

for HEMI in south north; do
    DATE_RANGE="`date +%Y-1-1` `date +%F`"
    icenet_data_era5 -w 10 -v $DATA_ARGS_ERA5 $HEMI $DATE_RANGE 2>&1 | tee logs/fc.era5.${HEMI}.log
    icenet_data_sic -v $HEMI $DATE_RANGE 2>&1 | tee logs/fc.sic.${HEMI}.log

#   ERA5 tracks behind the SIC, there was an issue causing the need to use SIC
#    FORECAST_INIT=`python -c 'import xarray as xr; print(str(xr.open_dataset("data/osisaf/'$HEMI'/siconca/'${DATE_RANGE:0:4}'.nc").time.values.max())[0:10])'`

    # If ERA5 `tas` variable netCDF file does not exist for this year, likely because we've just hit first week of new year where there is no ERA5 data
    # available yet due to ~5 day lag in data availability.
    if [ ! -f "data/era5/$HEMI/tas/${DATE_RANGE:0:4}.nc" ]; then
        # Use latest day data has been downloaded for in the previous year
        echo "data/era5/$HEMI/tas/${DATE_RANGE:0:4}.nc" not found, using latest date from previous year as forecast init date.
        YEAR=`date +%Y --date='last year'`
        FORECAST_INIT=`python -c 'import xarray as xr; print(str(xr.open_dataset("data/era5/'$HEMI'/tas/'${YEAR}'.nc").time.values.max())[0:10])'`
    else
        YEAR=${DATE_RANGE:0:4}
        FORECAST_INIT=`python -c 'import xarray as xr; print(str(xr.open_dataset("data/era5/'$HEMI'/tas/'${YEAR}'.nc").time.values.max())[0:10])'`
    fi

    export FORECAST_START="$FORECAST_INIT"
    export FORECAST_END="$FORECAST_INIT"
    ./run_prediction.sh fc.$FORECAST_INIT ${PREDICTION_NETWORK}_${HEMI} $HEMI forecast $TRAIN_DATA_NAME 2>&1 | tee logs/fc.${HEMI}.log

    ./produce_op_assets.sh fc.${FORECAST_INIT}_${HEMI} 2>&1 | tee logs/op_assets.${HEMI}.log
done
