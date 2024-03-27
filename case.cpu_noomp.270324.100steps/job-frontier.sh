#!/bin/bash
#SBATCH -A phy122-ecp
#SBATCH -J 4
#SBATCH -o %x-%j.out
#SBATCH -t 00:30:00
### #SBATCH -p ecp
##SBATCH --reservation=hack3
#SBATCH -N 4

#!/bin/bash 

export OMP_NUM_THREADS=4
#export MPICH_GPU_SUPPORT_ENABLED=1
rm plot run.out log.err
mkdir -p matrix
mkdir -p out
mkdir -p dump

srun -N 4 -n 32 --ntasks-per-node=8 --gpus-per-task=1 -c 4 --gpu-bind=closest ./gem_main > run.out 2> log.err &

wait

