#!/usr/bin/env bash

# Set up PyTorch environment variables so that we build kernels only
# for relevant GPU architectures.

set -euo pipefail

# Do all of this only if we have NVCC available at all.
if [ "$(command -v nvcc)" ]; then
    _cuda_ver="$(nvcc --version | awk 'match($0, / release [0-9.]+,/) { prefix_len=length(" release "); print substr($0, RSTART + prefix_len, RLENGTH - prefix_len - 1); }')"
    _cuda_major_ver="$(echo "$_cuda_ver" | cut -d . -f 1)"
    _cuda_minor_ver="$(echo "$_cuda_ver" | cut -d . -f 2)"

    # Build GPU kernels for the following architectures, based on CUDA
    # version availability:
    # - V100 (CC 7.0)
    # - A100 (CC 8.0)
    # - H100 (CC 9.0)

    export TORCH_CUDA_ARCH_LIST=''
    # V100 requires CUDA >=9.0
    if [ "$_cuda_major_ver" -ge 9 ]; then
        TORCH_CUDA_ARCH_LIST="7.0"
    fi
    # A100 requires CUDA >=11.0
    if [ "$_cuda_major_ver" -ge 11 ]; then
        TORCH_CUDA_ARCH_LIST="$TORCH_CUDA_ARCH_LIST;8.0"
    fi
    # H100 requires CUDA >=11.8
    if [ "$_cuda_major_ver" -gt 11 ]; then
        TORCH_CUDA_ARCH_LIST="$TORCH_CUDA_ARCH_LIST;9.0"
    elif [ "$_cuda_major_ver" -eq 11 ] && [ "$_cuda_minor_ver" -ge 8 ]; then
        TORCH_CUDA_ARCH_LIST="$TORCH_CUDA_ARCH_LIST;9.0"
    fi
elif [ -n "$cuda_compute_capability" ]; then
    export TORCH_CUDA_ARCH_LIST="$cuda_compute_capability"
fi
