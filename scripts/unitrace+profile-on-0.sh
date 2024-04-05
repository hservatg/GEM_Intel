#!/bin/bash

if [[ "${PMI_RANK}" -eq 0 ]]; then
	LIBOMPTARGET_PLUGIN_PROFILE=T unitrace $@ > STDOUT.${PMI_RANK} 2> STDERR.${PMI_RANK}
else
	$@ > STDOUT.${PMI_RANK} 2> STDERR.${PMI_RANK}
fi
