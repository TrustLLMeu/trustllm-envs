#!/usr/bin/env bash

if ! [ -f "$1" ]; then
    echo "File supplied for cleanup does not exist"
fi

module purge
module load Stages/2025 GCC OpenMPI mpifileutils
drm "$@"
