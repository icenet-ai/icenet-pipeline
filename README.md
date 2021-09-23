# IceNet-Pipeline
Tools for operational execution of the IceNet model

## Overview

The structure of this repository is to provide CLI commands that allow you to
 run the icenet model end-to-end, allowing you to make daily sea ice 
 predictions.
 
 __Please note the structure of this repository is still undergoing serious 
 development and is going to change significantly...__
 
## Running IceNet

### environment

### data

### process

python src/IceNet-Pipeline/process.py -v -w 32 -ob 8 -l 3 \
    -ts 2010-01-01 -te 2010-01-31 \
    small north 2001-01-01 2002-12-31 \ 
    2010-12-01 2010-12-31 2>&1 | tee logs/process.small.log

### train

### predict

