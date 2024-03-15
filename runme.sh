#!/bin/bash -l
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

export LIBOMPTARGET_PLUGIN_PROFILE=F # env to control printing out kernel timing
export LIBOMPTARGET_DEBUG=0          # avail value: 0 1 2, set to 2 will print out about 20G data for a 1 min run

module purge
module load intel/oneapi/2024.0 intel-comp-rt/agama-ci-devel intel/pti-gpu-nda #currently onetrace generate large json files showing nothing, but we still need the pti module to provide sysmon command to check the gpu number and health.

# force openmp to run codes on GPU
export OMP_TARGET_OFFLOAD=MANDATORY  # avail value: DISABLED MANDATORY DEFAULT

if [ "make" == "make" ]; then 
  make clean
  make
fi

profiling="vtune" # available values: none, vtune, advi_roofline, onetrace(!!generate large data files, but show nothing in the browser)

if [ "run" == "run" ]; then 
cd case_one_gpu
for i in 256 #32 64 128
do
    #reset the input/output to run the exe
    #only keep 'gem.in  gem.template.in  plot.256.n1.gpu  profiles-1d.dat  rdata.dat  run.sh  zdata.dat' in case_one_gpu folder 
    #shiquans@ortce-skl21:~/test-20240213-GEM/gem_simple_v2/case_one_gpu$ ls
    #gem.in  profiles-1d.dat  rdata.dat  zdata.dat
    #or "cp /nfs/site/home/shiquans/test-20240213-GEM/gem_simple_v2/case_one_gpu/* ." to get everything new

    rm -rf out matrix dump
    rm 1d.dat rz.dat eqdat eqflux xpp gem.out zprof plot
    rm flux yyre fluxa indicator gtildi gtilde
    rm profiles-1d.dat rdata.dat zdata.dat gem.in 
    rm parallel_print.sh
    rm app_rank_*
    rm gem.256.in
    rm core*

    mkdir -p out matrix dump
    #cp /nfs/site/home/shiquans/test-20240213-GEM/gem_simple_v2/case_one_gpu/* .
    cp /nfs/site/home/shiquans/test-20240213-GEM/gem_simple_v2/case_one_gpu/profiles-1d.dat .
    cp /nfs/site/home/shiquans/test-20240213-GEM/gem_simple_v2/case_one_gpu/rdata.dat .
    cp /nfs/site/home/shiquans/test-20240213-GEM/gem_simple_v2/case_one_gpu/zdata.dat .
    cp gem.template.in gem.$i.in
    sed -i 's/XXX/'$i'/g' gem.$i.in
    mv gem.$i.in gem.in

    if [ $profiling == "none" ]; then 
      export LIBOMPTARGET_PLUGIN_PROFILE=T # set to T to print out libomptarget kernel naming and timing
      export LIBOMPTARGET_DEBUG=0
      #export IGC_PrintFunctionSizeAnalysis=0

      #print out each MPI rank to individual file
      rm ./parallel_print.sh
      cat > ./parallel_print.sh <<EOF
#!/bin/bash
\$@ > app_rank_clean_\${PMI_RANK}.out 2> app_rank_clean_\${PMI_RANK}.err
echo 'end of parallel print out'
exit
EOF
      cat ./parallel_print.sh
      chmod 755 parallel_print.sh
      ls -lrt ./parallel_print.sh
      mpirun -np 8 ./parallel_print.sh ../gem_main
      rm -rf output_per_mpi_rank
      mkdir output_per_mpi_rank
      mv app_rank* ./output_per_mpi_rank/
    fi

    if [ $profiling == "vtune" ]; then 
      # turn off libomptarget profile and debug
      export LIBOMPTARGET_PLUGIN_PROFILE=F
      export LIBOMPTARGET_DEBUG=0
      # reset result folder, otherwise vtune has a high chance of failure
      rm -rf ./vtune_result*
      if [ ! -d './vtune_result' ]; then mkdir ./vtune_result; fi
      echo "ready to run executable with vtune"
      date
      #mpirun -np 8 vtune -c gpu-hotspots -knob gpu-sampling-interval=3 -r ./vtune_result ../gem_main #xx
      #mpirun -np 8 vtune -c gpu-hotspots -r ./vtune_result ../gem_main #archived, 75% failed
      #mpirun -np 8 vtune -c gpu-offload -knob gpu-sampling-interval=3 -finalization-mode=deferred -r ./vtune_result ../gem_main #vtune: Error: Cannot find knob gpu-sampling-interval. For a list of available knobs, use -help collect gpu-offload
      #mpirun -np 8 vtune -c gpu-offload -data-limit=0 -finalization-mode=deferred -r ./vtune_result ../gem_main #collected data successfully

      #mpirun -np 8 vtune -c gpu-hotspots -finalization-mode=deferred -r ./vtune_result ../gem_main #collected data successfully 
      #mpirun -np 8 vtune -c gpu-offload -data-limit=0 -finalization-mode=deferred -r ./vtune_result ../gem_main # core dump 
      #mpirun -np 8 vtune -c gpu-offload -data-limit=0 -finalization-mode=deferred -knob collect-cpu-gpu-bandwidth=true -r ./vtune_result ../gem_main # sdp693160 vtune: Error: CPU-GPU bandwidth collection requires the sampling driver to be enabled on the system. To continue the analysis, install the sampling driver or disable the "Analyze CPU-GPU bandwidth" knob.
      mpirun -np 8 vtune -c hpc-performance -data-limit=0 -finalization-mode=deferred -r ./vtune_result ../gem_main #collected data successfully 
      echo "vtune run finished."
      date 
# vtune data finalization command, needs to be ran separately: nohup vtune -report summary -r ./archived_hpc-performance_20240124a-vtune_result.sdp125072 > archived_hpc-performance_20240124a-vtune_result.sdp125072_nohup.out 2>&1 &
    fi

    if [ $profiling == "onetrace" ]; then 
      onetrace --chrome-call-logging --chrome-device-timeline mpirun -np 8 ../gem_main
    fi

    if [ profiling == "advi_roofline" ]; then 
      #advisor --collect=roofline --project-dir=./advi_results -- mpirun -np 8 ../gem_main 
      ##roofline analysis needs to run the exe twice, so this line probably fails because the exe is not reset correctly.

      advisor --collect=survey --profile-gpu --project-dir=./advi_results -- mpirun -np 8 ../gem_main 
      #reset the input/output to run the exe
      rm -rf out matrix dump
      rm 1d.dat rz.dat eqdat eqflux xpp gem.out zprof plot
      rm flux yyre fluxa indicator gtildi gtilde
      rm parallel_print.sh
      rm app_rank_*
      rm gem.256.in
      rm core*

      mkdir -p out matrix dump
      cp /nfs/site/home/shiquans/test-20240213-GEM/gem_simple_v2/case_one_gpu/* .
      cp gem.template.in gem.$i.in
      sed -i 's/XXX/'$i'/g' gem.$i.in
      mv gem.$i.in gem.in
 
      cp gem.$i.in gem.in
      # check gpus health, all device memory should be cleaned up except 7Mb
      sysmon
      #advisor --collect=projection --profile-gpu --model-baseline-gpu --project-dir=./advi_results
      advisor --collect=tripcounts --flop --profile-gpu --project-dir=./advi_results -- mpirun -np 8 ../gem_main 

      # generate html interactive report
      advisor --report=all --project-dir=./advi_results --report-output=./gpu_roofline_report.html
      advisor --report=roofline --gpu --project-dir=./advi_results --report-output=./gpu_roofline.html --data-type=float
    fi

    if [ $profiling == "onetrace" ]; then 
      onetrace --chrome-call-logging --chrome-device-timeline mpirun -np 8 ../gem_main
    fi

    cp plot plot.$i.n1.gpu

done
cd ../
fi    

