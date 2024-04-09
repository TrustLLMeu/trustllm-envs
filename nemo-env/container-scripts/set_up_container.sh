#!/usr/bin/env bash

# In this script, we set up our Python virtual environment, installing
# the repositories specified in the `repos` variable in
# `configuration.sh`.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../container-scripts/activate_container.sh setup

# Create the patched Triton file.
sed 's|libs = subprocess\..*$|libs = "/usr/local/cuda/lib64/stubs/libcuda.so"|g' /usr/local/lib/python3.10/dist-packages/triton/common/build.py > "$scratch_dir"/triton-build-patch.py
# Create the patched Lightning file.
sed 's|root_node = \(self\.resolve_root_node_address(.*)\)$|root_node = os.getenv("MASTER_ADDR", \1)|g' /usr/local/lib/python3.10/dist-packages/lightning_fabric/plugins/environments/slurm.py  > "$scratch_dir"/slurm-master-addr-patch.py

# Create or activate the Python virtual environment
if ! [ -d "$venv_dir" ]; then
    python -m venv --system-site-packages --without-pip "$venv_dir"
    source "$venv_dir"/bin/activate
    python -m pip install -U pip
else
    source "$venv_dir"/bin/activate
fi

# Clone and install the external repositories
mkdir -p "$(dirname "$ext_repo_dir")"
for _repo_tuple in "${repos[@]}"; do
    _repo_uri="$(echo "$_repo_tuple" | tr -s ' ' | cut -d ' ' -f 1)"
    _repo_commit="$(echo "$_repo_tuple" | tr -s ' ' | cut -d ' ' -f 2)"
    _repo_pip_install_features="$(echo "$_repo_tuple" | tr -s ' ' | cut -d ' ' -f 3)"

    # Take last part of URI, stripping ".git" at the end if it exists.
    _curr_repo_dir="$ext_repo_dir"/"$(basename "$_repo_uri" .git)"
    if ! [ -d "$_curr_repo_dir" ]; then
        git clone "$_repo_uri" --branch "$_repo_commit" "$_curr_repo_dir"
    fi
    pushd "$_curr_repo_dir"
    # We do not pull so that software state is completely under user
    # control.

    # NeMo-Megatron-Launcher does not support our standard
    # installation method, so we hardcode this exception.
    if [ "$_repo_uri" = 'https://github.com/NVIDIA/NeMo-Megatron-Launcher.git' ]; then
        python -m pip install -r requirements.txt
    else
        python -m pip install -e ."$_repo_pip_install_features"
    fi
    popd
done

# Download all HuggingFace tokenizers that NeMo can use.
python -c 'from transformers import AutoTokenizer; list(AutoTokenizer.from_pretrained(tok_name) for tok_name in ["gpt2", "bert-large-uncased", "bert-large-cased"])'

pop_curr_file
