# icenet-pipeline

Pipelining tools for operational execution of the IceNet model

## Overview

The structure of this repository is to provide CLI commands that allow you to
 run the icenet model end-to-end, allowing you to make daily sea ice 
 predictions.

## Get the repositories 

```bash
git clone git@github.com:icenet-ai/icenet-pipeline.git green
git clone git@github.com:icenet-ai/icenet.git icenet.green
ln -s green pipeline
ln -s icenet.green icenet
```

## Creating the environment

In spite of using the latest conda, the following may not work due to ongoing 
issues with the solver not failing / logging clearly. [1]

### Using conda

Conda can be used to manage system dependencies for HPC usage, we've tested on
the BAS and JASMIN (NERC) HPCs. Obviously your dependencies for conda will 
change based on what is in your system, so please treat this as illustrative:

```bash
cd pipeline
conda env create -n icenet -f environment.yml
conda activate icenet

# Environment specifics
# BAS HPC just continue
# For JASMIN you'll be missing some things
module load jaspy/3.8
conda install -c conda-forge geos proj

### Additional linkage instructions for GPU usage
mkdir -p $CONDA_PREFIX/etc/conda/activate.d
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$CONDA_PREFIX/lib/' > $CONDA_PREFIX/etc/conda/activate.d/env_vars.sh
chmod +x $CONDA_PREFIX/etc/conda/activate.d/env_vars.sh
. $CONDA_PREFIX/etc/conda/activate.d/env_vars.sh
```

### IceNet installation

Then install IceNet into your environment as applicable. If using conda 
obviously enable the environment first. We are not publishing to PyPI yet, at
time of last update. Using `-e` is optional, based on whether you want to be
able to hack at the source!

```bash
cd ../icenet   # or wherever you've cloned icenet
pip install -e . 
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

Quite often you might 
```bash

```









```bash
source ENVS

icenet_data_masks $HEMI -v
# Training and val
## icenet_data_oras5 -w 8 --vars uo,vo,so,thetao north 1993-1-1 2019-12-31

icenet_data_cmip $HEMI MRI-ESM2-0 r1i1p1f1 \
  -d -sd 1988-1-1 -ed 1991-12-31 -w 4
icenet_data_era5 $HEMI 1988-1-1 1991-12-31 -v
icenet_data_sic $HEMI 1988-1-1 1991-12-31 -v
# Test
icenet_data_hres $HEMI 2012-06-01 2012-06-30 -v
icenet_data_sic $HEMI 2012-06-01 2012-06-30 -v

icenet_process_cmip pretrain_loader $HEMI MRI-ESM2-0 r1i1p1f1 \
    -ns 1988-1-1 -ne 1990-12-31 \
    -vs 1991-2-1 -ve 1991-2-28 \
    -ts 1991-6-1 -te 1991-6-30 -l $LAG 
icenet_process_metadata pretrain_loader $HEMI

icenet_process_era5 train_loader $HEMI \
    -ns 1988-1-1 -ne 1990-12-31 \
    -vs 1991-2-1 -ve 1991-2-28 \
    -ts 1991-6-1 -te 1991-6-30 -l $LAG 
icenet_process_sic train_loader $HEMI \
    -ns 1988-1-1 -ne 1990-12-31 \
    -vs 1991-2-1 -ve 1991-2-28 \
    -ts 1991-6-1 -te 1991-6-30 -l $LAG 
icenet_process_metadata train_loader $HEMI

icenet_process_era5 -r processed/train_loader/era5/$HEMI \
  -v -l $LAG -ts 2012-06-01 -te 2012-06-30 forecast_loader $HEMI
icenet_process_sic  -r processed/train_loader/osisaf/$HEMI \
  -v -l $LAG -ts 2012-06-01 -te 2012-06-30 forecast_loader $HEMI
icenet_process_metadata forecast_loader $HEMI

icenet_dataset_create -l $LAG -ob 2 -w 4 pretrain_loader $HEMI
icenet_dataset_create -l $LAG -ob 2 -w 4 train_loader $HEMI
icenet_dataset_create -l $LAG -c -fn forecast forecast_loader $HEMI

./run_train_ensemble.sh \
    -b 2 -e 20 -f $FILTER_FACTOR -p $PREP_SCRIPT -q 2 \
    train_loader train_loader the_model

./loader_test_dates.sh forecast_loader >forecast_dates.csv
./run_predict_ensemble.sh -f `cat FILTER_FACTOR | tr -d '\n'` -p bashpc.sh \
    the_model forecast a_forecast forecast_dates.csv
```

## Changing environments

You need to be in a location that contains your environments and sources, for 
example: 

```commandline
cd hpc/icenet
ls -d1 *
blue
data
green
icenet2.blue
icenet2.green
pipeline
scratch
test
# pipeline -> green
```

Change the location of the pipeline from green to blue

```commandline
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

That should be it! 

## Credits

*Please see LICENSE for usage information*

Tom Andersson - Lead research
James Byrne - Research Software Engineer
Scott Hosking - PI

[1]: https://github.com/conda/conda/issues?q=is%3Aissue+is%3Aopen+solving
