#OPTION
GPU_OPT=y   ### y-> use OpenACC/GPU; n-> use OpenMP/CPU
DEBUG=n
HOST=ORTCE
###############################################################################
ifneq (,${HOST})
  SYSTEMS := ${HOST}
else
  SYSTEMS := $(shell hostname)
endif

SRCS := $(wildcard *.F90)
OBJS := $(patsubst %.F90,%.o,$(SRCS))
OBJS =  gem_com.o gem_equil.o gem_main.o gem_outd.o gem_fcnt.o gem_fft_wrapper.o gem_gkps_adi.o #adios2_comm_mod.o

#FFTW_INC =-I$(FFTW_DIR)/include
#FFTW_LIB =-L$(FFTW_DIR)/lib -lfftw3_threads -lfftw3 -lfftw3f_threads -lfftw3f
FFTW_LIB = -qmkl
FFTW_INC = -qmkl
LIBS = dfftpack/libdfftpack.a

LIB +=-I${MKLROOT}/include/fftw
LD_LIB +=$(FFTW_LIB)

F90=mpiifx
PLIB = gem_pputil.o

ifneq (,$(findstring frontier,$(SYSTEMS)))
OPT = -O0 -s real64 -hlist=ad -e Zz -homp
ifeq ($(GPU_OPT),y)
    OPT = -O0 -s real64 -hlist=ad -e Zz -hacc -homp -munsafe-fp-atomics -hacc_model=auto_async_none -hacc_model=deep_copy -hacc_model=fast_addr
ifeq ($(DEBUG), y)
    OPT += -g 
endif
    OPT += -DGPU
else
     OPT = -O2 -fiopenmp -fopenmp-targets=spir64 -fsycl -r8 -i8
ifeq ($(DEBUG),y)
    OPT += -g
endif
    OPT += -DOPENMP_CPU
endif
endif
     OPT = -g -DGPU -DOPENACC2OPENMP_ORIGINAL_OPENMP -qopt-report=3 -O2 -fiopenmp -fopenmp-targets=spir64 -r8 -i8 -fpp #AOT
     LFFLAGS = $(OPT) $(OBJS) $(PLIB) $(LIBS) $(LIB) $(LD_LIB) -L${MKLROOT}/lib/intel64 -lmkl_sycl -lmkl_intel_ilp64 -lmkl_intel_thread -lmkl_core -liomp5 -lpthread -ldl
     CFFLAGS = $(OPT) $(LIB) -fpp  

gem_main: gem_equil.o gem_main.o gem_outd.o gem_fcnt.o gem_pputil.o gem_com.o gem_fft_wrapper.o gem_gkps_adi.o
	$(F90) -o gem_main $(LFFLAGS) 

gem_pputil.o: gem_pputil.F90
	$(F90) -c $(OPT) gem_pputil.F90

gem_com.o: gem_com.F90 gem_pputil.o
	$(F90) -c $(OPT) gem_com.F90

gem_equil.o: gem_equil.F90 gem_pputil.o gem_com.o
	$(F90) -c $(OPT) gem_equil.F90

gem_gkps_adi.o: gem_gkps_adi.F90 gem_com.F90 gem_equil.F90 gem_pputil.F90
	$(F90) -c $(OPT) gem_gkps_adi.F90

gem_outd.o: gem_outd.F90 gem_fft_wrapper.o gem_pputil.o gem_com.o gem_equil.o
	$(F90) -c $(OPT) gem_outd.F90

gem_main.o: gem_main.F90 gem_fft_wrapper.o gem_pputil.o gem_com.o gem_equil.o gem_gkps_adi.o #adios2_comm_mod.o mapping.o
	$(F90) -c $(CFFLAGS) gem_main.F90

gem_fcnt.o: gem_fcnt.F90
	$(F90) -c $(OPT) gem_fcnt.F90

gem_fft_wrapper.o: gem_fft_wrapper.F90
	$(F90) -c $(OPT) $(LIB) $(LIBS) gem_fft_wrapper.F90

clean:
	rm -f *.o *.opt *.i *acc.o *acc.s *.lst *.mod *.cg gem_main *.optrpt *.opt.yaml *.modmic
