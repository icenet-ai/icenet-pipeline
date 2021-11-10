#!/bin/bash
#SBATCH --output=/data/hpcdata/users/jambyr/icenet/pipeline/predict.%j.%N.42.out
#SBATCH --error=/data/hpcdata/users/jambyr/icenet/pipeline/predict.%j.%N.42.err
#SBATCH --chdir=/data/hpcdata/users/jambyr/icenet/pipeline
#SBATCH --mail-type=begin,end,fail,requeue
#SBATCH --mail-user=jambyr@bas.ac.uk
#SBATCH --time=48:00:00
#SBATCH --job-name=icetpred
#SBATCH --nodes=1
#SBATCH --nodelist=node022
#SBATCH --gres=gpu:1
#SBATCH --partition=gpu
#SBATCH --account=gpu
#SBATCH --cpus-per-task=8
#SBATCH --mem=64gb


# BAS HPC specific items are offloaded to the ensemble configuration so that there is a single point of config
module load hpc/cuda/11.2
. /hpcpackages/python/miniconda3/etc/profile.d/conda.sh
conda activate /data/hpcdata/users/jambyr/miniconda3/envs/icenet
cd /data/hpcdata/users/jambyr/icenet/pipeline

echo "START `date +%F`"

icenet_predict -v -n 1.2 -t 90s_22 south_90s south_90s_test 42 90s_test_dates.csv

echo "FINISH `date +%F`"
