# icenet-pipeline

Pipelining tools for operational execution of the IceNet model

## Overview

The structure of this repository is to provide CLI commands that allow you to
 run the icenet model end-to-end, allowing you to make daily sea ice 
 predictions.

## Get the repositories 

```bash
git clone git@github.com:icenet-ai/icenet-pipeline.git green
ln -s green pipeline
```

## Creating the environment

In spite of using the latest conda, the following may not work due to ongoing 
issues with the solver not failing / logging clearly. [1]

### Using conda

Conda can be used to manage system dependencies for HPC usage, we've tested on
the BAS and JASMIN (NERC) HPCs. Obviously your dependencies for conda will 
change based on what is in your system, so please treat this as illustrative. 

```bash
cd pipeline
conda env create -n icenet -f environment.yml
conda activate icenet

# Environment specifics
# BAS HPC just continue
# For JASMIN you'll be missing some things
module load jaspy/3.8
conda install -c conda-forge geos proj
# For your own HPC, who knows... the HPC specific instructions are very 
# changeable even for those tested, so please adapt as required. ;) 

### Additional linkage instructions for Tensorflow GPU usage BEFORE ICENET
mkdir -p $CONDA_PREFIX/etc/conda/activate.d
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$CONDA_PREFIX/lib/' > $CONDA_PREFIX/etc/conda/activate.d/env_vars.sh
chmod +x $CONDA_PREFIX/etc/conda/activate.d/env_vars.sh
. $CONDA_PREFIX/etc/conda/activate.d/env_vars.sh
```

### IceNet installation

Then install IceNet into your environment as applicable. If using conda 
obviously enable the environment first. 

Bear in mind when installing `icenet` (and by dependency `tensorflow`) you 
will need to be on a CUDA/GPU enabled machine for binary linkage. As per 
current (end of 2022) `tensorflow` guidance do not install it via conda. 

#### Developer installation

Using `-e` is optional, based on whether you want to be able to hack at the 
source!

```bash
cd ../icenet   # or wherever you've cloned icenet
pip install -e . 
```

#### PyPI installation

__If you don't want the source locally, you can now install via PyPI...__

```bash
pip install icenet
```

### Linking data folders

The system is set up to process data in certain directories. With each pipeline
installation you can share the source data if you like, so use symlinks for
`data` if applicable, and intermediate folders `processed` and 
`network_datasets` you might want to store on alternate storage as applicable.
The following kind of illustrates this:

```bash
# An example from deployment on JASMIN, linking big folders to group storage
ln -s /gws/nopw/j04/icenet/data
mkdir /gws/nopw/j04/icenet/network_datasets
mkdir /gws/nopw/j04/icenet/processed
ln -s /gws/nopw/j04/icenet/network_datasets
ln -s /gws/nopw/j04/icenet/processed
```

## Example run of the pipeline

### A note on HPCs

The pipeline is often run on __SLURM__. Previously the SBATCH headers for 
submission were included, but to avoid issues with portability these have now 
been removed and the instructions now exemplify running against this type of 
HPC with the setup passed on the command line rather than in hardcoded headers.

If you're not using SLURM, just run the commands without sbatch. To use an 
alternative just amend sbatch to whatever you need. 

### Configuration

This pipeline revolves around the ENVS file to provide the necessary 
configuration items. This can easily be derived from the `ENVS.example` file 
to a new file, then symbolically linked. Comments are available in 
`ENVS.example` to assist you with the editing process. 

```bash
cp ENVS.example ENVS.myconfig
ln -sf ENVS.myconfig ENVS
# Edit ENVS.myconfig to customise parameters for the pipeline
```

These variables will then be picked up during the runs via the ENVS symlink.

### Running the pipeline 

_[This is a very high level overview, for a more detailed run-through please 
review the icenet-notebooks repository.][2]_

#### One off: preparing SIC masks

As an additional dataset, IceNet relies on some masks being pre-prepared, so you
only have to do this on first run against the data store. 

```bash
conda activate icenet
icenet_data_masks north
icenet_data_masks south
```

#### Running training and prediction commands 

Change PREFIX to the setup you want to run through in ENVS

```bash
source ENVS

SBATCH_ARGS="$ICENET_SLURM_ARGS $ICENET_SLURM_DATA_PART"
sbatch $SBATCH_ARGS run_data.sh $HEMI $BATCH_SIZE $WORKERS

SBATCH_ARGS="$ICENET_SLURM_ARGS $ICENET_SLURM_RUN_PART"
./run_train_ensemble.sh \
    -b $BATCH_SIZE -e 200 -f $FILTER_FACTOR -p $PREP_SCRIPT -q 4 \
    ${TRAIN_DATA_NAME}_${HEMI} ${TRAIN_DATA_NAME}_${HEMI} mydemo_${HEMI}

./loader_test_dates.sh ${TRAIN_DATA_NAME}_north >test_dates.north.csv

./run_predict_ensemble.sh -f $FILTER_FACTOR -p $PREP_SCRIPT \
    mydemo_north forecast a_forecast test_dates.north.csv
```

### Other helper commands

The following commands are illustrative of various workflows built on top of, 
or alongside, the workflow described above. These are useful to use 
independently or to base your own workflows on.

#### run_forecast_plots.sh

This leverages the IceNet plotting functionality to analyse the specified
forecasts.

#### run_prediction.sh

This wraps up the preparation of data and running of predictions against 
pre-trained networks. This contrasts to the use of the test set to run 
predictions that was [demonstrated previously][3].

This command makes assumptions that source data is available for the OSI-SAF, 
ERA5 and ORAS5 datasets for the predictions you want to make. Use 
`icenet_data_sic`, `icenet_data_era5` and `icenet_data_oras5` respectively. 
This workflow is also easily adapted to other datasets, wink wink nudge nudge.

If you're using a model from another pipeline you need to ensure normalisation 
parameters are linked to under your `./processed` folder. For example:

```bash
ln -s /data/hpcdata/users/alice/icenet/pipeline/processed/traindata_north ./processed/traindata_north
```

## Implementing and changing environments

The point of having a repository like this is to facilitate easy integration 
with workflow managers, as well as allow multiple pipelines to easily be 
co-located in the filesystem. To achieve this have a location that contains 
your environments and sources, for example: 

```
cd hpc/icenet
ls -d1 *
blue
data
green
pipeline
scratch
test

# pipeline -> green

# Optionally you might have local sources for installs (e.g. not pip installed)
icenet.blue    
icenet.green    
```

Change the location of the pipeline from green to blue

```bash
TARGET=blue

ln -sfn $TARGET pipeline

# If using a branch, go into icenet.blue and pull / checkout as required, e.g.
cd icenet.blue
git pull
git checkout my-feature-branch
cd ..

# Next update the conda environment, which will be specific to your local disk
ln -sfn $HOME/hpc/miniconda3/envs/icenet-$TARGET $HOME/hpc/miniconda3/envs/icenet
cd pipeline
git pull

# Update the environment
conda env update -n icenet -f environment.yml
conda activate icenet
pip install --upgrade -r requirements-pip.txt
pip install -e ../icenet.$TARGET
```

## Credits

* Tom Andersson - Lead researcher
* James Byrne - Research Software Engineer
* Scott Hosking - PI

## License

*Please see LICENSE file for license information!*

[1]: https://github.com/conda/conda/issues?q=is%3Aissue+is%3Aopen+solving
[2]: https://github.com/icenet-ai/icenet-notebooks/
[3]: #running-training-and-prediction-commands