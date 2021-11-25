#!/bin/bash
#SBATCH --output=/data/hpcdata/users/jambyr/icenet/pipeline/train.%j.%N.42.out
#SBATCH --error=/data/hpcdata/users/jambyr/icenet/pipeline/train.%j.%N.42.err
#SBATCH --chdir=/data/hpcdata/users/jambyr/icenet/pipeline
#SBATCH --mail-type=begin,end,fail,requeue
#SBATCH --mail-user=jambyr@bas.ac.uk
#SBATCH --time=48:00:00
#SBATCH --job-name=icetest
#SBATCH --nodes=1
#SBATCH --nodelist=node022
#SBATCH --gres=gpu:2
#SBATCH --partition=gpu
#SBATCH --account=gpu
#SBATCH --cpus-per-task=16
#SBATCH --mem=128gb


# BAS HPC specific items are offloaded to the ensemble configuration so that there is a single point of config
module load hpc/cuda/11.2
. /hpcpackages/python/miniconda3/etc/profile.d/conda.sh
conda activate /data/hpcdata/users/jambyr/miniconda3/envs/icenet
cd /data/hpcdata/users/jambyr/icenet/pipeline
mkdir -p results

echo "START `date +%F`"

icenet_train -v north_test22 north_test.42 42 \
    -b 4 -e 2 -m -w 16 -qs 10 -s mirrored \
2>&1 

echo "FINISH `date +%F`"
