#!/usr/bin/env bash

source ENVS

if [ $# -lt 2 ] || [ "$1" == "-h" ]; then
    echo "Usage $0 <forecast_name> <hemisphere>"
    echo "\nArguments"
    echo "<forecast_name>     name of forecast"
    echo "<hemisphere>        hemisphere to use"
    echo "\nOptions"
    echo "-m <metrics>        string of metrics separated by commas, by default \"binacc,sie,mae,rmse,sic\""
    echo "-r <region>         region arguments, by default uses full hemisphere"
    echo "-t <thresholds>     string of SIC thresholds separated by (each must be between 0 and 1), by default \"0.15,0.8\""
    echo "-g <grid_area_size> grid area resolution to use - i.e. the length of the sides in km, by default 25 (i.e. 25km^2)"
    echo "-o <output_dir>     output directory path to store plots, by default \"plot/validation/<forecast_name>\""
    exit 1
fi

# default values
METRICS="binacc,sie,mae,rmse,sic"
REGION=""
THRESHOLDS=(0.15, 0.8)
GRID_AREA_SIZE="-g 25"
OUTPUT_DIR="plot/validation/${FORECAST_NAME}"
OPTIND=1
while getopts "m:r:t:g:o:" opt; do
    case "$opt" in
        m)  METRICS=${OPTARG} ;;
        r)  REGION="-r ${OPTARG}" ;;
        t)  THRESHOLDS=${OPTARG} ;;
        g)  GRID_AREA_SIZE="-g ${OPTARG}" ;;
        o)  OUTPUT_DIR=${OPTARG}
    esac
done

# split on commas
METRICS=(${METRICS//,/ })
THRESHOLDS=(${THRESHOLDS//,/ })

# check if metric is valid
VALID_METRICS=("binacc" "sie" "mae" "mse" "rmse" "sic")
for element in "${METRICS[@]}"
do
    if [[ ! "${VALID_METRICS[*]}" =~ "${element}" ]]; then
        # element is not in VALID_METRICS 
        echo "'${element}' is not a valid metric"
        exit 1
    fi
done

shift $((OPTIND-1))

echo "Leftovers from getopt: $@"

FORECAST="$1"
HEMI="$2"
LOG_PREFIX="logs/${FORECAST_NAME}_validation"
BINACC_LOG="${LOG_PREFIX}_binacc.log"
SIE_LOG="${LOG_PREFIX}_sie.log"
MAE_LOG="${LOG_PREFIX}_mae.log"
MSE_LOG="${LOG_PREFIX}_mse.log"
RMSE_LOG="${LOG_PREFIX}_rmse.log"
SICERR_LOG="${LOG_PREFIX}_sic.log"

if [ -d $OUTPUT_DIR ]; then
    # remove existing log files if they exist
    rm -v -f $BINACC_LOG $SIE_LOG $MAE_LOG $MSE_LOG $RMSE_LOG $SICERR_LOG
fi
mkdir -p $OUTPUT_DIR

for element in "${METRICS[@]}"
    do
    OUTPUT="${OUTPUT_DIR}/${element}_leadtime_avg.png"
    if [ "${element}" == "binacc" ]; then
        for THRESH in ${THRESHOLDS}; do
            ./run_forecast_plots.sh -m ${element} $REGION -v -l -t $THRESH \
                -o $OUTPUT_DIR $FORECAST $HEMI >> $BINACC_LOG 2>&1
            ./run_forecast_plots.sh -m ${element} $REGION -e -v -l -t $THRESH \
                -o $OUTPUT_DIR $FORECAST $HEMI >> $BINACC_LOG 2>&1
        done
    elif [ "${element}" == "sie" ]; then
        for THRESH in ${THRESHOLDS}; do
            ./run_forecast_plots.sh -m ${element} $REGION -v -l \
                -t $THRESH $GRID_AREA_SIZE -o $OUTPUT_DIR $FORECAST $HEMI >> $SIE_LOG 2>&1
            ./run_forecast_plots.sh -m ${element} $REGION -e -v -l \
                -t $THRESH $GRID_AREA_SIZE -o $OUTPUT_DIR $FORECAST $HEMI >> $SIE_LOG 2>&1
        done
    elif [ "${element}" == "sic" ]; then
        ./run_forecast_plots.sh -m ${element} $REGION -v \
            -o $OUTPUT_DIR $FORECAST $HEMI >> $SICERR_LOG 2>&1
    else
        if [ "${element}" == "mae" ]; then
            LOGFILE="${MAE_LOG}"
        elif [ "${element}" == "mse" ]; then
            LOGFILE="${MSE_LOG}"
        elif [ "${element}" == "rmse" ]; then
            LOGFILE="${RMSE_LOG}"
        fi
        ./run_forecast_plots.sh -m ${element} $REGION -v -l \
            -o $OUTPUT_DIR $FORECAST $HEMI >> $LOGFILE 2>&1
        ./run_forecast_plots.sh -m ${element} $REGION -e -v -l \
            -o $OUTPUT_DIR $FORECAST $HEMI >> $LOGFILE 2>&1
    fi
done