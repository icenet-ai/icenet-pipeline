#!/bin/bash
#SBATCH --output=/data/hpcdata/users/jambyr/icenet/pipeline/south_testrun.out
#SBATCH --error=/data/hpcdata/users/jambyr/icenet/pipeline/south_testrun.err
#SBATCH --chdir=/data/hpcdata/users/jambyr/icenet/pipeline
#SBATCH --mail-type=begin,end,fail,requeue
#SBATCH --mail-user=jambyr@bas.ac.uk
#SBATCH --time=1-00:00:00
#SBATCH --job-name=ds_south
#SBATCH --nodes=1
#SBATCH --nodelist=node022
#SBATCH --partition=gpu
#SBATCH --account=gpu
#SBATCH --cpus-per-task=16
#SBATCH --mem=64gb

cd /data/hpcdata/users/jambyr/icenet/pipeline

echo "START `date +%F`"

module load hpc/cuda/11.2
. /hpcpackages/python/miniconda3/etc/profile.d/conda.sh
conda activate /data/hpcdata/users/jambyr/miniconda3/envs/icenet

python -u scratch/tf_nans.py dataset_config.north_test22.json

echo "SWITCH"

python -u scratch/tf_nans.py dataset_config.south_test22.json

echo "FINISH `date +%F`"
