#!/usr/bin/env bash

# Take set-up steps after external repositories have been installed.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/configure_pip_install_variables.sh

# Install HuggingFace Transformers for various scripts. Accelerate is
# installed to enable automatic device placement.
python -m pip "${_pip_install_args[@]}" accelerate transformers
# Install HuggingFace Tokenizers just because.
python -m pip "${_pip_install_args[@]}" tokenizers

# Install torchrun_jsc to fix distributed job launching.
python -m pip "${_pip_install_args[@]}" 'torchrun_jsc>=0.0.17'

# Install grouped GEMM for optional MoE functionality. Latest commit
# of custom branch.
# We install to a custom temporary location because this requires a
# lot of space.
tmp_pip_dir="$scratch_dir"/.tmp-pip
mkdir -p "$tmp_pip_dir"
mktemp -d -p "$tmp_pip_dir"
env TMPDIR="$tmp_pip_dir" python -m pip "${_pip_install_args[@]}" \
    git+https://github.com/rakkit/grouped_gemm@compile
rm -rf "$tmp_pip_dir"

torchtitan_repo_dir="$ext_repo_dir"/torchtitan
# Install testing tools.
if [ -f "$torchtitan_repo_dir"/dev-requirements.txt ]; then
    python -m pip "${_pip_install_args[@]}" -r "$torchtitan_repo_dir"/dev-requirements.txt
else
    echo "Could not find" \
         "\`${torchtitan_repo_dir@Q}/dev-requirements.txt\`." \
         "Please check whether the file was removed."
fi

if ((_is_installing)) && ! ((_is_offline)); then
    # Download standard HuggingFace SentencePiece tokenizers for
    # templates (TorchTitan explicitly uses only license-locked
    # tokenizers).
    python -c 'from transformers import AutoTokenizer; list(AutoTokenizer.from_pretrained(tok_name) for tok_name in ["google-t5/t5-small"])'
fi

pop_curr_file
