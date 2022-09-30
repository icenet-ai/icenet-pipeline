#!/usr/bin/env bash

if [[ $# -lt 3 ]]; then
    echo "Usage $0 LOADER DATASET NAME"
    exit 1
fi

. ENVS

echo "ARGS: $@"

ENSEMBLE_TARGET="slurm"
ENSEMBLE_SWITCH=""
ENSEMBLE_ARGS=""
ENSEMBLE_JOBS=1
ENSEMBLE_NTASKS=4

while getopts ":b:c:de:f:g:j:l:m:n:p:q:s:t:" opt; do
  case "$opt" in
    b)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_batch=$OPTARG ";;
    c)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}cluster=$OPTARG ";;
    d)  ENSEMBLE_TARGET="dummy";;
    e)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_epochs=$OPTARG ";;
    g)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}gpus=$OPTARG ";;
    j)  ENSEMBLE_JOBS=$OPTARG ;;
    l)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_preload=$OPTARG ";;
    m)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}mem=$OPTARG ";;
    n)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}nodelist=$OPTARG ";;
    p)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_prep=$OPTARG ";;
    q)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_queue=$OPTARG ";;
    s)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_strategy=$OPTARG ";;
    t)  ENSEMBLE_NTASKS=$OPTARG ;;
  esac
done

[ ! -z "$ENSEMBLE_ARGS" ] && ENSEMBLE_SWITCH="-x"
shift $((OPTIND-1))

[[ "${1:-}" = "--" ]] && shift

echo "ARGS = $ENSEMBLE_SWITCH $ENSEMBLE_ARGS, Leftovers: $@"

LOADER="$1"
DATASET="$2"
NAME="$3"

TRAIN_CONFIG=`mktemp -p . --suffix ".train"`

sed -r \
    -e "s/NAME/${NAME}/g" \
    -e "s/LOADER/${LOADER}/g" \
    -e "s/DATASET/${DATASET}/g" \
    -e "s/MAXJOBS/${ENSEMBLE_JOBS}/g" \
    -e "s/NTASKS/${ENSEMBLE_NTASKS}/g" \
 ensemble/train.tmpl.yaml >$TRAIN_CONFIG

# This now provided by ENVS
ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_filter_factor=$FILTER_FACTOR ";;

COMMAND="model_ensemble $TRAIN_CONFIG $ENSEMBLE_TARGET $ENSEMBLE_SWITCH $ENSEMBLE_ARGS"
echo "Running $COMMAND"
$COMMAND
echo "Removing temporary configuration $TRAIN_CONFIG"
rm $TRAIN_CONFIG
