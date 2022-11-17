#!/usr/bin/env bash
[ -f /etc/bashrc ] && . /etc/bashrc

. ENVS

conda activate $ICENET_CONDA

# Don't like this but unavoidable at present
if [ -f /data/hpcdata/users/$USER/.wandb.env ]; then
   echo "Loading WANDB configuration specifically for BAS"
   . /data/hpcdata/users/$USER/.wandb.env
fi
