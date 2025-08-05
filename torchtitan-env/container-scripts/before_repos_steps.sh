#!/usr/bin/env bash

# Take set-up steps after external repositories have been installed.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/configure_pip_install_variables.sh

# python -m pip "${_pip_install_args[@]}" 'torch==2.7.1'

# Install Rust
_cpu_arch="$(uname -m)"
_rust_installer_dir="$rust_offline_dir"/rust-"$rust_ver"-"$_cpu_arch"-unknown-linux-gnu
mkdir -p "$_rust_installer_dir"
_rust_installer_file="$_rust_installer_dir".tar.xz
if ! [ -d "$_rust_installer_dir" ]; then
    if ! [ -f "$_rust_installer_file" ]; then
        if ! ((_is_offline)); then
            curl --proto '=https' --tlsv1.2 -sSf -o "$_rust_installer_file" \
                 https://static.rust-lang.org/dist/"$(basename "$_rust_installer_file")"
        else
            echo 'Cannot install offline because Rust installer directory' \
                 'was not found. Please place Rust installer directory at' \
                 "\`$_rust_installer_dir\`. See" \
                 'https://forge.rust-lang.org/infra/other-installation-methods.html#standalone-installers' \
                 'for more information.'
        fi
    fi
    tar xJf "$_rust_installer_file"
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
