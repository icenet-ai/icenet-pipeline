#!/bin/bash -x
# Trained model to forecast from. Uses PREDICTION_NETWORK if it is set in the
# environment, otherwise defaults to atmos23 for backwards compatibility.
PREDICTION_NETWORK=${PREDICTION_NETWORK:-atmos23}

export ENSEMBLE_PREDICT_SEEDS="42,46,45,17,24,84,83,16,5,3"
./run_era5_forecast.sh ${PREDICTION_NETWORK}  |& tee logs/daily.`date +\%F`.log
