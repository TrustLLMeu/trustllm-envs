# TrustLLM software environments

Container-based environments for the TrustLLM EU project, with support
for [llm-foundry](https://github.com/mosaicml/llm-foundry) and
[NeMo](https://github.com/NVIDIA/NeMo) (planned). The repository also
includes example scripts for JSC systems.

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
1. Configure project-global paths and – most importantly – the
   container library to use to your liking in
   `trustllm-envs/global_configuration.sh`.

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

# License

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
