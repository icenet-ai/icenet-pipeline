#!/bin/bash
#SBATCH --job-name=hsouth1
#SBATCH --partition=pvc
#SBATCH --nodes=2
#SBATCH --ntasks=16
#SBATCH --ntasks-per-node=8
#SBATCH --gres=gpu:4
#SBATCH --cpus-per-task=12          # split from 96 cores
#SBATCH --time=1-00:00:00             # job length
#SBATCH --output=logs/train.south.%j.out
#SBATCH --error=logs/train.south.%j.err

source $HOME/.bashrc

module purge
module load default-dawn
module load dawn-env/2024-04-15 intel-oneapi-ccl intel-oneapi-compilers intel-oneapi-dnn intel-oneapi-dpct intel-oneapi-dpl intel-oneapi-inspector intel-oneapi-mkl intel-oneapi-mpi intel-oneapi-tbb

conda activate icenet

mpirun -np 16 icenet_train_horovod --device-type XPU -v --early-stopping 5 -wp test -wu jambyr --shuffle-train -e 100 -b 4 -n 1.44 dataset_config.full_train_south.json hv_south1 42
