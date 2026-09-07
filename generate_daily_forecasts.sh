#!/bin/bash -x
export ENSEMBLE_PREDICT_SEEDS="42,46,45,17,24,84,83,16,5,3"
./run_era5_forecast.sh atmos23 |& tee logs/daily.`date +\%F`.log
