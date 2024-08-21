#!/bin/bash
#SBATCH --job-name=hsm1
#SBATCH --partition=pvc
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --ntasks-per-node=2
#SBATCH --gres=gpu:4
#SBATCH --exclusive
#SBATCH --cpus-per-task=24          # split from 96 cores
#SBATCH --time=12:00:00             # job length
#SBATCH --output=logs/train.small_north_test.%j.out
#SBATCH --error=logs/train.small_north_test.%j.err

source $HOME/.bashrc

module purge
module load default-dawn
module load dawn-env/2024-04-15 intel-oneapi-ccl intel-oneapi-compilers intel-oneapi-dnn intel-oneapi-dpct intel-oneapi-dpl intel-oneapi-inspector intel-oneapi-mkl intel-oneapi-mpi intel-oneapi-tbb

conda activate icenet

mpirun -np 2 icenet_train_horovod --device-type XPU -v --early-stopping 5 -wp test -wu jambyr --shuffle-train -e 3 -b 4 -n 1.44 dataset_config.full_train_north.json hv_small_test1 42
