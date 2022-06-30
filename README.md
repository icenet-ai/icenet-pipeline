# IceNet-Pipeline
Tools for operational execution of the IceNet model

## Overview

The structure of this repository is to provide CLI commands that allow you to
 run the icenet model end-to-end, allowing you to make daily sea ice 
 predictions.

## Creating the environment

In spite of using the latest conda, the following may not work due to ongoing 
issues with the solver not failing / logging clearly. [1]

```bash
conda env create -n icenet -f environment.yml
pip install -r requirements-pip.txt
```

Alternatively you can use:

```bash
conda create -n icenet python==3.8
conda activate icenet
conda install -c conda-forge -c defaults `grep '  - ' environment.yml | egrep -v '(defaults|conda-forge|python)' | sed -r 's/  - / /' | tr -d '\n'`
pip install -r requirements-pip.txt
```

If you get CondaMemoryError (as I do with 16gb of RAM whilst solving), then
sometimes you can just run through things manually and it all works (don't
forget to do pip install after!)

```bash
conda install -c conda-forge -c defaults cudatoolkit
conda install -c conda-forge -c defaults cudnn
conda install -c conda-forge -c defaults eccodes
conda install -c conda-forge -c defaults hdf4 hdf5
conda install -c conda-forge -c defaults ipykernel
conda install -c conda-forge -c defaults iris
```

There was a dependency on `xgeo` when I did this, so it's possible that package was broken in conda, but this is all useful stuff.

Then install the python dependencies on top of this:

```bash
pip install -r requirements-pip.txt
pip install -e . # or wherever you've cloned icenet
```
 
## Credits

*Please see LICENSE for usage information*

Tom Andersson
James Byrne

[1]: https://github.com/conda/conda/issues?q=is%3Aissue+is%3Aopen+solving