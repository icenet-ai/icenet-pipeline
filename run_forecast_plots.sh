#!/usr/bin/env bash

source ENVS

if [ $# -lt 2 ] || [ "$1" == "-h" ] ; then
    echo "Usage $0 [-m <metrics>] [-e] [-r] [-l] <forecast_name> <hemisphere>"
fi

# default values for metrics to produce and to compare with ECMWF
METRICS="binacc,sic"
ECMWF="false"
ROLLING="false"
LEADTIME_AVG="false"
OPTIND=1
while getopts "m:erl" opt; do
    case "$opt" in
        m)  METRICS=${OPTARG} ;;
        e)  ECMWF="true" ;;
        r)  ROLLING="true" ;;
        l)  LEADTIME_AVG="true"
    esac
done

# split on commas
METRICS=(${METRICS//,/ })

# check if metric is valid
VALID_METRICS=("binacc" "sie" "mae" "mse" "rmse" "sic")
for element in "${METRICS[@]}"
do
    if [[ ! "${VALID_METRICS[*]}" =~ "${element}" ]] ; then
        # element is not in VALID_METRICS 
        echo "'${element}' is not a valid metric"
        exit 1
    fi
done

# determine whether or not to compare with ECMWF
if [[ "${ECMWF}" == true ]]; then
    echo "Generating (${METRICS[@]}) plots for forecast (with comparison with ECMWF)"
    E_FLAG="-e"
else
    echo "Generating (${METRICS[@]}) plots for forecast (without comparison with ECMWF)"
    E_FLAG=""
fi

if [[ "${LEADTIME_AVG}" == true ]]; then
    echo "Also generating leadtime averaged plots for the above metrics"
fi

shift $((OPTIND-1))

echo "Leftovers from getopt: $@"

FORECAST="$1"
HEMI="$2"

FORECAST_NAME=${FORECAST}_${HEMI}
FORECAST_FILE="results/predict/${FORECAST_NAME}.nc"
LOG_PREFIX="logs/${FORECAST_NAME}"
BINACC_LOG="${LOG_PREFIX}_binacc.log"
SIE_LOG="${LOG_PREFIX}_sie.log"
MAE_LOG="${LOG_PREFIX}_mae.log"
MSE_LOG="${LOG_PREFIX}_mse.log"
RMSE_LOG="${LOG_PREFIX}_rmse.log"
SICERR_LOG="${LOG_PREFIX}_sic.log"
OUTPUT_DIR="plot/$FORECAST_NAME"

if [ -d $OUTPUT_DIR ] ; then
    # remove existing log files if they exist
    rm -v -f $BINACC_LOG $SIE_LOG $MAE_LOG $MSE_LOG $RMSE_LOG $SICERR_LOG
fi
mkdir -p $OUTPUT_DIR

echo "Reading ${FORECAST_NAME}.csv"

# create metric plots for each forecast date
cat ${FORECAST_NAME}.csv | while read -r FORECAST_DATE; do
    for element in "${METRICS[@]}"
    do
        OUTPUT="${OUTPUT_DIR}/${element}.${FORECAST_DATE}.png"
        if [ "${element}" == "binacc" ] ; then
            echo "Producing binary accuracy plot for $FORECAST_DATE (${OUTPUT})"
            icenet_plot_bin_accuracy -b $E_FLAG -v -o $OUTPUT \
                $HEMI $FORECAST_FILE $FORECAST_DATE >> $BINACC_LOG 2>&1
        elif [ "${element}" == "sie" ] ; then
            echo "Producing sea ice extent error plot for $FORECAST_DATE (${OUTPUT})"
            icenet_plot_sie_error -b $E_FLAG -v -o $OUTPUT \
                $HEMI $FORECAST_FILE $FORECAST_DATE >> $SIE_LOG 2>&1
        elif [ "${element}" == "mae" ] ; then
            echo "Producing MAE plot for $FORECAST_DATE (${OUTPUT})"
            icenet_plot_metrics -b $E_FLAG -v -m "MAE" -o $OUTPUT \
                $HEMI $FORECAST_FILE $FORECAST_DATE >> $MAE_LOG 2>&1
        elif [ "${element}" == "mse" ] ; then
            echo "Producing MSE plot for $FORECAST_DATE (${OUTPUT})"
            icenet_plot_metrics -b $E_FLAG -v -m "MSE" -o $OUTPUT \
                $HEMI $FORECAST_FILE $FORECAST_DATE >> $MSE_LOG 2>&1
        elif [ "${element}" == "rmse" ] ; then
            echo "Producing RMSE plot for $FORECAST_DATE (${OUTPUT})"
            icenet_plot_metrics -b $E_FLAG -v -m "RMSE" -o $OUTPUT \
                $HEMI $FORECAST_FILE $FORECAST_DATE >> $RMSE_LOG 2>&1
        elif [ "${element}" == "sic" ] ; then
            OUTPUT="${OUTPUT_DIR}/${element}.${FORECAST_DATE}.mp4"
            echo "Producing SIC error video for $FORECAST_DATE (${OUTPUT})"
            icenet_plot_sic_error -v -o $OUTPUT \
                $HEMI $FORECAST_FILE $FORECAST_DATE >> $SICERR_LOG 2>&1
        fi
    done
done

# stitch together metric plots if requested
if [[ "${ROLLING}" == true ]]; then
    for element in "${METRICS[@]}"
    do
        if [ "${element}" == "sic" ] ; then
            continue
        elif [ "${element}" == "binacc" ] ; then
            echo "Producing rolling binary accuracy plot (${OUTPUT})"
            LOGFILE="${BINACC_LOG}"
        elif [ "${element}" == "sie" ] ; then
            echo "Producing rolling sea ice extent error plot (${OUTPUT})"
            LOGFILE="${SIE_LOG}"
        elif [ "${element}" == "mae" ] ; then
            echo "Producing rolling MAE plot (${OUTPUT})"
            LOGFILE="${MAE_LOG}"
        elif [ "${element}" == "mse" ] ; then
            echo "Producing rolling MSE plot (${OUTPUT})"
            LOGFILE="${MSE_LOG}"
        elif [ "${element}" == "rmse" ] ; then
            echo "Producing rolling RMSE plot (${OUTPUT})"
            LOGFILE="${RMSE_LOG}"
        fi
        OUTPUT="${OUTPUT_DIR}/${element}.mp4"
        ffmpeg -framerate 10 -y -pattern_type glob -i "${OUTPUT_DIR}/${element}.*.png" \
            -vcodec libx264 -pix_fmt yuv420p $OUTPUT >> $LOGFILE
    done
fi

# produce leadtime averaged plots
if [[ "${LEADTIME_AVG}" == true ]]; then
    for element in "${METRICS[@]}"
    do
        if [ "${element}" == "sic" ] ; then
            continue
        elif [ "${element}" == "binacc" ] ; then
            echo "Producing leadtime averaged binary accuracy plot (${OUTPUT})"
            LOGFILE="${BINACC_LOG}"
        elif [ "${element}" == "sie" ] ; then
            echo "Producing leadtime averaged sea ice extent error plot (${OUTPUT})"
            LOGFILE="${SIE_LOG}"
        elif [ "${element}" == "mae" ] ; then
            echo "Producing leadtime averaged MAE plot (${OUTPUT})"
            LOGFILE="${MAE_LOG}"
        elif [ "${element}" == "mse" ] ; then
            echo "Producing leadtime averaged MSE plot (${OUTPUT})"
            LOGFILE="${MSE_LOG}"
        elif [ "${element}" == "rmse" ] ; then
            echo "Producing leadtime averaged RMSE plot (${OUTPUT})"
            LOGFILE="${RMSE_LOG}"
        fi
        OUTPUT="${OUTPUT_DIR}/${element}_leadtime_avg.png"
        icenet_plot_leadtime_avg $HEMI $FORECAST_FILE \
            -m $element -ao "all" -s -sm 1 $E_FLAG \
            -o $OUTPUT >> $LOGFILE
    done
fi
