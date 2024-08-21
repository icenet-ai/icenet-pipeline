#!/bin/bash
#SBATCH --job-name=icy_test
#SBATCH --partition=pvc
#SBATCH --ntasks=8
#SBATCH --ntasks-per-node=4
#SBATCH --gres=gpu:4
#SBATCH --cpus-per-task=24          # split from 96 cores
#SBATCH --time=08:00:00             # job length
#SBATCH --output=train.%j.out
#SBATCH --error=train.%j.err

source $HOME/.bashrc

module purge
module load default-dawn
module load dawn-env/2024-04-15 intel-oneapi-ccl intel-oneapi-compilers intel-oneapi-dnn intel-oneapi-dpct intel-oneapi-dpl intel-oneapi-inspector intel-oneapi-mkl intel-oneapi-mpi intel-oneapi-tbb

conda activate icenet

mpirun -np 8 python scripts/horovod_test.py
