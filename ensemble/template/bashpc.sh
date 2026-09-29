#!/usr/bin/env bash
[ -f /etc/bashrc ] && . /etc/bashrc

# Don't like this but unavoidable at present
if [ -f /data/hpcdata/users/$USER/.wandb.env ]; then
   echo "Loading WANDB configuration specifically for BAS"
   . /data/hpcdata/users/$USER/.wandb.env
fi

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/data/hpcdata/users/icenet/miniforge3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/data/hpcdata/users/icenet/miniforge3/etc/profile.d/conda.sh" ]; then
        . "/data/hpcdata/users/icenet/miniforge3/etc/profile.d/conda.sh"
    else
        export PATH="/data/hpcdata/users/icenet/miniforge3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<


# >>> mamba initialize >>>
# !! Contents within this block are managed by 'mamba shell init' !!
export MAMBA_EXE='/data/hpcdata/users/icenet/miniforge3/bin/mamba';
export MAMBA_ROOT_PREFIX='/users/icenet/.local/share/mamba';
__mamba_setup="$("$MAMBA_EXE" shell hook --shell bash --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__mamba_setup"
else
    alias mamba="$MAMBA_EXE"  # Fallback on help from mamba activate
fi
unset __mamba_setup
# <<< mamba initialize <<<
