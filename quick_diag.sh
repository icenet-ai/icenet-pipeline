#!/usr/bin/env bash

# set -u -o pipefail
STRATEGY=${1:-mirrored}
GPUS=${2:-4}

# srun --gres=gpu:4 --job-name=icenet-test --partition=pvc --nodes=1 --time=01:00:00 --pty bash -i
LOGNAME="logs/$STRATEGY.$GPUS.`uuidgen`.log"

{
. ENVS
conda activate $ICENET_CONDA
echo "START: `date +%s`"
icenet_train -b 4 -e 1 -f 1 -n $FILTER_FACTOR -s $STRATEGY --gpus $GPUS -nw --lr 25e-5 -v  exp23_south test_south1 42
echo "END: `date +%s`"
} 2>&1 | tee $LOGNAME
