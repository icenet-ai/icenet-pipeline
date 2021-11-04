#!/usr/bin/env bash

if [[ $# -lt 3 ]]; then
    echo "Usage $0 NETWORK DATASET NAME"
    exit 1
fi

echo "ARGS: $@"

ENSEMBLE_TARGET="slurm"
ENSEMBLE_SWITCH=""
ENSEMBLE_ARGS=""

while getopts ":b:df:m:p:" opt; do
  case "$opt" in
    b)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_batch=$OPTARG ";;
    d)  ENSEMBLE_TARGET="dummy";;
    f)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_filter_factor=$OPTARG ";;
    m)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}mem=$OPTARG ";;
    p)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_prep=$OPTARG ";;
  esac
done

[ ! -z "$ENSEMBLE_ARGS" ] && ENSEMBLE_SWITCH="-x"
shift $((OPTIND-1))

[[ "${1:-}" = "--" ]] && shift

echo "ARGS = $ENSEMBLE_SWITCH $ENSEMBLE_ARGS, Leftovers: $@"

NETWORK="$1"
DATASET="$2"
NAME="$3"

PREDICT_CONFIG=`mktemp -p . --suffix ".predict"`

sed -r \
    -e "s/NETWORK/${NETWORK}/g" \
    -e "s/DATASET/${DATASET}/g" \
    -e "s/NAME/${NAME}/g" \
 ensemble/predict.tmpl.yaml >$PREDICT_CONFIG

COMMAND="model_ensemble $PREDICT_CONFIG $ENSEMBLE_TARGET $ENSEMBLE_SWITCH $ENSEMBLE_ARGS"
echo "Running $COMMAND"
$COMMAND
echo "Removing temporary configuration $PREDICT_CONFIG"
rm $PREDICT_CONFIG
