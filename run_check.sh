#!/bin/bash
#
# Output directory
#SBATCH --output=/data/hpcdata/users/jambyr/icenet/pipeline/logs/check.%j.%N.out
#SBATCH --chdir=/data/hpcdata/users/jambyr/icenet/pipeline
#SBATCH --mail-type=begin,end,fail,requeue
#SBATCH --mail-user=jambyr@bas.ac.uk
#SBATCH --time=48:00:00
#SBATCH --partition=gpu
#SBATCH --account=gpu
#SBATCH --nodes=1
#SBATCH --nodelist=node022
#SBATCH --mem=8g
#SBATCH --job-name=check

. /hpcpackages/python/miniconda3/etc/profile.d/conda.sh
conda activate /data/hpcdata/users/$USER/miniconda3/envs/icenet

if [ $# -lt 1 ]; then
    echo "Usage: $0 dataset_name"
    exit 1
fi

DATASET_NAME=$1

set -o pipefail
set -eu

icenet_dataset_check -v dataset_config.${DATASET_NAME}.json
