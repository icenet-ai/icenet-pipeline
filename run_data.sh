#!/bin/bash
#
# Output directory
#SBATCH --output=/data/hpcdata/users/jambyr/icenet/blue/logs/data.%j.%N.out
#SBATCH --chdir=/data/hpcdata/users/jambyr/icenet/blue
#SBATCH --mail-type=begin,end,fail,requeue
#SBATCH --mail-user=jambyr@bas.ac.uk
#SBATCH --time=48:00:00
#SBATCH --partition=medium
#SBATCH --account=medium
#SBATCH --nodes=1
##SBATCH --mem=192g
#SBATCH --job-name=tiny

. /hpcpackages/python/miniconda3/etc/profile.d/conda.sh
conda activate /data/hpcdata/users/$USER/miniconda3/envs/icenet

set -o pipefail
set -eu

#START="1985-1-1,2005-7-1"
#END="1985-6-30,2005-12-31"

START=`seq 1979 1 1995 | xargs printf "%4d-3-1,"``seq 1979 1 1995 | xargs printf "%4d-3-14,"`
START=${START%,}
END=`seq 1979 1 1995 | xargs printf "%4d-3-1,"``seq 1979 1 1995 | xargs printf "%4d-3-14,"`
END=${END%,}

VAL_START="2016-3-1,2016-3-14"
VAL_END="2016-3-1,2016-3-14"
TEST_START="2019-3-1,2019-3-14"
TEST_END="2019-3-1,2019-3-14"
LAG=1
DATANAME="tiny"
HEMI="$1"

icenet_process_era5 \
    --abs uas,vas --anom tas,ta500,tos,psl,zg500,zg250 \
    -v -l $LAG -ns $START -ne $END -vs $VAL_START -ve $VAL_END -ts $TEST_START -te $TEST_END \
    ${DATANAME}_${HEMI} $HEMI
#icenet_process_oras5 \
#    --anom so,thetao --abs uo,vo \
#    -v -l $LAG -ns $START -ne $END -vs $VAL_START -ve $VAL_END -ts $TEST_START -te $TEST_END \
#    ${DATANAME}_${HEMI} $HEMI
icenet_process_sic \
    --abs siconca \
    -v -l $LAG -ns $START -ne $END -vs $VAL_START -ve $VAL_END -ts $TEST_START -te $TEST_END \
    --trends siconca --trend-lead 1,8,15,22,29,36,43,50,57,64,71,78,85,92 \
    ${DATANAME}_${HEMI} $HEMI
icenet_process_metadata ${DATANAME}_${HEMI} $HEMI

icenet_dataset_create -v -p -ob 2 -w 12 -fd 93 -l $LAG ${DATANAME}_${HEMI} $HEMI
