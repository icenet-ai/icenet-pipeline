#!/usr/bin/env bash

set -e -o pipefail

FORECAST_NAME="$1"
REGION="$2"

OUTPUT_DIR="results/forecasts/$FORECAST_NAME"
LOG_DIR="log/forecasts/$FORECAST_NAME"

FORECAST_FILE="results/predict/${FORECAST_NAME}.nc"
HEMI=`echo $FORECAST_NAME | sed -r 's/^.+_(north|south)$/\1/'`

if [ $# -lt 1 ] || [ "$1" == "-h" ]; then
  echo "$0 <forecast name w/hemi> [region]"
  exit 1
fi

[ ! -z $REGION ] && REGION="-r $REGION"

if ! [[ $HEMI =~ ^(north|south)$ ]]; then
  echo "Hemisphere from $FORECAST_NAME not available, raise an issue"
  exit 1
fi


function produce_docs {
  local DIR=$1

  cp template_LICENSE.md ${DIR}/LICENSE.md
  cp template_README.md ${DIR}/README.md
}


for WORKING_DIR in "$OUTPUT_DIR" "$LOG_DIR"; do
  if [ -d $WORKING_DIR ]; then
    echo "Output directory $WORKING_DIR already exists, removing"
    echo rm -rv $OUTPUT_DIR
  fi
done

echo "Making $OUTPUT_DIR"
mkdir -p OUTPUT_DIR

for DATE_FORECAST in $( cat ${FORECAST_NAME}.csv | tail -n 1 ); do
  DATE_DIR="$OUTPUT_DIR/$DATE_FORECAST"
  echo "Making $DATE_DIR"
  mkdir -p $DATE_DIR

  echo "Producing single output file for date forecast"
  python -c 'import xarray; xarray.open_dataset("'$FORECAST_FILE'").sel(time="'$DATE_FORECAST'").to_netcdf("'$DATE_DIR'/'$DATE_FORECAST'.nc")'

  echo "Producing geotiffs from that file"
  icenet_output_geotiff -o $DATE_DIR $FORECAST_FILE $DATE_FORECAST 1..93

  echo "Producing movie file of raw video"
  icenet_plot_forecast $REGION -o $DATE_DIR -l 1..93 -f mp4 $HEMI $FORECAST_FILE $DATE_FORECAST

  echo "Producing stills for manual composition (with coastlines)"
  icenet_plot_forecast $REGION -o $DATE_DIR -l 1..93 $HEMI $FORECAST_FILE $DATE_FORECAST

  produce_docs
done

#icenet_plot_bin_accuracy -v -b -e -r 125,190,170,235 -o test.png north results/predict/lanc23.2023-02-13_north.nc 2014-02-13

}