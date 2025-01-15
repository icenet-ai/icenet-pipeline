#!/usr/bin/env bash

if [[ $# -lt 2 ]]; then
    echo "Usage $0 DATASET NAME"
    exit 1
fi

. ENVS

echo "ARGS: $@"

# Defaults if not specified
ENSEMBLE_TARGET="slurm"
ENSEMBLE_SWITCH=""
ENSEMBLE_ARGS=""
ENSEMBLE_JOBS=1
ENSEMBLE_SEEDS_DEFAULT=42,46,45,17,24,84,83,16,5,3

while getopts ":b:c:de:f:g:j:l:m:n:o:p:q:r:s:t:x:" opt; do
  case "$opt" in
    b)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}batch=$OPTARG ";;
    c)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}cluster=$OPTARG ";;
    d)  ENSEMBLE_TARGET="dummy";;
    e)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}epochs=$OPTARG ";;
    f)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}filter_factor=$OPTARG ";;
    g)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}gpus=$OPTARG ";;
    j)  ENSEMBLE_JOBS=$OPTARG ;;
    l)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}preload=$OPTARG ";;
    m)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}mem=$OPTARG ";;
    n)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}nodelist=$OPTARG ";;
    o)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}nodes=$OPTARG ";;
    p)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}prep=$OPTARG ";;
    r)  ENSEMBLE_RUNS=$OPTARG ;; # Ensemble member run seed values
    s)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}strategy=$OPTARG ";;
    t)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}ntasks=$OPTARG ";;
    x)  ENSEMBLE_ARGS="${ENSEMBLE_ARGS}email=$OPTARG ";;
  esac
done

[ ! -z "$ENSEMBLE_ARGS" ] && ENSEMBLE_SWITCH="-x"
shift $((OPTIND-1))

[[ "${1:-}" = "--" ]] && shift

echo "ARGS = $ENSEMBLE_SWITCH $ENSEMBLE_ARGS, Leftovers: $@"

DATASET="$1"
NAME="$2"

LOADER=`basename $( cat dataset_config.${DATASET}.json | jq '.loader_config' | tr -d '"' )`
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
    -e "/\bSEEDS$/s/.*/${ENSEMBLE_SEEDS}/g" \
 ensemble/train.tmpl.yaml >$TRAIN_CONFIG

COMMAND="model_ensemble $TRAIN_CONFIG $ENSEMBLE_TARGET $ENSEMBLE_SWITCH $ENSEMBLE_ARGS"
echo "Running $COMMAND"
$COMMAND
echo "Removing temporary configuration $TRAIN_CONFIG"
rm $TRAIN_CONFIG
