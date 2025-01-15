#!/usr/bin/env bash

set -e -o pipefail

FORECAST_NAME="$1"
REGION="$2"

OUTPUT_DIR="results/forecasts/$FORECAST_NAME"
LOG_DIR="log/forecasts/$FORECAST_NAME"

FORECAST_FILE="results/predict/${FORECAST_NAME}.nc"
FORECAST_LENGTH=`python -c 'import xarray as xr; print(int(xr.open_dataset("'$FORECAST_FILE'").leadtime.max()))'`
HEMI=`echo $FORECAST_NAME | sed -r 's/^.+\.(north|south)$/\1/'`

GROUND_TRUTH_DS=`jq -r 'first(.sources[]).dataset_config' loader.${FORECAST_NAME}.json`
GROUND_TRUTH_DIR=`dirname $( jq -r '.data._var_files.siconca[0]' $GROUND_TRUTH_DS )`

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

function rename_gfx {
  GFX_DIR="$1"
  F_PREFIX="$2"
  F_GLOB="$3"

  for NOM in $( find $GFX_DIR -name "${F_PREFIX}${F_GLOB}" ); do
    NOM_FILENAME=`basename $NOM`
    mv -v $NOM ${GFX_DIR}/${NOM_FILENAME#${F_PREFIX}}
  done
}

for WORKING_DIR in "$OUTPUT_DIR" "$LOG_DIR"; do
  if [ -d $WORKING_DIR ]; then
    echo "Output directory $WORKING_DIR already exists, removing"
    rm -rv $OUTPUT_DIR
  fi
done

echo "Making $OUTPUT_DIR"
mkdir -p $OUTPUT_DIR

for DATE_FORECAST in $( cat ${FORECAST_NAME}.csv ); do
  DATE_DIR="$OUTPUT_DIR/$DATE_FORECAST"
  echo "Making $DATE_DIR for forecast date $DATE_FORECAST"
  mkdir -p $DATE_DIR

  echo "Producing single output file for date forecast"
  python -c 'import xarray; xarray.open_dataset("'$FORECAST_FILE'").sel(time=slice("'$DATE_FORECAST'", "'$DATE_FORECAST'")).to_netcdf("'$DATE_DIR'/'$DATE_FORECAST'.nc")'

  echo "Producing geotiffs from that file"
  icenet_output_geotiff -o $DATE_DIR $FORECAST_FILE $DATE_FORECAST 1..$FORECAST_LENGTH
  rename_gfx $DATE_DIR "${FORECAST_NAME}.${DATE_FORECAST}." '*.tiff'

  echo "Producing movie file of raw video"
  icenet_plot_forecast $REGION -o $DATE_DIR -l 1..$FORECAST_LENGTH -f mp4 $GROUND_TRUTH_DS $FORECAST_FILE $DATE_FORECAST
  rename_gfx $DATE_DIR "${FORECAST_NAME}.${DATE_FORECAST}." '*.mp4'

  echo "Producing stills for manual composition (with coastlines)"
  icenet_plot_forecast $REGION -o $DATE_DIR -l 1..$FORECAST_LENGTH $GROUND_TRUTH_DS $FORECAST_FILE $DATE_FORECAST
  # Removed -c:v libx264
  ffmpeg -framerate 5 -pattern_type glob -i ${DATE_DIR}'/'${FORECAST_NAME}'.*.png' ${DATE_DIR}/${FORECAST_NAME}.mp4
  rename_gfx $DATE_DIR "${FORECAST_NAME}.${DATE_FORECAST}." '*.png'

  echo "Producing movie and stills of ensemble standard deviation in predictions"
  icenet_plot_forecast $REGION -s -o $DATE_DIR -l 1..$FORECAST_LENGTH -f mp4 $GROUND_TRUTH_DS $FORECAST_FILE $DATE_FORECAST
  rename_gfx $DATE_DIR "${FORECAST_NAME}.${DATE_FORECAST}." '*.stddev.mp4'

  icenet_plot_forecast $REGION -s -o $DATE_DIR -l 1..$FORECAST_LENGTH $GROUND_TRUTH_DS $FORECAST_FILE $DATE_FORECAST
  ffmpeg -framerate 5 -pattern_type glob -i ${DATE_DIR}'/'${FORECAST_NAME}'.*.stddev.png' ${DATE_DIR}/${FORECAST_NAME}.stddev.mp4
  rename_gfx $DATE_DIR "${FORECAST_NAME}.${DATE_FORECAST}." '*.stddev.png'

  produce_docs $DATE_DIR

  # TODO: copy docs to root folder
  # TODO: copy plot/ content for whole domain

  echo "Producing binary accuracy plots (these are meaningless forecasting into the future w.r.t the OSISAF data)"

  SIC_FILENAME="${GROUND_TRUTH_DIR}/`date +%Y`.nc"
  # Get the most recent day, sorry for ignoring all timezone information
  SIC_LATEST=`python -c 'import xarray; print(str(xarray.open_dataset("'$SIC_FILENAME'").time.values[-1])[0:10])'`

  if [[ `date --date="$SIC_LATEST" +%s` -gt `date --date="$DATE_FORECAST + 1 day" +%s` ]]; then
    echo "We have necessary SIC data ($SIC_LATEST) for forecast date $DATE_FORECAST"

    for THRESHOLD in 0.15 0.5 0.8 0.9; do
      icenet_plot_bin_accuracy $REGION -e -b -t $THRESHOLD \
        -o ${DATE_DIR}/bin_accuracy.${THRESHOLD}.png \
        $GROUND_TRUTH_DS $FORECAST_FILE $DATE_FORECAST
    done

    icenet_plot_metrics $REGION -e -b -s \
      -o ${DATE_DIR}/ \
      $GROUND_TRUTH_DS $FORECAST_FILE $DATE_FORECAST

    icenet_plot_sic_error $REGION \
      -o ${DATE_DIR}/${DATE_FORECAST}.sic_error.mp4 \
      $GROUND_TRUTH_DS $FORECAST_FILE $DATE_FORECAST

    icenet_plot_sie_error $REGION -e -b \
      -o ${DATE_DIR}/${DATE_FORECAST}.sie_error.25.png \
      $GROUND_TRUTH_DS $FORECAST_FILE $DATE_FORECAST
  else
    echo "We do not have observational SIC data ($SIC_LATEST) for plotting \
    forecast date $DATE_FORECAST"
  fi

  # Future uses - probably via another workflow:
  #  rsync to local destinations?
  #  Azure blob storage upload using az
done

echo "Done, enjoy your forecasts in $OUTPUT_DIR"
