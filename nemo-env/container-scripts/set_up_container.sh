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
mkdir -p "$(dirname "$ext_repo_dir")"
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
        if [ "$#" -gt 0 ] && [ "$1" = update ]; then
            # Check whether we have something to stash:
            # Check for staged changes.
            git diff-index --quiet --cached HEAD --
            _is_dirty="$?"
            # Check for unstaged changes.
            git diff-files --quiet
            _is_dirty="$((_is_dirty + $?))"

            git fetch --tags -f
            if ((_is_dirty)); then
                git stash push -m "Update setup at $(date)"
            fi
            git checkout "$_repo_commit"
            if ((_is_dirty)); then
                # The reason we do all of the above is that we want
                # this command to be able to fail, so that updating
                # stops when a user needs to resolve conflicts.
                git stash pop
            fi
        fi
    fi
    # We do not pull so that software state is completely under user
    # control.

    # NeMo-Framework-Launcher does not support our standard
    # installation method, so we hardcode this exception.
    if [ "$_repo_uri" = 'https://github.com/NVIDIA/NeMo-Framework-Launcher.git' ]; then
        python -m pip "${_pip_install_args[@]}" -r requirements.txt
    else
        python -m pip "${_pip_install_editable_args[@]}" ."$_repo_pip_install_features"
    fi
    popd
done

# Explicitly install Megatron-LM repo last again. We do this in such a
# complicated way so that the extra install features are found.
for _repo_tuple in "${repos[@]}"; do
    _repo_uri="$(echo "$_repo_tuple" | tr -s ' ' | cut -d ' ' -f 1)"
    if [ "$_repo_uri" != 'https://github.com/NVIDIA/Megatron-LM.git' ]; then
        continue
    fi
    _repo_pip_install_features="$(echo "$_repo_tuple" | tr -s ' ' | cut -d ' ' -f 3)"

    _curr_repo_dir="$ext_repo_dir"/"$(basename "$_repo_uri" .git)"
    pushd "$_curr_repo_dir"
    python -m pip "${_pip_install_editable_args[@]}" ."$_repo_pip_install_features"
    popd
done

# Install grouped GEMM for optional MoE functionality.
python -m pip "${_pip_install_args[@]}" git+https://github.com/fanshiqing/grouped_gemm@v1.0
# Install HuggingFace Transformers again separately since newer
# versions cause errors with NeMo.
python -m pip "${_pip_install_args[@]}" 'transformers<4.41.0'

if ((_is_installing)); then
    # Create the patched Lightning file.
    sed 's|root_node = \(self\.resolve_root_node_address(.*)\)$|root_node = os.getenv("MASTER_ADDR", \1)|g' "$venv_dir"/lib/python3.10/site-packages/lightning_fabric/plugins/environments/slurm.py  > "$scratch_dir"/slurm-master-addr-patch.py

    if ! ((_is_offline)); then
        # Download all HuggingFace tokenizers that NeMo can use.
        python -c 'from transformers import AutoTokenizer; list(AutoTokenizer.from_pretrained(tok_name) for tok_name in ["gpt2", "bert-large-uncased", "bert-large-cased"])'
    fi
fi

pop_curr_file
