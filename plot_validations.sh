#!/usr/bin/env bash

source ENVS

if [ $# -lt 1 ] || [ "$1" == "-h" ]; then
    echo -e "\nUsage $0 <forecast_name> <hemisphere>"
    echo -e "\nArguments"
    echo "<forecast_name>     name of forecast"
    echo -e "\nOptions"
    echo "-m <metrics>        string of metrics separated by commas, by default \"binacc,sie,mae,rmse,sic\""
    echo "-r <region>         region arguments, by default uses full hemisphere"
    echo "-t <thresholds>     string of SIC thresholds separated by (each must be between 0 and 1), by default \"0.15,0.8\""
    echo "-g <grid_area_size> grid area resolution to use - i.e. the length of the sides in km, by default 25 (i.e. 25km^2)"
    echo "-o <output_dir>     output directory path to store plots, by default \"plot/validation/<forecast_name>\""
    echo -e "\nThe script will generate several plots which can be used to validate the forecast (and also to compare with ECMWF)"
    echo "The plots to analyse the performance of the forecasts will be saved to <output_dir>"
    echo "and the plots to compare performance with ECMWF will be saved to <output_dir>/ECMWF_comp"
    echo "Run \"plot_forecast.sh -h\" for more details of what the plots generated are"
    exit 1
fi

# default values
METRICS="binacc,sie,mae,rmse,sic"
REGION=""
THRESHOLDS=(0.15, 0.8)
GRID_AREA_SIZE="-g 25"
REQUESTED_OUTPUT_DIR=""
OPTIND=1

while getopts "m:r:t:g:o:" opt; do
    case "$opt" in
        m)  METRICS=${OPTARG} ;;
        r)  REGION="-r ${OPTARG}" ;;
        t)  THRESHOLDS=${OPTARG} ;;
        g)  GRID_AREA_SIZE="-g ${OPTARG}" ;;
        o)  REQUESTED_OUTPUT_DIR=${OPTARG}
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

# echo "Leftovers from getopt: $@"

FORECAST_NAME=${1}

if [ "${REQUESTED_OUTPUT_DIR}" == "" ]; then
    OUTPUT_DIR="plot/validation/${FORECAST_NAME}"
else
    OUTPUT_DIR=${REQUESTED_OUTPUT_DIR}
fi

mkdir -p $OUTPUT_DIR

echo "Producing validation assets (${METRICS[@]} metrics) in ${OUTPUT_DIR} and ${OUTPUT_DIR}/ECMWF_comp"

for element in "${METRICS[@]}"
    do
    if [ "${element}" == "binacc" ]; then
        for THRESH in ${THRESHOLDS[@]}; do
            ./plot_forecast.sh -m ${element} $REGION -v -l -t $THRESH \
                -o $OUTPUT_DIR $FORECAST_NAME
            ./plot_forecast.sh -m ${element} $REGION -e -v -l -t $THRESH \
                -o "${OUTPUT_DIR}/ECMWF_comp" $FORECAST_NAME
        done
    elif [ "${element}" == "sie" ]; then
        for THRESH in ${THRESHOLDS[@]}; do
            ./plot_forecast.sh -m ${element} $REGION -v -l -t $THRESH $GRID_AREA_SIZE \
                -o $OUTPUT_DIR $FORECAST_NAME
            ./plot_forecast.sh -m ${element} $REGION -e -v -l -t $THRESH $GRID_AREA_SIZE \
                -o "${OUTPUT_DIR}/ECMWF_comp" $FORECAST_NAME
        done
    elif [ "${element}" == "sic" ]; then
        ./plot_forecast.sh -m ${element} $REGION -v \
            -o $OUTPUT_DIR $FORECAST_NAME
    else
        if [ "${element}" == "mae" ]; then
            LOGFILE="${MAE_LOG}"
        elif [ "${element}" == "mse" ]; then
            LOGFILE="${MSE_LOG}"
        elif [ "${element}" == "rmse" ]; then
            LOGFILE="${RMSE_LOG}"
        fi
        ./plot_forecast.sh -m ${element} $REGION -v -l \
            -o $OUTPUT_DIR $FORECAST_NAME
        ./plot_forecast.sh -m ${element} $REGION -e -v -l \
            -o "${OUTPUT_DIR}/ECMWF_comp" $FORECAST_NAME
    fi
done
