#!/usr/bin/env bash

if [[ $# -lt 3 ]]; then
    echo "Usage $0 LOADER DATASET NAME"
    exit 1
fi

. ENVS

echo "ARGS: $@"

# Defaults if not specified
ENSEMBLE_TARGET="slurm"
ENSEMBLE_SWITCH=""
ENSEMBLE_ARGS=""
ENSEMBLE_JOBS=1
ENSEMBLE_NTASKS=4
ENSEMBLE_SEEDS_DEFAULT=42,46,45,17,24,84,83,16,5,3

while getopts ":b:c:de:f:g:j:l:m:n:o:p:q:r:s:t:" opt; do
  case "$opt" in
    b)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_batch=$OPTARG ";;
    c)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}cluster=$OPTARG ";;
    d)  ENSEMBLE_TARGET="dummy";;
    e)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_epochs=$OPTARG ";;
    f)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_filter_factor=$OPTARG ";;
    g)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}gpus=$OPTARG ";;
    j)  ENSEMBLE_JOBS=$OPTARG ;;
    l)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_preload=$OPTARG ";;
    m)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}mem=$OPTARG ";;
    n)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}nodelist=$OPTARG ";;
    o)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}nodes=$OPTARG ";;
    p)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_prep=$OPTARG ";;
    q)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}arg_queue=$OPTARG ";;
    r)  ENSEMBLE_RUNS=$OPTARG ;; # Ensemble member run seed values
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

##
# Dynamically generate seeds for ensemble run.
#

IFS="," read -ra SEEDS <<< "$ENSEMBLE_RUNS"

# Check if seeds defined as CLI args (e.g. `-r 42,46`)
if [ ${#SEEDS[@]} -eq 0 ]; then
    IFS="," read -ra SEEDS <<< "$ENSEMBLE_TRAIN_SEEDS"
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
    -e "s/NAME/${NAME}/g" \
    -e "s/LOADER/${LOADER}/g" \
    -e "s/DATASET/${DATASET}/g" \
    -e "s/MAXJOBS/${ENSEMBLE_JOBS}/g" \
    -e "s/NTASKS/${ENSEMBLE_NTASKS}/g" \
    -e "/\bSEEDS$/s/.*/${ENSEMBLE_SEEDS}/g" \
 ensemble/train.tmpl.yaml >$TRAIN_CONFIG

COMMAND="model_ensemble $TRAIN_CONFIG $ENSEMBLE_TARGET $ENSEMBLE_SWITCH $ENSEMBLE_ARGS"
echo "Running $COMMAND"
$COMMAND
echo "Removing temporary configuration $TRAIN_CONFIG"
rm $TRAIN_CONFIG
