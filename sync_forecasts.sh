#!/bin/bash

# Group icenet forecast outputs nearly by year for
# delivery by the Polar Data Centre.

# Get the absolute path for this script
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

ICENET_2_PIPELINE=${1:-"${SCRIPT_DIR}"}
SYNC_PATH=${2:-"/data/twins/pub/sic/icenet/forecasts/"}
MODEL_NAME=${3:-"exp23"}

# Loop over prediction forecasts
for dir in "${ICENET_2_PIPELINE}"/results/forecasts/fc.*; do
    # Only proceed if a directory
    [[ -d "$dir" ]] || continue

    # Extract filename and hemisphere from dir name
    name=$(basename "$dir")
    hemisphere="${name##*_}"

    # Extract year from forecast dir name (e.g., fc.2025-08-01_north -> 2025)
    year="$(basename $dir | cut -d. -f2 | cut -d- -f1)/"

    # Sync across
    destination_path="${SYNC_PATH}/${MODEL_NAME}_${hemisphere}/${year}"
    mkdir -p "${destination_path}"
    echo "Copying ${dir}/* to ${destination_path}"
    rsync -av "$dir"/* "${destination_path}"
done
