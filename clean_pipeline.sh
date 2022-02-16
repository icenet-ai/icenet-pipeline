#!/usr/bin/env bash

echo "Cleaning the environment"
rm -v dataset_config.*.json
find ensemble/ -maxdepth 1 -type d -a ! -name 'ensemble' -a ! -name 'template' -exec echo rm -rv {} \;
rm -v loader.*.json
rm -rv logs/*
rm -rv network_datasets/*
rm -rv plot/*
rm predict.*.csv
rm -rv processed/*
rm -rv results/{networks,predict}/*
rm -rv _sicfile/
rm -rv wandb/
