# IceNet-Pipeline
Tools for operational execution of the IceNet model

## Overview

The structure of this repository is to provide CLI commands that allow you to
 run the icenet model end-to-end, allowing you to make daily sea ice 
 predictions.
 
 __Please note the structure of this repository is still undergoing serious 
 development and is going to change significantly...__
 
## Running IceNet

These parameters will work on a laptop 

### environment

Create or activate

### data

python

### process

python process.py -v -w 4 -ob 2 -fd 4 -l 2 -ts 2010-01-28 -te 2010-01-31 laptop north 2010-01-01 2010-01-22 2010-01-23 2010-01-27

HPC:
```python src/IceNet-Pipeline/process.py -v -w 32 -ob 8 -fd 14 -l 3 \
    -ts 2010-01-01 -te 2010-01-31 \
    small north 2001-01-01 2002-12-31 2010-12-01 2010-12-31 2>&1 | tee logs/process.small.log```

### train

model_ensemble -n -v -c -s ensemble/train_ensemble.yaml

### predict

