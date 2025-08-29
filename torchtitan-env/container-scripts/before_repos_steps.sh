#!/usr/bin/env bash

# Take set-up steps after external repositories have been installed.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/configure_pip_install_variables.sh

if [ "$(uname -m)" = aarch64 ]; then
    _pytorch_repo_dir="$ext_repo_dir"/pytorch
    if ! [ -d "$_pytorch_repo_dir" ]; then
        mkdir -p "$(dirname "$_pytorch_repo_dir")"
        git clone https://github.com/pytorch/pytorch "$_pytorch_repo_dir"
    fi
    pushd "$_pytorch_repo_dir"
    git fetch --tags -f
    # `torch.version.git_version` of below nightly.
    git checkout dcc2abce2d00bcbd67de3c9502db51a1aa78f933
    git submodule sync
    git submodule update --init --recursive
    python -m pip "${_pip_install_args[@]}" -r requirements.txt
    make triton
    # We install to a custom temporary location because this requires a
    # lot of space.
    tmp_pip_dir="$scratch_dir"/.tmp-pip
    mkdir -p "$tmp_pip_dir"
    mktemp -d -p "$tmp_pip_dir"
    # Use limited number of `MAX_JOBS` to avoid running out of RAM.
    # If ARM+CUDA, set `USE_PRIORITIZED_TEXT_FOR_LD=1`.
    # TODO Only set this when CUDA is found.
    env TMPDIR="$tmp_pip_dir" MAX_JOBS=6 USE_PRIORITIZED_TEXT_FOR_LD=1 \
        python -m pip "${_pip_install_unisolated_editable_args[@]}" .
    rm -rf "$tmp_pip_dir"
    popd
else
    python -m pip "${_pip_install_args[@]}" --pre 'torch==2.9.0.dev20250825' \
           --index-url https://download.pytorch.org/whl/nightly/cu129 \
           --force-reinstall
fi

# Install Rust
_cpu_arch="$(uname -m)"
mkdir -p "$rust_offline_dir"
_rust_installer_dir="$rust_offline_dir"/rust-"$rust_ver"-"$_cpu_arch"-unknown-linux-gnu
_rust_installer_file="$_rust_installer_dir".tar.xz
if ! [ -d "$_rust_installer_dir" ]; then
    if ! [ -f "$_rust_installer_file" ]; then
        if ! ((_is_offline)); then
            curl --proto '=https' --tlsv1.2 -sSf -o "$_rust_installer_file" \
                 https://static.rust-lang.org/dist/"$(basename "$_rust_installer_file")"
        else
            echo 'Cannot install offline because Rust installer directory' \
                 'was not found. Please place Rust installer directory at' \
                 "\`${_rust_installer_dir@Q}\`. See" \
                 'https://forge.rust-lang.org/infra/other-installation-methods.html#standalone-installers' \
                 'for more information.'
        fi
    fi
    pushd "$rust_offline_dir"
    tar xJf "$_rust_installer_file"
    popd
fi
# We get an `ldconfig` warning that we could prevent with
# `--disable-ldconfig`, but it doesn't cause an error code, so we do
# not disable `ldconfig` in case we can use it.
# We install only the minimal required components.
bash "$_rust_installer_dir"/install.sh \
     --prefix="$rust_dir" \
     --components=rustc,rust-std-"$_cpu_arch"-unknown-linux-gnu,cargo

# Put Rust binaries into `PATH`.
export PATH="$rust_dir"/bin:"$PATH"

pop_curr_file
