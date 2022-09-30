#!/bin/bash
#
# Output directory
#SBATCH --output=/data/hpcdata/users/jambyr/icenet/pipeline/logs/data.%j.%N.out
#SBATCH --chdir=/data/hpcdata/users/jambyr/icenet/pipeline
#SBATCH --mail-type=begin,end,fail,requeue
#SBATCH --mail-user=jambyr@bas.ac.uk
#SBATCH --time=48:00:00
#SBATCH --partition=medium
#SBATCH --account=medium
#SBATCH --nodes=1
#SBATCH --job-name=dataset_name

##SBATCH --mem=192g

. ENVS

. /hpcpackages/python/miniconda3/etc/profile.d/conda.sh
conda activate /data/hpcdata/users/$USER/miniconda3/envs/icenet

set -o pipefail
set -eu

DATANAME="dataset_name"
HEMI="${1:-$HEMI}"

[ ! -z "$PROC_ARGS_ERA5" ] && icenet_process_era5 -v -l $LAG \
    $PROC_ARGS_ERA5 \
    -ns $TRAIN_START -ne $TRAIN_END -vs $VAL_START -ve $VAL_END -ts $TEST_START -te $TEST_END \
    ${DATANAME}_${HEMI} $HEMI

[ ! -z "$PROC_ARGS_ORAS5" ] && icenet_process_oras5 -v -l $LAG \
    $PROC_ARGS_ORAS5 \
    -ns $TRAIN_START -ne $TRAIN_END -vs $VAL_START -ve $VAL_END -ts $TEST_START -te $TEST_END \
    ${DATANAME}_${HEMI} $HEMI

[ ! -z "$PROC_ARGS_SIC" ] && icenet_process_sic -v -l $LAG \
    $PROC_ARGS_SIC \
    -ns $TRAIN_START -ne $TRAIN_END -vs $VAL_START -ve $VAL_END -ts $TEST_START -te $TEST_END \
    ${DATANAME}_${HEMI} $HEMI

icenet_process_metadata ${DATANAME}_${HEMI} $HEMI

icenet_dataset_create -v -p -ob 2 -w 12 -fd $FORECAST_DAYS -l $LAG ${DATANAME}_${HEMI} $HEMI
