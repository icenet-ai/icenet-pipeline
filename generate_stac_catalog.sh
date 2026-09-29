#!/bin/bash -l

# Generate STAC catalog using:
# https://github.com/environmental-forecasting/environmental-stac-orchestrator
# It also rsyncs it to a defined path, and ingests it into a database.
# It expects a `../../.env.prod` file that points to the pgres database,
# and, its password.

# Get the absolute path for this script
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

ICENET_2_PIPELINE=${1:-"${SCRIPT_DIR}"}
SYNC_PATH=${2:-"/data/twins/pub/sic/icenet/prod/stac-catalog/"}
MODEL_NAME=${3:-"exp23"}

source $(conda info --base)/etc/profile.d/conda.sh
conda activate environmental_stac_generator

dir=${ICENET_2_PIPELINE}/results/stac-catalog/
mkdir -p ${dir}
cd ${dir}
envstacgen preprocess -w 12 ../predict/*_north.nc -n icenet_${MODEL_NAME}_north #-o
envstacgen preprocess -w 12 ../predict/*_south.nc -n icenet_${MODEL_NAME}_south #-o

rsync -av --exclude .env* ${dir} ${SYNC_PATH}

# Ingest into postgreSQL database
# There must be a `.env.*` config file here based on above github repo README.md
# e.g. `./.env.production`
envstacgen ingest --env-file ../../.env.prod ${dir}data/stac/catalog.json #-o
