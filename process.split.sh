#!/usr/bin/env bash

python process.py -v -l 4 -fd 93 -ob 4 -w 32 \
    -ts 2020-01-01 -te 2020-12-31 \
    ensemble_split north 2005-01-01,2011-01-01 2007-12-31,2015-12-31 2016-01-01 2017-12-31 2>&1 | tee process.split.out
