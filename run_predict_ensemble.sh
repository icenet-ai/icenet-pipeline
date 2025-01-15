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
ENSEMBLE_SEEDS_DEFAULT=42,46,45

while getopts ":b:df:i:lm:p:r:x" opt; do
  case "$opt" in
    b)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_batch=$OPTARG ";;
    d)  ENSEMBLE_TARGET="dummy";;
    f)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_filter_factor=$OPTARG ";;
    i)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_ident=$OPTARG ";;
    l)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_testset=false ";;
    m)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}mem=$OPTARG ";;
    p)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_prep=$OPTARG ";;
    r)  ENSEMBLE_RUNS=$OPTARG ;; # Ensemble member run seed values
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

##
# Dynamically generate seeds for ensemble run.
#

IFS="," read -ra SEEDS <<< "$ENSEMBLE_RUNS"

# Check if seeds defined as CLI args (e.g. `-r 42,46`)
if [ ${#SEEDS[@]} -eq 0 ]; then
    IFS="," read -ra SEEDS <<< "$ENSEMBLE_PREDICT_SEEDS"
    # Check if seeds defined in ENVS exported variables (else use defaults)
    if [ ${#SEEDS[@]} -eq 0 ]; then
        IFS="," read -ra SEEDS <<< "$ENSEMBLE_SEEDS_DEFAULT"
    fi
fi

# Generate seed lines for yaml output
ENSEMBLE_SEEDS=""
COUNTER=0
for seed in ${SEEDS[@]}
do
    ENSEMBLE_SEEDS+="        - seed:   "$seed
    if [ $COUNTER -lt $((${#SEEDS[@]}-1)) ]; then
        ENSEMBLE_SEEDS+="\n"
    fi
    ((COUNTER++))
done

echo "No. of ensemble members: " "${#SEEDS[@]}"
printf -v joined '%s,' "${SEEDS[@]}"
echo "Ensemble members: " "${joined%,}"

sed -r \
    -e "s/NETWORK/${NETWORK}/g" \
    -e "s/DATASET/${DATASET}/g" \
    -e "s/LOADER/${LOADER}/g" \
    -e "s/NAME/${NAME}/g" \
    -e "/\bSEEDS$/s/.*/${ENSEMBLE_SEEDS}/g" \
 ensemble/predict.tmpl.yaml >$PREDICT_CONFIG

COMMAND="model_ensemble $PREDICT_CONFIG $ENSEMBLE_TARGET $ENSEMBLE_SWITCH $ENSEMBLE_ARGS"
echo "Running $COMMAND"

if [[ $DO_NOT_EXECUTE == 0 ]]; then
    $COMMAND
    echo "Removing temporary configuration $PREDICT_CONFIG"
    rm $PREDICT_CONFIG
else
    echo "Configuration left in $PREDICT_CONFIG"
fi
