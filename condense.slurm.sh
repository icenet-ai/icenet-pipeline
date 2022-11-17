#!/bin/bash

. ENVS

conda activate $ICENET_CONDA

echo "START $1 $2 $3: `date +%T`"
icenet_process_condense -v $1 $2 $3 >$ICENET_HOME/logs/condense.$1.$2.$3.log 2>&1
echo "END $1 $2 $3 `date +%T`"

