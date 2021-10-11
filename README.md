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

* Small:  

```bash
    python src/IceNet-Pipeline/process.py -v -w 32 -ob 8 -fd 14 -l 3 \
        -ts 2010-01-01 -te 2010-01-31 \
        small north 2001-01-01 2002-12-31 2010-12-01 2010-12-31 2>&1 | tee logs/process.small.log
```

* Ensemble:

```bash    
    python src/IceNet-Pipeline/process.py -v -l 4 -fd 93 -ob 4 -w 32 \
        -ts 2019-01-01 -te 2020-12-31 \
        -d 0.1 \   
        ensemble_train north 1979-01-01 2016-12-31 2017-01-01 2018-12-31 2>&1 | tee process.ensemble.out
```

* Split dates:

```bash    
    python src/IceNet-Pipeline/process.py -v -l 4 -fd 93 -ob 4 -w 32 \
        -d 0.4 -ts 2019-01-01 -te 2020-12-31 \
        ensemble_split north \
        1979-01-01,1985-01-01,1994-01-01,2005-01-01,2011-01-01 \
        1981-12-31,1987-12-31,1996-12-31,2007-12-31,2015-12-31 \
        2016-01-01 \
        2018-12-31 \
        2>&1 | tee process.split.out
```

### train

model_ensemble -n -v -c -s ensemble/train_ensemble.yaml

_Test a laptop run_

```bash
ln -sf ../../../train.py
ln -sf ../../../loader.laptop.json
ln -sf ../../../dataset_config.laptop.json
ln -sf ../../../network_datasets
ln -sf ../../../results
mkdir -p ../../../results

python3 train.py -v laptop draft.{{ seed }} {{ seed }} \
    -b 4 -e 10 -m -qs 8 -s default \
    -n 0.25 \
2>&1 | tee train.out.log
```

#### Production run

model_ensemble -n -v -c -s ensemble/train_ensemble.production.yaml

### predict

model_ensemble -n -v -c -s ensemble/predict_ensemble.yaml


_Test a laptop run_

```bash
ln -sf ../../../data
ln -sf ../../../predict.py
ln -sf ../../../loader.laptop.json
ln -sf ../../../dataset_config.laptop.json
ln -sf ../../../network_datasets
ln -sf ../../../processed
ln -sf ../../../results


python3 predict.py -v -n 0.25 \
    laptop draft test_forecast \
    46 2010-01-28 2010-01-31 \
    2>&1 | tee predict.out.log
```
