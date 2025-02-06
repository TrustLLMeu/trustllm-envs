#!/usr/bin/env bash

# Take set-up steps after external repositories have been installed.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/configure_pip_install_variables.sh

# Most version specifications here from
# `Megatron-LM/Dockerfile.ci.dev` and
# `Megatron-LM/requirements/pytorch:24.07/requirements.txt`.
# Install grouped GEMM for optional MoE functionality. Latest version
# as specified in
# `Megatron-LM/megatron/core/transformer/moe/grouped_gemm_util.py`.
python -m pip "${_pip_install_args[@]}" \
       git+https://github.com/fanshiqing/grouped_gemm@v1.1.4
# Install additional tokenizer libraries. Latest versions.
python -m pip "${_pip_install_args[@]}" sentencepiece tiktoken
# Install HuggingFace Transformers for various scripts. Accelerate is
# installed to enable automatic device placement.
python -m pip "${_pip_install_args[@]}" accelerate transformers
# Install HuggingFace Tokenizers and Datasets just because.
python -m pip "${_pip_install_args[@]}" tokenizers datasets
# Install WandB for a logging alternative. Latest version.
python -m pip "${_pip_install_args[@]}" wandb
# Install Flask packages for inference server. Latest version.
python -m pip "${_pip_install_args[@]}" flask-restful
# Install TensorRT Model Optimizer for faster inference.
python -m pip "${_pip_install_args[@]}" 'nvidia-modelopt[torch]>=0.19.0'
# Install Zarr and TensorStore for sharded checkpointing. Not really
# necessary since FSDP-2 does not work with these backends, but just
# for completeness sake. TensorStore version specified in
# `Megatron-LM/megatron/core/dist_checkpointing/strategies/base.py`.
python -m pip "${_pip_install_args[@]}" zarr tensorstore==0.1.45
# Install NLTK for data preprocessing. We probably don't want to use
# it, but we include it for completeness sake.
python -m pip "${_pip_install_args[@]}" nltk
# Install einops for, e.g., Mamba. Latest version.
python -m pip "${_pip_install_args[@]}" einops
# Install other Mamba dependencies. Latest versions.
env CAUSAL_CONV1D_FORCE_BUILD=TRUE \
    python -m pip "${_pip_install_args[@]}" \
    git+https://github.com/Dao-AILab/causal-conv1d.git@v1.4.0
# Install Mamba package with `--no-deps` due to Triton. We should have
# all dependencies covered.
env MAMBA_FORCE_BUILD=TRUE \
    python -m pip "${_pip_install_args[@]}" --no-deps \
    git+https://github.com/state-spaces/mamba.git@v2.2.2

# Here we uninstall a potentially different Triton again so we have
# the version in the container. That way, it doesn't cause problems
# with the container's PyTorch relying on version-specific internals.
! python -m pip uninstall -y triton

# Install `torchrun_jsc` to fix distributed job launching.
python -m pip "${_pip_install_args[@]}" torchrun_jsc

# Other dependencies we assume to be available in the container:
# - TransformerEngine
# - Apex
# - FlashAttention
# - torchvision
# - TensorBoard

# Install testing tools. Latest versions.
python -m pip "${_pip_install_args[@]}" pytest pytest-cov pytest_mock wrapt

if ((_is_installing)) && ! ((_is_offline)); then
    # Download all HuggingFace tokenizers that Megatron-LM explicitly
    # uses (GPT-2 only in testing).
    python -c 'from transformers import AutoTokenizer; list(AutoTokenizer.from_pretrained(tok_name) for tok_name in ["gpt2", "bert-large-uncased", "bert-large-cased"])'
fi

pop_curr_file
