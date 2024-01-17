#!/usr/bin/env bash

source ENVS

if [ $# -lt 2 ] || [ "$1" == "-h" ]; then
    echo -e "\nUsage $0 <dates_file> <dataset_config>"
    echo -e "\nArguments"
    echo "<dates_file>     file containing dates to generate plots for"
    echo "<dataset_config> dataset config for the dataset"
    echo -e "\nOptions"
    echo "-v               produce video using the individual metric plots by stitching them together with ffmpeg"
    echo "-o <output_dir>  directory path to store plots, by default \"<dataset_config>_input_variables\""
    echo -e "\nThe script generate the inputs for each date in the file provided"
    echo "for the input variables recorded in the dataset_config."
    exit 1
fi

VIDEO="false"
REQUESTED_OUTPUT_DIR=""
while getopts "vo:" opt; do
    case "$opt" in
        v)  VIDEO="true" ;;
        o)  REQUESTED_OUTPUT_DIR=${OPTARG}
    esac
done

shift $((OPTIND-1))

DATE_FILE="$1"
DATASET_CONFIG_PATH="$2"

if [ "${REQUESTED_OUTPUT_DIR}" == "" ]; then
    OUTPUT_DIR="${DATASET_CONFIG_PATH}_input_variables"
else
    OUTPUT_DIR=${REQUESTED_OUTPUT_DIR}
fi

mkdir -p $OUTPUT_DIR

echo "Saving input variable plots in ${OUTPUT_DIR}"

# loop through dates in DATE_FILE and plot the input variables
while read date; do
    icenet_plot_input ${DATASET_CONFIG_PATH} ${date} "${OUTPUT_DIR}/${date}_input.png"
    echo "Saved plot for ${date} in \"${OUTPUT_DIR}/${date}_input.png\""
done < ${DATE_FILE}

# stitch together metric plots if requested
if [[ "${VIDEO}" == true ]]; then
    INPUTS="${OUTPUT_DIR}*.png"
    OUTPUT="${OUTPUT_DIR}/inputs.mp4" 
    ffmpeg -framerate 10 -y -pattern_type glob -i "${INPUTS}" \
            -vcodec libx264 -pix_fmt yuv420p $OUTPUT
fi