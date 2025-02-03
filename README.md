# TrustLLM software environments

Container-based environments for the TrustLLM EU project, with support
for [LLM Foundry](https://github.com/mosaicml/llm-foundry),
[Megatron-LM](https://github.com/NVIDIA/Megatron-LM), and
[NeMo](https://github.com/NVIDIA/NeMo). The repository also includes
example scripts for JSC and BSC systems.

## Usage

Please see the software-specific READMEs in their respective
subdirectories.

For completeness sake, the generally viable information is reproduced
here:

1. SSH onto a GPU-focused supercomputer such as JUWELS Booster for
   setting up.
1. `git clone` this repository if it does not exist yet:

   ```shell
   [ -d trustllm-envs ] || git clone https://github.com/TrustLLMeu/trustllm-envs.git
   ```
1. Configure project-global paths and – most importantly – the machine
   name and container library to use to your liking in
   `trustllm-envs/global_configuration.sh`.

### Interactive use

Any interaction with the environment, that especially means code
execution, should be started from inside the container, after sourcing
the Python virtual environment inside the container. Because this is
very error-prone, we provide the `container_run.sh` script that
handles this for you. Any arguments supplied will be forwarded to be
executed inside the container with the appropriate environment setup.
Note, however, that this argument passing is not perfect due to some
container start scripts messing with the arguments. To be absolutely
sure that a command with complex quoting is executed correctly, please
use the container in an interactive session or create a script from
the command and execute that instead.  
For example:

```shell
# Execute a Bash script.
bash container_run.sh bash <example.sh>

# Run a Python script.
bash container_run.sh python <example.py>

# With no arguments: start an interactive shell.
bash container_run.sh
```

It is especially important that you install Python packages only after
using `container_run.sh`, for example by starting an interactive shell
(by executing `bash container_run.sh`) and then running `python -m pip
install <package-name>`.

### Caveats

We do not have internet access on JSC systems' compute nodes. If you
want to make use of existing HuggingFace models, tokenizers, or
datasets, you will have to download them in advance on a login node.

To do that, simply start up a shell in the desired container, then
pre-download whatever you need:

```shell
bash container_run.sh bash

# Now inside the container:
# Make sure we are in "online" mode.
export HF_DATASETS_OFFLINE=0
export HF_EVALUATE_OFFLINE=0
export HF_HUB_OFFLINE=0
export TRANSFORMERS_OFFLINE=0

# Whether to trust remote code; needs to be 1 for custom assets on the hub.
export TRUST_REMOTE_CODE=0

# Pre-download an example model.
python -c 'import os; from transformers import AutoModel; AutoModel.from_pretrained("gpt2", trust_remote_code=bool(os.getenv("TRUST_REMOTE_CODE", 0)))'

# Pre-download an example tokenizer; once with `tokenizers` package, once with `transformers` package.
python -c 'from tokenizers import Tokenizer; Tokenizer.from_pretrained("gpt2")'
python -c 'import os; from transformers import AutoTokenizer; AutoTokenizer.from_pretrained("gpt2", trust_remote_code=bool(os.getenv("TRUST_REMOTE_CODE", 0)))'

# Pre-download an example dataset.
python -c 'import os; from datasets import load_dataset; load_dataset("wikitext", "wikitext-103-raw-v1", trust_remote_code=bool(os.getenv("TRUST_REMOTE_CODE", 0)))'

# Pre-download an example metric; once with `evaluate` package, once with `datasets` package (deprecated).
python -c 'import evaluate; evaluate.load("accuracy")'
python -c 'import os; from datasets import load_metric; load_metric("accuracy", trust_remote_code=bool(os.getenv("TRUST_REMOTE_CODE", 0)))'
```

### Offline installation

Container images and `pip` packages can be downloaded in advance for
offline installation.

Please see the software-specific READMEs in their respective
subdirectories.

## License

Copyright 2024 Jan Ebert

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
