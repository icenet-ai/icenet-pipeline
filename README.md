# icenet-pipeline

Pipelining tools for operational execution of the IceNet model

## Overview

The structure of this repository is to provide CLI commands that allow you to
 run the icenet model end-to-end, allowing you to make daily sea ice 
 predictions.

## Get the repositories 

**Please note this repository is tagged to corresponding icenet versions: if 
you want to get a particular tag add `--branch vM.M.R` to the clone command.**

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

In my normal setup, I run several pipelines each with one source data store:

```bash
# From inside the icenet-pipeline cloned directory, assuming target exists!
ln -s ../data
```

The following kind of illustrates this for linking big stuff to different storage:

```bash
# An example from deployment on JASMIN
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

### Running the training pipeline 

_[This is a very high level overview, for a more detailed run-through please 
review the icenet-notebooks repository.][2]_

### Running prediction commands from preprepared models

**This might be the best starting use case if you want to build intuition about 
the pipeline facilities using someone elses models!**

***The shell you're using should be `bash`***

```bash
# Take a git clone of the pipeline
$ git clone git@github.com:icenet-ai/icenet-pipeline.git anewenv
$ cd anewenv
$ conda activate icenet

# We identify a pipeline we want to link to
$ ls -d /data/hpcdata/users/jambyr/icenet/pipeline
/data/hpcdata/users/jambyr/icenet/pipeline

# Copy the environment variable file that was used for training
$ cp -v /data/hpcdata/users/jambyr/icenet/pipeline/ENVS.bas.exp23 .
‘/data/hpcdata/users/jambyr/icenet/pipeline/ENVS.bas.exp23’ -> ‘./ENVS.bas.exp23’

# Repoint your ENVS to the training ENVS file you want to predict against
$ unlink ENVS
$ ln -sf ENVS.bas.exp23 ENVS
$ ls -l ENVS
lrwxrwxrwx 1 [[REDACTED]] [[REDACTED]] 9 Feb 10 11:48 ENVS -> ENVS.bas.exp23

# These can also be modified in ENVS 
$ export ICENET_CONDA=$CONDA_PREFIX
$ export ICENET_HOME=`realpath .`

# Links to my source data store
ln -s /data/hpcdata/users/jambyr/icenet/pipeline/data

# Ensures we have a data loader store directory for the pipeline 
mkdir processed
# Links to the training data loader store from the other pipeline
ln -s /data/hpcdata/users/jambyr/icenet/pipeline/processed/exp23_south processed/

# Make sure the networks directory exists
mkdir -p results/networks
# Links to the network trained in the other pipeline
ln -s /data/hpcdata/users/jambyr/icenet/pipeline/results/networks/atmos23_south results/networks/
```

[And now you can look at running prediction commands against somebody elses networks][4]

#### One off: preparing SIC masks

As an additional dataset, IceNet relies on some masks being pre-prepared, so you
only have to do this on first run against the data store. 

```bash
conda activate icenet
icenet_data_masks north
icenet_data_masks south
```

#### Running training and prediction commands afresh

Change PREFIX to the setup you want to run through in ENVS

```bash
source ENVS

SBATCH_ARGS="$ICENET_SLURM_ARGS $ICENET_SLURM_DATA_PART"
sbatch $SBATCH_ARGS run_data.sh north $BATCH_SIZE $WORKERS

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

This command wraps up the preparation of data and running of predictions against 
pre-trained networks. This contrasts to the use of the test set to run 
predictions that was [demonstrated previously][3].

This command makes assumptions that source data is available for the OSI-SAF, 
ERA5 and ORAS5 datasets for the predictions you want to make. Use 
`icenet_data_sic`, `icenet_data_era5` and `icenet_data_oras5` respectively. 
This workflow is also easily adapted to other datasets, wink wink nudge nudge.

If you haven't already installed it, install the `model-ensembler` package
which will work out the generation of ensemble models:

```bash
pip install model-ensembler
```

The process for running predictions is then basically: 

```bash
# These lines are required if not set within the ENVS file
export DEMO_TEST_START="2021-10-01"
export DEMO_TEST_END="$DEMO_TEST_START"

./run_prediction.sh demo_test model_name hemi demo_test train_data_name

# Optionally, stick it into azure too, provided you're set up for it
icenet_upload_azure -v -o results/predict/demo_test.nc $DEMO_TEST_START
```

as an example, to generate a training run based on the atmos23_south trained
model shown above (assuming you have already seeded your data store using
icenet_data_* commands):

```bash
export DEMO_TEST_START="2024-01-01"

export DEMO_TEST_END=$DEMO_TEST_START

./run_prediction.sh demo_forecast atmos23_south south demo_test
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

The template\_\* files are not to be considered with respect to the 
icenet-pipeline repository, they're used in publishing forecasts! 

*Please see LICENSE file for license information!*

[1]: https://github.com/conda/conda/issues?q=is%3Aissue+is%3Aopen+solving
[2]: https://github.com/icenet-ai/icenet-notebooks/
[3]: #running-training-and-prediction-commands
[4]: #run_predictionsh
