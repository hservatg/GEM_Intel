#!/bin/bash
#SBATCH -A phy122-ecp
#SBATCH -J 1-gpu-32
#SBATCH -o %x-%j.out
#SBATCH -t 00:10:00
### #SBATCH -p ecp
##SBATCH --reservation=hack3
#SBATCH -N 1

#!/bin/bash 

export OMP_NUM_THREADS=4
#export MPICH_GPU_SUPPORT_ENABLED=1
rm -f plot log.out log.err
mkdir -p matrix
mkdir -p out
mkdir -p dump

srun -N 1 -n 1 --ntasks-per-node=1 --gpus-per-task=1 -c 4 --gpu-bind=closest ./gem_main > log.out 2> log.err &

wait

