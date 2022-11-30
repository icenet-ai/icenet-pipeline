#!/usr/bin/env bash
[ -f /etc/bashrc ] && . /etc/bashrc

# Don't like this but unavoidable at present
if [ -f /data/hpcdata/users/$USER/.wandb.env ]; then
   echo "Loading WANDB configuration specifically for BAS"
   . /data/hpcdata/users/$USER/.wandb.env
fi

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/hpcpackages/jupyterhub/20200401/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/hpcpackages/jupyterhub/20200401/etc/profile.d/conda.sh" ]; then
        . "/hpcpackages/jupyterhub/20200401/etc/profile.d/conda.sh"
    else
        export PATH="/hpcpackages/jupyterhub/20200401/bin:$PATH"
    fi
fi
unset __conda_setup

