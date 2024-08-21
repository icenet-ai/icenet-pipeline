#!/usr/bin/env bash

source $HOME/.bashrc

module purge
module load default-dawn
module load dawn-env/2024-04-15 intel-oneapi-ccl intel-oneapi-compilers intel-oneapi-dnn intel-oneapi-dpct intel-oneapi-dpl intel-oneapi-inspector intel-oneapi-mkl intel-oneapi-mpi intel-oneapi-tbb

