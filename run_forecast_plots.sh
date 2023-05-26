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
    echo "-e                  compare forecast performance with ECMWF"
    echo "-l                  produce leadtime averaged plots"
    echo "-v                  produce video using the individual metric plots by stitching them together with ffmpeg"
    echo "-t <threshold>      SIC threshold to use (must be between 0 and 1), by default 0.15"
    echo "-g <grid_area_size> grid area resolution to use - i.e. the length of the sides in km, by default 25 (i.e. 25km^2)"
    echo "-o <output_dir>     output directory path to store plots, by default \"plot/<forecast_name>\""
    exit 1
fi

# default values
METRICS="binacc,sic"
REGION=""
ECMWF="false"
LEADTIME_AVG="false"
VIDEO="false"
THRESHOLD="-t 0.15"
GRID_AREA_SIZE="-ga ${OPTARG}"
OUTPUT_DIR="plot/${FORECAST_NAME}"
OPTIND=1
while getopts "m:r:elvt:g:o:" opt; do
    case "$opt" in
        m)  METRICS=${OPTARG} ;;
        r)  REGION="-r ${OPTARG}" ;;
        e)  ECMWF="true" ;;
        l)  LEADTIME_AVG="true" ;;
        v)  VIDEO="true" ;;
        t)  THRESHOLD="-t ${OPTARG}" ;;
        g)  GRID_AREA_SIZE="-ga ${OPTARG}" ;;
        o)  OUTPUT_DIR=${OPTARG}
    esac
done

# split on commas
METRICS=(${METRICS//,/ })

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

if [ -d $OUTPUT_DIR ]; then
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
        if [ "${element}" == "binacc" ]; then
            OUTPUT="${OUTPUT_DIR}/${element}_${THRESHOLD:3}.${FORECAST_DATE}.png"
            echo "Producing binary accuracy plot for $FORECAST_DATE (${OUTPUT})"
            icenet_plot_bin_accuracy -b $E_FLAG -v $REGION -o $OUTPUT $THRESHOLD \
                $HEMI $FORECAST_FILE $FORECAST_DATE >> $BINACC_LOG 2>&1
        elif [ "${element}" == "sie" ]; then
            OUTPUT="${OUTPUT_DIR}/${element}_${THRESHOLD:3}.${FORECAST_DATE}.png"
            echo "Producing sea ice extent error plot for $FORECAST_DATE (${OUTPUT})"
            icenet_plot_sie_error -b $E_FLAG -v $REGION -o $OUTPUT $THRESHOLD $GRID_AREA_SIZE \
                $HEMI $FORECAST_FILE $FORECAST_DATE >> $SIE_LOG 2>&1
        elif [ "${element}" == "mae" ]; then
            echo "Producing MAE plot for $FORECAST_DATE (${OUTPUT})"
            icenet_plot_metrics -b $E_FLAG -v $REGION -m "MAE" -o $OUTPUT \
                $HEMI $FORECAST_FILE $FORECAST_DATE >> $MAE_LOG 2>&1
        elif [ "${element}" == "mse" ]; then
            echo "Producing MSE plot for $FORECAST_DATE (${OUTPUT})"
            icenet_plot_metrics -b $E_FLAG -v $REGION -m "MSE" -o $OUTPUT \
                $HEMI $FORECAST_FILE $FORECAST_DATE >> $MSE_LOG 2>&1
        elif [ "${element}" == "rmse" ]; then
            echo "Producing RMSE plot for $FORECAST_DATE (${OUTPUT})"
            icenet_plot_metrics -b $E_FLAG -v $REGION -m "RMSE" -o $OUTPUT \
                $HEMI $FORECAST_FILE $FORECAST_DATE >> $RMSE_LOG 2>&1
        elif [ "${element}" == "sic" ]; then
            OUTPUT="${OUTPUT_DIR}/${element}.${FORECAST_DATE}.mp4"
            echo "Producing SIC error video for $FORECAST_DATE (${OUTPUT})"
            icenet_plot_sic_error -v $REGION -o $OUTPUT \
                $HEMI $FORECAST_FILE $FORECAST_DATE >> $SICERR_LOG 2>&1
        fi
    done
done

# produce leadtime averaged plots
if [[ "${LEADTIME_AVG}" == true ]]; then
    for element in "${METRICS[@]}"
    do
        if [ "${element}" == "sic" ]; then
            continue
        fi
        if [ "${element}" == "binacc" ]; then
            echo "Producing leadtime averaged binary accuracy plots..."
            LOGFILE="${BINACC_LOG}"
        elif [ "${element}" == "sie" ]; then
            echo "Producing leadtime averaged sea ice extent error plots..."
            LOGFILE="${SIE_LOG}"
        elif [ "${element}" == "mae" ]; then
            echo "Producing leadtime averaged MAE plots..."
            LOGFILE="${MAE_LOG}"
        elif [ "${element}" == "mse" ]; then
            echo "Producing leadtime averaged MSE plots..."
            LOGFILE="${MSE_LOG}"
        elif [ "${element}" == "rmse" ]; then
            echo "Producing leadtime averaged RMSE plots..."
            LOGFILE="${RMSE_LOG}"
        fi
        # determining the path to save metrics dataframe and the beginning of the output paths
        if [[ "${ECMWF}" == true ]]; then
            DATA_PATH="${OUTPUT_DIR}/${element}_leadtime_avg_df_comp.csv"
            OUTPUT_PATH_START="${OUTPUT_DIR}/${element}_leadtime_avg_comp"
        else
            DATA_PATH="${OUTPUT_DIR}/${element}_leadtime_avg_df.csv"
            OUTPUT_PATH_START="${OUTPUT_DIR}/${element}_leadtime_avg"
        fi
        echo "Will produce metrics dataframe in ${DATA_PATH}"
        echo "Plots saved in:"
        # averaging over all
        OUTPUT="${OUTPUT_PATH_START}_all.png"
        echo "- ${OUTPUT}"
        icenet_plot_leadtime_avg $HEMI $FORECAST_FILE $REGION \
            -m $element -ao "all" -s -sm 1 $E_FLAG $THRESHOLD $GRID_AREA_SIZE \
            -dp $DATA_PATH -o $OUTPUT >> $LOGFILE
        ##### initialisation day
        # averaging over monthly
        OUTPUT="${OUTPUT_PATH_START}_init_month.png"
        echo "- ${OUTPUT}"
        icenet_plot_leadtime_avg $HEMI $FORECAST_FILE $REGION \
            -m $element -ao "month" -s $E_FLAG $THRESHOLD $GRID_AREA_SIZE \
            -dp $DATA_PATH -o $OUTPUT >> $LOGFILE
        # averaging over daily
        OUTPUT="${OUTPUT_PATH_START}_init_day.png"
        echo "- ${OUTPUT}"
        icenet_plot_leadtime_avg $HEMI $FORECAST_FILE $REGION \
            -m $element -ao "day" -s $E_FLAG $THRESHOLD $GRID_AREA_SIZE \
            -dp $DATA_PATH -o $OUTPUT >> $LOGFILE
        ##### target day
        # averaging over monthly
        OUTPUT="${OUTPUT_PATH_START}_target_month.png"
        echo "- ${OUTPUT}"
        icenet_plot_leadtime_avg $HEMI $FORECAST_FILE $REGION \
            -m $element -ao "month" -s -td $E_FLAG $THRESHOLD $GRID_AREA_SIZE \
            -dp $DATA_PATH -o $OUTPUT >> $LOGFILE
        # averaging over daily
        OUTPUT="${OUTPUT_PATH_START}_target_day.png"
        echo "- ${OUTPUT}"
        icenet_plot_leadtime_avg $HEMI $FORECAST_FILE $REGION \
            -m $element -ao "day" -s -td $E_FLAG $THRESHOLD $GRID_AREA_SIZE \
            -dp $DATA_PATH -o $OUTPUT >> $LOGFILE
    done
fi

# stitch together metric plots if requested
if [[ "${VIDEO}" == true ]]; then
    for element in "${METRICS[@]}"
    do
        if [ "${element}" == "sic" ]; then
            continue
        fi
        OUTPUT="${OUTPUT_DIR}/${element}.mp4"
        if [ "${element}" == "binacc" ]; then
            echo "Producing rolling binary accuracy plot (${OUTPUT})"
            LOGFILE="${BINACC_LOG}"
        elif [ "${element}" == "sie" ]; then
            echo "Producing rolling sea ice extent error plot (${OUTPUT})"
            LOGFILE="${SIE_LOG}"
        elif [ "${element}" == "mae" ]; then
            echo "Producing rolling MAE plot (${OUTPUT})"
            LOGFILE="${MAE_LOG}"
        elif [ "${element}" == "mse" ]; then
            echo "Producing rolling MSE plot (${OUTPUT})"
            LOGFILE="${MSE_LOG}"
        elif [ "${element}" == "rmse" ]; then
            echo "Producing rolling RMSE plot (${OUTPUT})"
            LOGFILE="${RMSE_LOG}"
        fi
        # determine whether or not to stitch the leadtime averaged plots
        if [[ "${LEADTIME_AVG}" == true ]]; then
            INPUTS="${OUTPUT_DIR}/${element}*.png"
        else
            INPUTS="${OUTPUT_DIR}/${element}.*.png"
        fi
        ffmpeg -framerate 10 -y -pattern_type glob -i "${INPUTS}" \
            -vcodec libx264 -pix_fmt yuv420p $OUTPUT >> $LOGFILE
    done
fi
