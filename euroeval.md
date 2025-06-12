# EuroEval

## Setting up [EuroEval](https://euroeval.com/)

### Install dependencies
- Install [pyenv](https://github.com/pyenv/pyenv) and [pyenv-virtualenv](https://github.com/pyenv/pyenv-virtualenv)
- Install python version 3.11.10 (compatibility middle-ground with sentencepiece and euroeval)
  ```bash
      pyenv install 3.11
      pyenv global 3.11
  ```
- Create a virtual environment
- Install required modules
- Install cmake:
  ```bash
      pip install cmake==3.31.6
  ```
- Install sentencepiece and upgrade setuptools:
  ```bash
      pip install sentencepiece
      pip install --upgrade setuptools
  ```

### Install EuroEval
  ```bash
      pip install 'euroeval[all]'
  ```

## Using the Blablador API
- Create API key on the [Helmholtz Codebase](https://codebase.helmholtz.cloud/-/user_settings/personal_access_tokens).
- Define api_base and api_key
  ```python
      api_key = "glpat-*********************"
      api_base = "https://api.helmholtz-blablador.fz-juelich.de/v1"
  ```
- Verify your API communication is successful
  ```python
      import requests
      import os
      
      headers =  {
        'accept': 'application/json',
        'Authorization': f'Bearer {api_key}',
        'Content-Type': 'application/json'
      }
      
      response = requests.get(os.path.join(api_base, "models"), headers=headers)
      response.json()
  ```

## Implement EuroEval
- For EuroEval to be able to reach blablador-hosted models, you need to append "openai/" to the model name. (This is a requirement from the litellm module > see code snippet below)
  ```python
      from litellm import completion
  
      completion(
          model="openai/alias-reasoning",
          messages=[{"role": "user", "content": "What is your name? answer in 3 words."}],
          api_base=api_base,
          api_key=api_key,
          temperature=0.7,
          top_p=1,
          top_k=-1,
          n=1,
          max_tokens=1000,
          stop="string",
          stream=False,
          presence_penalty=0,
          frequency_penalty=0,
          user="string"
      )
  ```


## References:
```
@article{nielsen2024encoder,
  title={Encoder vs Decoder: Comparative Analysis of Encoder and Decoder Language Models on Multilingual NLU Tasks},
  author={Nielsen, Dan Saattrup and Enevoldsen, Kenneth and Schneider-Kamp, Peter},
  journal={arXiv preprint arXiv:2406.13469},
  year={2024}
}
@inproceedings{nielsen2023scandeval,
  author = {Nielsen, Dan Saattrup},
  booktitle = {Proceedings of the 24th Nordic Conference on Computational Linguistics (NoDaLiDa)},
  month = may,
  pages = {185--201},
  title = {{ScandEval: A Benchmark for Scandinavian Natural Language Processing}},
  year = {2023}
}
```