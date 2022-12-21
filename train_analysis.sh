#!/usr/bin/env bash

for NOM in $( find ensemble/ -name 'train*.out' ); do 
    echo $NOM; 
    egrep 'Epoch [0-9]+: val_rmse improved ' $NOM | tail -n 1; 
    egrep 'Epoch [0-9]+: early stopping' $NOM;
    egrep '^(START|FINISH)' $NOM; 
done


