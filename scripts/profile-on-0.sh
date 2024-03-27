#!/bin/bash

if [[ "${PMI_RANK}" -eq 0 ]]; then
	LIBOMPTARGET_PLUGIN_PROFILE=T $@
else
	$@
fi
