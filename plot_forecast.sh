#!/usr/bin/env bash

source ENVS

if [ $# -lt 1 ] || [ "$1" == "-h" ]; then
    echo -e "\nUsage $0 <forecast_name>"
    echo -e "\nArguments"
    echo "<forecast_name>     name of forecast"
    echo -e "\nOptions"
    echo "-m <metrics>        string of metrics separated by commas, by default \"binacc,sie,mae,rmse,sic\". Options: \"binacc\", \"sie\", \"mae\", \"mse\", \"rmse\", \"sic\""
    echo "-r <region>         region arguments, by default uses full hemisphere"
    echo "-e                  compare forecast performance with ECMWF"
    echo "-l                  produce leadtime averaged plots"
    echo "-v                  produce video using the individual metric plots by stitching them together with ffmpeg"
    echo "-t <threshold>      SIC threshold to use (must be between 0 and 1), by default 0.15"
    echo "-g <grid_area_size> grid area resolution to use - i.e. the length of the sides in km, by default 25 (i.e. 25km^2)"
    echo "-o <output_dir>     output directory path to store plots, by default \"plot/<forecast_name>\""
    echo -e "\nList of outputs generated"
    echo "* If \"binacc\" is included in the requested metrics, will generate all binary accuracy plots for dates in <forecast_name>.csv"
    echo "- these will be saved in the format \"<output_dir>/binacc.t_<threshold>.<date>.png\""
    echo "If \"-l\" is passed, leadtime averaged plots for binary accuracy will be generated too:"
    echo "    - averaging over all: \"<output_dir>/binacc.t_<threshold>_leadtime_avg_all.png\""
    echo "    - averaging by month and for initalisation date: \"<output_dir>/binacc.t_<threshold>_leadtime_avg_init_month.png\""
    echo "    - averaging by day and for initalisation date: \"<output_dir>/binacc.t_<threshold>_leadtime_avg_init_day.png\""
    echo "    - averaging by month and for target date: \"<output_dir>/binacc.t_<threshold>_leadtime_avg_target_month.png\""
    echo "    - averaging by day and for target date: \"<output_dir>/binacc.t_<threshold>_leadtime_avg_target_day.png\""
    echo "If \"-v\" is passed, a video will be produced to stitch all these plots together and saved in \"<output_dir>/binacc.t_<threshold>.mp4\""
    echo "* If \"sie\" is included in the requested metrics, will generate all SIE error plots for dates in <forecast_name>.csv"
    echo "(these will be saved in the format \"<output_dir>/sie.t_<threshold>.g_<grid_area_size>.<date>.png\")"
    echo "If \"-l\" is passed, leadtime averaged plots for SIE error will be generated too:"
    echo "    - averaging over all: \"<output_dir>/sie.t_<threshold>.g_<grid_area_size>_leadtime_avg_all.png\""
    echo "    - averaging by month and for initalisation date: \"<output_dir>/sie.t_<threshold>.g_<grid_area_size>_leadtime_avg_init_month.png\""
    echo "    - averaging by day and for initalisation date: \"<output_dir>/sie.t_<threshold>.g_<grid_area_size>_leadtime_avg_init_day.png\""
    echo "    - averaging by month and for target date: \"<output_dir>/sie.t_<threshold>.g_<grid_area_size>_leadtime_avg_target_month.png\""
    echo "    - averaging by day and for target date: \"<output_dir>/sie.t_<threshold>.g_<grid_area_size>_leadtime_avg_target_day.png\""
    echo "If \"-v\" is passed, a video will be produced to stitch all these plots together and saved in \"<output_dir>/sie.t_<threshold>.g_<grid_area_size>.mp4\""
    echo "* If \"mae\", \"mse\", or \"rmse\" is included in the requested metrics, will generate all MAE, MSE, or RMSE plots for dates in <forecast_name>.csv"
    echo "the names for the plots follow a similar convention as above but without the threshold or grid-area-size being saved in the name..."
    echo "for instance, for a given <metric>, these will be saved in the format \"<output_dir>/<metric>.<date>.png\""
    echo "If \"-l\" is passed, leadtime averaged plots for <metric> will be generated too:"
    echo "    - averaging over all: \"<output_dir>/<metric>_leadtime_avg_all.png\""
    echo "    - averaging by month and for initalisation date: \"<output_dir>/<metric>_leadtime_avg_init_month.png\""
    echo "    - averaging by day and for initalisation date: \"<output_dir>/<metric>_leadtime_avg_init_day.png\""
    echo "    - averaging by month and for target date: \"<output_dir>/<metric>_leadtime_avg_target_month.png\""
    echo "    - averaging by day and for target date: \"<output_dir>/<metric>_leadtime_avg_target_day.png\""
    echo "Note that if $\"-e\" is passed, all of these will have \"_comp\" after \"avg\""
    echo "The plot of the standard deviation of the metric for each forecast will also be generated"
    echo "If \"-v\" is passed, a video will be produced to stitch all these plots together and saved in \"<output_dir>/<metric>.mp4\""
    echo "* If \"sic\" is included in the requested metrics, will generate all SIC error videos for dates in <forecast_name>.csv"
    echo "(these will be saved in the format \"<output_dir>/sic.<date>.mp4\")"
    exit 1
fi

# default values
METRICS="binacc,sic"
REGION=""
ECMWF="false"
LEADTIME_AVG="false"
VIDEO="false"
THRESHOLD="-t 0.15"
GRID_AREA_SIZE="-ga 25"
REQUESTED_OUTPUT_DIR=""
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
        o)  REQUESTED_OUTPUT_DIR=${OPTARG}
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

# echo "Leftovers from getopt: $@"

FORECAST_NAME="$1"
FORECAST_FILE="results/predict/${FORECAST_NAME}.nc"
LOG_PREFIX="logs/${FORECAST_NAME}"
BINACC_LOG="${LOG_PREFIX}.binacc.log"
SIE_LOG="${LOG_PREFIX}.sie.log"
MAE_LOG="${LOG_PREFIX}.mae.log"
MSE_LOG="${LOG_PREFIX}.mse.log"
RMSE_LOG="${LOG_PREFIX}.rmse.log"
SICERR_LOG="${LOG_PREFIX}.sic.log"

GROUND_TRUTH_DS=`jq -r 'first(.sources[]).dataset_config' loader.${FORECAST_NAME}.json`

if [ "${REQUESTED_OUTPUT_DIR}" == "" ]; then
    OUTPUT_DIR="plot/${FORECAST_NAME}"
else
    OUTPUT_DIR=${REQUESTED_OUTPUT_DIR}
fi

# if [ -d $OUTPUT_DIR ]; then
#     # remove existing log files if they exist
#     rm -v -f $BINACC_LOG $SIE_LOG $MAE_LOG $MSE_LOG $RMSE_LOG $SICERR_LOG
# fi
mkdir -p $OUTPUT_DIR

echo "Saving plots in ${OUTPUT_DIR}"
echo "Reading ${FORECAST_NAME}.csv"

# create metric plots for each forecast date
cat ${FORECAST_NAME}.csv | while read -r FORECAST_DATE; do
    for element in "${METRICS[@]}"
    do
        OUTPUT="${OUTPUT_DIR}/${element}.${FORECAST_DATE}.png"
        if [ "${element}" == "binacc" ]; then
            OUTPUT="${OUTPUT_DIR}/${element}.t_${THRESHOLD:3}.${FORECAST_DATE}.png"
            echo "Producing binary accuracy plot for $FORECAST_DATE (${OUTPUT})"
            icenet_plot_bin_accuracy -b $E_FLAG -v $REGION -o $OUTPUT $THRESHOLD \
                $GROUND_TRUTH_DS $FORECAST_FILE $FORECAST_DATE >> $BINACC_LOG 2>&1
        elif [ "${element}" == "sie" ]; then
            OUTPUT="${OUTPUT_DIR}/${element}.t_${THRESHOLD:3}.ga_${GRID_AREA_SIZE:4}.${FORECAST_DATE}.png"
            echo "Producing sea ice extent error plot for $FORECAST_DATE (${OUTPUT})"
            icenet_plot_sie_error -b $E_FLAG -v $REGION -o $OUTPUT $THRESHOLD $GRID_AREA_SIZE \
                $GROUND_TRUTH_DS $FORECAST_FILE $FORECAST_DATE >> $SIE_LOG 2>&1
        elif [ "${element}" == "mae" ]; then
            echo "Producing MAE plot for $FORECAST_DATE (${OUTPUT})"
            icenet_plot_metrics -b $E_FLAG -v $REGION -m $element -o $OUTPUT \
                $GROUND_TRUTH_DS $FORECAST_FILE $FORECAST_DATE >> $MAE_LOG 2>&1
        elif [ "${element}" == "mse" ]; then
            echo "Producing MSE plot for $FORECAST_DATE (${OUTPUT})"
            icenet_plot_metrics -b $E_FLAG -v $REGION -m $element -o $OUTPUT \
                $GROUND_TRUTH_DS $FORECAST_FILE $FORECAST_DATE >> $MSE_LOG 2>&1
        elif [ "${element}" == "rmse" ]; then
            echo "Producing RMSE plot for $FORECAST_DATE (${OUTPUT})"
            icenet_plot_metrics -b $E_FLAG -v $REGION -m $element -o $OUTPUT \
                $GROUND_TRUTH_DS $FORECAST_FILE $FORECAST_DATE >> $RMSE_LOG 2>&1
        elif [ "${element}" == "sic" ]; then
            OUTPUT="${OUTPUT_DIR}/${element}.${FORECAST_DATE}.mp4"
            echo "Producing SIC error video for $FORECAST_DATE (${OUTPUT})"
            icenet_plot_sic_error -v $REGION -o $OUTPUT \
                $GROUND_TRUTH_DS $FORECAST_FILE $FORECAST_DATE >> $SICERR_LOG 2>&1
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
        PATH_START="${OUTPUT_DIR}/${element}"
        if [ "${element}" == "binacc" ]; then
            echo "Producing leadtime averaged binary accuracy plots..."
            PATH_START="${PATH_START}.t_${THRESHOLD:3}"
            LOGFILE="${BINACC_LOG}"
        elif [ "${element}" == "sie" ]; then
            echo "Producing leadtime averaged sea ice extent error plots..."
            PATH_START="${PATH_START}.t_${THRESHOLD:3}.ga_${GRID_AREA_SIZE:4}"
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
            DATA_PATH="${PATH_START}_leadtime_avg_df_comp.csv"
            OUTPUT_PATH_START="${PATH_START}_leadtime_avg_comp"
        else
            DATA_PATH="${PATH_START}_leadtime_avg_df.csv"
            OUTPUT_PATH_START="${PATH_START}_leadtime_avg"
        fi
        echo "Will produce metrics dataframe in ${DATA_PATH}"
        echo "Plots produced:"
        # averaging over all
        OUTPUT="${OUTPUT_PATH_START}_all.png"
        icenet_plot_leadtime_avg $GROUND_TRUTH_DS $FORECAST_FILE $REGION \
            -m $element -ao "all" -s -sm 1 $E_FLAG $THRESHOLD $GRID_AREA_SIZE \
            -dp $DATA_PATH -o $OUTPUT >> $LOGFILE 2>&1
        echo "* ${OUTPUT}"
        ##### initialisation day
        # averaging over monthly
        OUTPUT="${OUTPUT_PATH_START}_init_month.png"
        icenet_plot_leadtime_avg $GROUND_TRUTH_DS $FORECAST_FILE $REGION \
            -m $element -ao "month" -s $E_FLAG $THRESHOLD $GRID_AREA_SIZE \
            -dp $DATA_PATH -o $OUTPUT >> $LOGFILE 2>&1
        echo "* ${OUTPUT}"
        # averaging over daily
        OUTPUT="${OUTPUT_PATH_START}_init_day.png"
        icenet_plot_leadtime_avg $GROUND_TRUTH_DS $FORECAST_FILE $REGION \
            -m $element -ao "day" -s $E_FLAG $THRESHOLD $GRID_AREA_SIZE \
            -dp $DATA_PATH -o $OUTPUT >> $LOGFILE 2>&1
        echo "* ${OUTPUT}"
        ##### target day
        # averaging over monthly
        OUTPUT="${OUTPUT_PATH_START}_target_month.png"
        icenet_plot_leadtime_avg $GROUND_TRUTH_DS $FORECAST_FILE $REGION \
            -m $element -ao "month" -s -td $E_FLAG $THRESHOLD $GRID_AREA_SIZE \
            -dp $DATA_PATH -o $OUTPUT >> $LOGFILE 2>&1
        echo "* ${OUTPUT}"
        # averaging over daily
        OUTPUT="${OUTPUT_PATH_START}_target_day.png"
        icenet_plot_leadtime_avg $GROUND_TRUTH_DS $FORECAST_FILE $REGION \
            -m $element -ao "day" -s -td $E_FLAG $THRESHOLD $GRID_AREA_SIZE \
            -dp $DATA_PATH -o $OUTPUT >> $LOGFILE 2>&1
        echo "* ${OUTPUT}"
    done
fi

# stitch together metric plots if requested
if [[ "${VIDEO}" == true ]]; then
    for element in "${METRICS[@]}"
    do
        if [ "${element}" == "sic" ]; then
            continue
        fi
        PATH_START="${OUTPUT_DIR}/${element}"
        # add to PATH_SPART if we're working with binacc or SIE
        if [ "${element}" == "binacc" ]; then
            PATH_START="${PATH_START}.t_${THRESHOLD:3}"  
        elif [ "${element}" == "sie" ]; then
            PATH_START="${PATH_START}.t_${THRESHOLD:3}.ga_${GRID_AREA_SIZE:4}"
        fi
        # print out where the plot will be saved
        OUTPUT="${PATH_START}.mp4"
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
            INPUTS="${PATH_START}*.png"
        else
            INPUTS="${PATH_START}.*.png"
        fi
        ffmpeg -framerate 10 -y -pattern_type glob -i "${INPUTS}" \
            -vcodec libx264 -pix_fmt yuv420p $OUTPUT >> $LOGFILE 2>&1
    done
fi
