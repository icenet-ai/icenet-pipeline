#!/bin/bash
#
# Output directory
#SBATCH --output=/data/hpcdata/users/jambyr/icenet/pipeline/logs/condense.%j.%N.out
#SBATCH --chdir=/data/hpcdata/users/jambyr/icenet/pipeline
#SBATCH --mail-type=begin,end,fail,requeue
#SBATCH --mail-user=jambyr@bas.ac.uk
#SBATCH --time=12:00:00
#SBATCH --partition=medium
#SBATCH --account=medium
#SBATCH --nodes=1
#SBATCH --job-name=condense

. ENVS

. /hpcpackages/python/miniconda3/etc/profile.d/conda.sh
conda activate /data/hpcdata/users/$USER/miniconda3/envs/icenet

echo "START $1 $2 $3: `date +%T`"
icenet_process_condense -v $1 $2 $3 >logs/condense.$1.$2.$3.log 2>&1
echo "END $1 $2 $3 `date +%T`"

