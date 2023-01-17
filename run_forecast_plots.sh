#!/usr/bin/env bash

source ENVS

FORECAST="$1"
HEMI="${2:-$HEMI}"

FORECAST_NAME=${FORECAST}_${HEMI}
FORECAST_FILE="results/predict/${FORECAST_NAME}.nc"
LOG_PREFIX="logs/${FORECAST_NAME}"
BINACC_LOG="${LOG_PREFIX}_bin_accuracy.log"
SICERR_LOG="${LOG_PREFIX}_sic_error.log"
OUTPUT_DIR="plot/$FORECAST_NAME"

if [ -d $OUTPUT_DIR ]; then
    rm -v $BINACC_LOG $SICERR_LOG
fi
mkdir -p $OUTPUT_DIR

echo "Reading ${FORECAST_NAME}.csv"

cat ${FORECAST_NAME}.csv | while read -r FORECAST_DATE; do
    echo "Producing binary accuracy for $FORECAST_DATE";
    icenet_plot_bin_accuracy -e -v \
        -o ${OUTPUT_DIR}/bin_accuracy.${FORECAST_DATE}.png \
        $HEMI $FORECAST_FILE $FORECAST_DATE >>$BINACC_LOG 2>&1

    echo "Producing SIC error for $FORECAST_DATE";
    icenet_plot_sic_error -v \
        -o ${OUTPUT_DIR}/sic_error.${FORECAST_DATE}.mp4 \
        $HEMI $FORECAST_FILE $FORECAST_DATE >>$SICERR_LOG 2>&1
done
