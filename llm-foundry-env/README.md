# TrustLLM llm-foundry environment

The container-based environment on using llm-foundry, with example
scripts for JSC systems.

## Usage

### Quickstart

This will set up the software stack, preprocess data, and run a
training.

1. SSH onto a GPU-focused supercomputer such as JUWELS Booster for
   setting up.
1. `git clone` this repository if it does not exist yet:

   ```shell
   [ -d trustllm-envs ] || git clone https://github.com/TrustLLMeu/trustllm-envs.git
   ```
1. Configure project-global paths and – most importantly – the
   container library to use to your liking in
   `trustllm-envs/global_configuration.sh`.
1. Configure paths concerning the llm-foundry environment to your
   liking in `trustllm-envs/llm-foundry-env/configuration.sh`.
1. Switch into the llm-foundry environment's directory:

   ```shell
   cd trustllm-envs/llm-foundry-env
   ```
1. Build the llm-foundry container:

   ```shell
   nice bash build_container.sh
   ```
1. To prevent overwriting the actively used container, we use a
   different path to build the container. This means we have to move
   the container to another location, where we expect the active
   container to be:

   ```shell
   bash move_built_container_to_active.sh
   ```
1. Set up the rest of the software stack:

   ```shell
   nice bash set_up.sh
   ```
1. SSH onto a CPU-focused supercomputer such as JUWELS Cluster for CPU
   tasks.
1. Preprocess the training data, tokenizing it and converting it to
   the binary format used by llm-foundry. Here is an example assuming
   you're on JUWELS Cluster:

   ```shell
   sbatch jsc/preprocess_data_jwc.sbatch
   ```
1. SSH onto the GPU-focused supercomputer such as JUWELS Booster for
   GPU tasks.
1. Run a pre-training task. Here is an example assuming you're on
   JUWELS Booster:

   ```shell
   sbatch jsc/run_training_jwb.sbatch
   ```

### Data preprocessing

We prefer to use CPU supercomputers like JUWELS Cluster for
CPU-intensive tasks such as large-scale data preprocessing, because
they have CPU-only nodes so we don't waste our GPU budget (in the case
of JUWELS Cluster also optionally a few nodes with higher RAM).

```shell
sbatch jsc/preprocess_data_jwc.sbatch
```

### Training

We prefer to use GPU supercomputers like JUWELS Booster for
GPU-intensive tasks such as model training, because they have
(stronger) graphics cards.

```shell
sbatch jsc/run_training_jwb.sbatch
```

### Caveats

We do not have internet access on JSC systems' compute nodes. If you
want to make use of existing HuggingFace models, tokenizers, or
datasets, you will have to download them in advance on a login node.

To do that, simply start up a shell in the container, then
pre-download whatever you need:

```shell
bash container_run.sh bash

# Now inside the container:
# Make sure we are in "online" mode.
export HF_DATASETS_OFFLINE=0
export HF_EVALUATE_OFFLINE=0
export HF_HUB_OFFLINE=0
export TRANSFORMERS_OFFLINE=0

# Pre-download an example model.
python -c 'from transformers import AutoModel; AutoModel.from_pretrained("gpt2")'

# Pre-download an example tokenizer; once with `tokenizers` package, once with `transformers` package.
python -c 'from tokenizers import Tokenizer; Tokenizer.from_pretrained("gpt2")'
python -c 'from transformers import AutoTokenizer; AutoTokenizer.from_pretrained("gpt2")'

# Pre-download an example dataset.
python -c 'from datasets import load_dataset; load_dataset("wikitext", "wikitext-103-raw-v1")'

# Pre-download an example metric; once with `evaluate` package, once with `datasets` package (deprecated).
python -c 'import evaluate; evaluate.load("accuracy")'
python -c 'from datasets import load_metric; load_metric("accuracy")'
```

## Background information

This section is a work in progress. It will contain lower-level
details of things we do and why.

<!-- We are working with read-only Apptainer containers. This means TODO -->
