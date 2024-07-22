#!/bin/bash

. ENVS
conda activate $ICENET_CONDA

if [ $# -lt 1 ]; then
    echo "Usage: $0 dataset_name"
    exit 1
fi

DATASET_NAME=$1

set -o pipefail
set -eu

icenet_dataset_check -v dataset_config.${DATASET_NAME}.json
