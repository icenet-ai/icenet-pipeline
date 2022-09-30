#!/usr/bin/env bash

if [[ $# -lt 4 ]]; then
    echo "Usage $0 NETWORK DATASET NAME DATEFILE [LOADER]"
    exit 1
fi

. ENVS

echo "ARGS: $@"

DO_NOT_EXECUTE=0
ENSEMBLE_TARGET="slurm"
ENSEMBLE_SWITCH=""
ENSEMBLE_ARGS=""
TRAIN_IDENT=""

while getopts ":b:df:i:lm:p:x" opt; do
  case "$opt" in
    b)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_batch=$OPTARG ";;
    d)  ENSEMBLE_TARGET="dummy";;
    i)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_ident=$OPTARG ";;
    l)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_testset=false ";;
    m)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}mem=$OPTARG ";;
    p)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_prep=$OPTARG ";;
    x)  DO_NOT_EXECUTE=1
  esac
done

[ ! -z "$ENSEMBLE_ARGS" ] && ENSEMBLE_SWITCH="-x"
shift $((OPTIND-1))

[[ "${1:-}" = "--" ]] && shift

echo "ARGS = $ENSEMBLE_SWITCH $ENSEMBLE_ARGS, Leftovers: $@"

NETWORK="$1"
DATASET="$2"
NAME="$3"
DATEFILE="$4"
# TODO: really need to get rid of some of these symlinks
LOADER="${5:-${DATASET}}"

if [[ ! -f $DATEFILE ]]; then
    echo "Missing $DATEFILE which must be a regular file of dates"
    exit 1
fi

mkdir -p ensemble/${NAME}
ln -s `realpath ${DATEFILE}` ensemble/${NAME}/predict_dates.csv

PREDICT_CONFIG=`mktemp -p . --suffix ".predict"`

sed -r \
    -e "s/NETWORK/${NETWORK}/g" \
    -e "s/DATASET/${DATASET}/g" \
    -e "s/LOADER/${LOADER}/g" \
    -e "s/NAME/${NAME}/g" \
 ensemble/predict.tmpl.yaml >$PREDICT_CONFIG

# This now provided by ENVS
ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_filter_factor=$FILTER_FACTOR "

COMMAND="model_ensemble -v  $PREDICT_CONFIG $ENSEMBLE_TARGET $ENSEMBLE_SWITCH $ENSEMBLE_ARGS"
echo "Running $COMMAND"

if [[ $DO_NOT_EXECUTE == 0 ]]; then
    $COMMAND
    echo "Removing temporary configuration $PREDICT_CONFIG"
    rm $PREDICT_CONFIG
else
    echo "Configuration left in $PREDICT_CONFIG"
fi
