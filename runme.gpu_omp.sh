#!/bin/bash

profiling="none" # available values: none

# run this runme as: nohup ./runme.sh > ss.txt 2>&1 &
export I_MPI_OFFLOAD_SYMMETRIC=1
export I_MPI_FABRICS=shm
export I_MPI_OFFLOAD_CELL=tile
export I_MPI_OFFLOAD_DOMAIN_SIZE=1
export I_MPI_OFFLOAD_DEVICES=all
export I_MPI_OFFLOAD=1
export I_MPI_DEBUG=10 # set to 10 for printing out most info, set to default 0 disabled print out
export I_MPI_OFFLOAD_RDMA=1

export NEOReadDebugKeys=1
export EnableImplicitScaling=0

export OMP_NUM_THREADS=14
export OMP_PLACES=CORES
export OMP_PROC_BIND=CLOSE

export EnableRecoverablePageFaults=0 #suggested by Tobias, not yet working 20240206

# export LIBOMPTARGET_LEVEL0_COMPILATION_OPTIONS="-ze-intel-enable-auto-large-GRF-mode"
# IGC will use compiler heuristics to pick between small and large GRF mode on a per-kernel basis

#export LIBOMPTARGET_LEVEL0_COMPILATION_OPTIONS="-ze-opt-large-register-file"
# IGC will force large GRF mode for all kernels

#export IGC_ForceOCLSIMDWidth=16                #suggested by Ravi, works for 16 or 32
#export IGC_PrintFunctionSizeAnalysis=1         #suggested by Ravi, print out not easy to understand

module purge
module load intel/oneapi/2024.0

# force openmp to run codes on GPU
export OMP_TARGET_OFFLOAD=MANDATORY  # avail value: DISABLED MANDATORY DEFAULT

CURRENT_TIME=`date +%d%m%y-%H%M`

cp -r case.reference case.gpu_omp.${CURRENT_TIME}
cd case.gpu_omp.${CURRENT_TIME}
mkdir -p out matrix dump

ulimit -s unlimited

if [[ "${profiling}" == "none" ]]; then
	mpirun -np 8 ../scripts/profile-on-0.sh ../gem_main
fi
