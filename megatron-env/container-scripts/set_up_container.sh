#!/usr/bin/env bash

# In this script, we set up our Python virtual environment, installing
# the repositories specified in the `repos` variable in
# `configuration.sh`.
#
# If the first argument is "download", the remaining arguments will be
# passed as extra arguments to `pip download`. These can be used, for
# example, to specify the `--platform` or `--python-version` to
# download for.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../container-scripts/activate_container.sh setup

if [ "$#" -gt 0 ] && [ "$1" = download ]; then
    mkdir -p "$pip_offline_dir"

    _is_installing=0
    _is_offline=0
    _pip_install_args=( download -d "$pip_offline_dir" "${@:2}" )
    _pip_install_upgrade_args=( "${_pip_install_args[@]}" )
    _pip_install_editable_args=( "${_pip_install_args[@]}" )
elif [ "$#" -gt 0 ] && [ "$1" = offline ]; then
    if ! [ -d "$pip_offline_dir" ]; then
        echo "\`pip\` packages have not been pre-downloaded for offline" \
             "installation. Please place them at \`$pip_offline_dir\`."
    fi

    _is_installing=1
    _is_offline=1
    _pip_install_args=( install --no-build-isolation --no-index --find-links 'file://'"$pip_offline_dir" )
    _pip_install_upgrade_args=( "${_pip_install_args[@]}" )
    _pip_install_editable_args=( "${_pip_install_args[@]}" -e )
else
    _is_installing=1
    _is_offline=0
    _pip_install_args=( install )
    _pip_install_upgrade_args=( "${_pip_install_args[@]}" -U )
    _pip_install_editable_args=( "${_pip_install_args[@]}" -e )
fi

# Create or activate the Python virtual environment
if ! [ -d "$venv_dir" ]; then
    python -m venv --system-site-packages --without-pip "$venv_dir"
    source "$venv_dir"/bin/activate
    python -m pip "${_pip_install_upgrade_args[@]}" pip
else
    source "$venv_dir"/bin/activate
    if (("$_is_installing")) && (("$_is_offline")); then
        python -m pip "${_pip_install_upgrade_args[@]}" pip
    fi
fi

# Clone and install the external repositories
mkdir -p "$ext_repo_dir"
for _repo_tuple in "${repos[@]}"; do
    _repo_uri="$(echo "$_repo_tuple" | tr -s ' ' | cut -d ' ' -f 1)"
    _repo_commit="$(echo "$_repo_tuple" | tr -s ' ' | cut -d ' ' -f 2)"
    _repo_pip_install_features="$(echo "$_repo_tuple" | tr -s ' ' | cut -d ' ' -f 3)"

    # Take last part of URI, stripping ".git" at the end if it exists.
    _curr_repo_dir="$ext_repo_dir"/"$(basename "$_repo_uri" .git)"
    if ! [ -d "$_curr_repo_dir" ]; then
        git clone "$_repo_uri" "$_curr_repo_dir"
        pushd "$_curr_repo_dir"
        git checkout "$_repo_commit"
    else
        # By default, we do not check out when the repo already exists
        # so that software state is completely under user control.
        pushd "$_curr_repo_dir"

        # Do we maybe have to change the repo's remote URI?
        if [ "$_repo_uri" = 'https://github.com/TrustLLMeu/Megatron-LM.git' ]; then
            _forked_repo_uri=1
        else
            _forked_repo_uri=0
        fi
        # For safety, we upgrade URI of `origin` to our fork.
        # Previously this was the upstream NVIDIA `origin`.
        if ((_forked_repo_uri)) \
           && [ "$(git remote get-url origin)" != "$_repo_uri" ]; then
            git remote add prev-origin "$(git remote get-url origin)"
            git remote set-url origin "$_repo_uri"
            git remote update
        fi

        if [ "$#" -gt 0 ] && [ "$1" = update ]; then
            git fetch --tags -f

            # Check whether we have something to stash: (We have to do
            # it so awkwardly so that Bash does not exit unsuccessful
            # commands.)
            # Check for staged changes.
            ! git diff-index --quiet --cached HEAD --
            _is_clean="$?"
            # Check for unstaged changes.
            ! git diff-files --quiet
            _is_clean="$((_is_clean && $?))"

            if ! ((_is_clean)); then
                git stash push -m "Update setup at $(date)"
            fi
            git checkout "$_repo_commit"
            if ! ((_is_clean)); then
                # The reason we do all of the above is that we want
                # this command to be able to fail, so that updating
                # stops when a user needs to resolve conflicts.
                git stash pop
            fi
        fi
    fi
    # We do not pull so that software state is completely under user
    # control.

    python -m pip "${_pip_install_editable_args[@]}" ."$_repo_pip_install_features"
    popd
done

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
# Install TensorRT Model Optimizer for faster inference. Version
# specification from `Megatron-LM/Dockerfile.ci.dev`.
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
env MAMBA_FORCE_BUILD=TRUE \
    python -m pip "${_pip_install_args[@]}" \
    git+https://github.com/state-spaces/mamba.git@v2.2.2

# Install torchrun_jsc to fix distributed job launching.
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
