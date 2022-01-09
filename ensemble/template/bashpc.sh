#!/usr/bin/env bash
[ -f /etc/bashrc ] && . /etc/bashrc

module load hpc/cuda/11.2
. /hpcpackages/python/miniconda3/etc/profile.d/conda.sh
conda activate /data/hpcdata/users/jambyr/miniconda3/envs/icenet

# Don't like this but unavoidable at present
if [ -f /data/hpcdata/users/$USER/.wandb.env ]; then
   echo "Loading WANDB configuration specifically for BAS"
   . /data/hpcdata/users/$USER/.wandb.env
fi
