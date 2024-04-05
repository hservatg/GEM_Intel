#!/bin/bash

if [[ "${PMI_RANK}" -eq 0 ]]; then
	LIBOMPTARGET_PLUGIN_PROFILE=T /nfs/site/home/hservatg/src/applications.analyzers.profilingtoolsinterfaces.gpu.git/tools/ze_data_volume/build/ze_data_volume $@ > STDOUT.${PMI_RANK} 2> STDERR.${PMI_RANK}
else
	$@ > STDOUT.${PMI_RANK} 2> STDERR.${PMI_RANK}
fi
