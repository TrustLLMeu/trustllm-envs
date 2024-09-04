# Copyright 2022 MosaicML LLM Foundry authors
# SPDX-License-Identifier: Apache-2.0

# Patched on top of the same file for JSON without `_parallel` at
# revision 96dba068f5b7acb3246b4ee9749cf5ef1aad6ea1.
# This standalone version obviously does not benefit from updates to the
# original version, but is thus supposed to be more stable.

"""Streaming dataset conversion scripts for Parquet files."""
from argparse import ArgumentParser, Namespace
import os
from enum import Enum
from glob import glob
from typing import Optional

import datasets as hf_datasets
from datasets.distributed import split_dataset_by_node
from streaming import MDSWriter
from torch.utils.data import IterableDataset
from tqdm import tqdm
from transformers import AutoTokenizer, PreTrainedTokenizerBase

from llmfoundry.data import ConcatTokensDataset, NoConcatDataset


class ConcatMode(Enum):
    NO_CONCAT = 'NO_CONCAT'
    CONCAT_TOKENS = 'CONCAT_TOKENS'


def patch_dataset_sharding():
    import itertools

    def my_iter(self):
        ex_iterator = iter(self.ex_iterable)
        return itertools.islice(ex_iterator, self.offset, None, self.step)

    hf_datasets.iterable_dataset.StepExamplesIterable.__iter__ = my_iter


def build_hf_dataset(
    path: str,
    split: str,
    mode: ConcatMode,
    max_length: Optional[int] = None,
    bos_text: str = '',
    eos_text: str = '',
    no_wrap: bool = False,
    get_bos_token_id: bool = False,
    get_eos_token_id: bool = False,
    recurse: bool = False,
    tokenizer: PreTrainedTokenizerBase = None,
) -> IterableDataset:
    """Build an IterableDataset over the HF C4 or pile source data.

    Args:
        path (str): Dataset name
        split (str): Split name.
        mode (ConcatMode): NO_CONCAT, or CONCAT_TOKENS
        max_length (int): The length of concatenated tokens
        bos_text (str): text to insert at the beginning of each sequence
        eos_text (str): text to insert at the end of each sequence
        no_wrap (bool): if concatenating, whether to wrap text across `max_length` boundaries
        get_bos_token_id (bool): whether to get the token ID to insert at the beginning of each
            sequence from the tokenizer
        get_eos_token_id (bool): whether to get the token ID to insert at the end of each sequence
            from the tokenizer
        recurse (bool): Whether to recurse into subdirectories of the given path to look for data
            files.
        tokenizer (PreTrainedTokenizerBase): if mode is CONCAT_TOKENS, the tokenizer to use
        data_subset (str): Referred to as "name" in HuggingFace datasets.load_dataset.
            Typically "all" (The Pile) or "en" (c4).

    Returns:
        An IterableDataset.
    """
    if os.path.isdir(path):
        if recurse:
            data_files = filter(
                os.path.isfile,
                glob(f'{path}/**/*', recursive=True),
            )
        else:
            data_files = glob(f'{path}/*')
    else:
        data_files = path

    world_size = int(os.environ['WORLD_SIZE'])
    rank = int(os.environ['RANK'])

    hf_dataset = hf_datasets.load_dataset(
        'parquet',
        data_files=data_files,
        split=split,
        streaming=True,
    )
    hf_dataset = split_dataset_by_node(
        hf_dataset,
        rank=rank,
        world_size=world_size,
    )

    if mode == ConcatMode.NO_CONCAT:
        dataset = NoConcatDataset(hf_dataset)
    else:
        if not isinstance(tokenizer, PreTrainedTokenizerBase):
            raise ValueError(
                f'{tokenizer=} must be of type PreTrainedTokenizerBase',
            )
        if max_length is None:
            raise ValueError(f'max_length must be set.')
        if bos_text + eos_text == '' and not (get_bos_token_id and get_eos_token_id):
            test_tokens = tokenizer('test')
            if test_tokens['input_ids'][
                0] != tokenizer.bos_token_id and test_tokens['input_ids'][
                    -1] != tokenizer.eos_token_id:
                tok_error_msg = 'This tokenizer does not insert an EOS nor BOS token. '
                tok_error_msg += 'Concatenating with this tokenizer will result in sequences being '
                tok_error_msg += 'attached without a separating token. Please use another tokenizer, '
                tok_error_msg += 'such as facebook/opt-125m, or specify EOS/BOS text with e.g. '
                tok_error_msg += '--bos_text=<|endoftext|>.'
                raise ValueError(tok_error_msg)
        dataset = ConcatTokensDataset(
            hf_dataset=hf_dataset,
            tokenizer=tokenizer,
            max_length=max_length,
            bos_text=bos_text,
            eos_text=eos_text,
            no_wrap=no_wrap,
            get_bos_token_id=get_bos_token_id,
            get_eos_token_id=get_eos_token_id,
        )
    return dataset


def convert_dataset_parquet(
    path: str,
    out_root: str,
    compression: Optional[str],
    concat_tokens: Optional[int],
    split: str,
    tokenizer: Optional[str] = None,
    bos_text: str = '',
    eos_text: str = '',
    no_wrap: bool = False,
    get_bos_token_id: bool = False,
    get_eos_token_id: bool = False,
    use_fast: bool = True,
    recurse: bool = False,
    num_workers: Optional[int] = None,
) -> None:
    """Create C4/pile streaming dataset.

    Args:
        path (str): Path to the input data file
        out_root (str): Output root directory
        compression (Optional[str]): Compression type, if any
        concat_tokens (Optional[int]): Convert text to tokens and concatenate up to this many tokens
        split (str): Dataset split to process
        tokenizer (Optional[str]): Tokenizer name
        bos_text (str): Text to insert at the beginning of each sequence
        eos_text (str): Text to insert at the end of each sequence
        no_wrap (bool): Do not wrap text across max_length boundaries
        get_bos_token_id (bool): Whether to get the token ID to insert at the beginning of each
            sequence from the tokenizer
        get_eos_token_id (bool): Whether to get the token ID to insert at the end of each sequence
            from the tokenizer
        use_fast (bool): Whether to use a fast version of the tokenizer.
        recurse (bool): Whether to recurse into subdirectories of the given path to look for data
            files.
        num_workers (Optional[int]): Number of workers for data loading
    """
    if concat_tokens is not None:
        mode = ConcatMode.CONCAT_TOKENS
        built_tokenizer = AutoTokenizer.from_pretrained(tokenizer, use_fast=use_fast)
        # we will enforce length, so suppress warnings about sequences too long for the model
        built_tokenizer.model_max_length = int(1e30)
        columns = {'tokens': 'ndarray:int32'}
    else:
        mode = ConcatMode.NO_CONCAT
        built_tokenizer = None
        columns = {'text': 'str'}

    if 'WORLD_SIZE' not in os.environ or 'RANK' not in os.environ:
        print(
            'The `WORLD_SIZE` and `RANK` environment variables need to be '
            'defined for parallel data processing, where `WORLD_SIZE` is the '
            'number of processes, and `RANK` is the index of this process.'
        )
        exit(1)

    rank = int(os.environ['RANK'])

    # Get samples
    dataset = build_hf_dataset(
        path=path,
        split=split,
        mode=mode,
        max_length=concat_tokens,
        bos_text=bos_text,
        eos_text=eos_text,
        no_wrap=no_wrap,
        get_bos_token_id=get_bos_token_id,
        get_eos_token_id=get_eos_token_id,
        recurse=recurse,
        tokenizer=built_tokenizer,
    )

    print('here')

    # Write samples
    print(f'Converting to MDS format...')
    print(
        f'Note that the progress bar is based on the dataset length before tokenization.',
    )
    print(f'It will finish at a value below 100% if tokenizing')
    with MDSWriter(
        columns=columns,
        out=os.path.join(out_root, str(rank)),
        compression=compression,
    ) as out:
        # Can help to remove `tqdm`.
        # for sample in tqdm(dataset):
        for sample in dataset:
            out.write(sample)


def convert_dataset_parquet_from_args(
    path: str,
    out_root: str,
    compression: Optional[str],
    concat_tokens: Optional[int],
    split: str,
    tokenizer: Optional[str] = None,
    bos_text: Optional[str] = None,
    eos_text: Optional[str] = None,
    no_wrap: bool = False,
    get_bos_token_id: bool = False,
    get_eos_token_id: bool = False,
    use_fast: bool = True,
    recurse: bool = False,
    num_workers: Optional[int] = None,
) -> None:
    """A wrapper for `convert_dataset_parquet` that parses arguments.

    Args:
        path (str): Path to the input data file
        out_root (str): Output root directory
        compression (Optional[str]): Compression type, if any
        concat_tokens (Optional[int]): Convert text to tokens and concatenate up to this many tokens
        split (str): Dataset split to process
        tokenizer (Optional[str]): Tokenizer name
        bos_text (Optional[str]): Text to insert at the beginning of each sequence
        eos_text (Optional[str]): Text to insert at the end of each sequence
        no_wrap (bool): Do not wrap text across max_length boundaries
        get_bos_token_id (bool): Whether to get the token ID to insert at the beginning of each
            sequence from the tokenizer
        get_eos_token_id (bool): Whether to get the token ID to insert at the end of each sequence
            from the tokenizer
        use_fast (bool): Whether to use a fast version of the tokenizer.
        recurse (bool): Whether to recurse into subdirectories of the given path to look for data
            files.
        num_workers (Optional[int]): Number of workers for data loading

    Raises:
        ValueError: If the out_root directory exists and contains files that overlap with the requested splits
        ValueError: If concat_tokens is set and a tokenizer is not provided
    """
    if os.path.isdir(out_root) and len(
        set(os.listdir(out_root)).intersection(set(split)),
    ) > 0:
        raise ValueError(
            f'--out_root={out_root} contains {os.listdir(out_root)} which cannot overlap with the requested splits {split}.',
        )

    # Make sure we have needed concat options
    if (
        concat_tokens is not None and isinstance(concat_tokens, int) and
        tokenizer is None
    ):
        ValueError(
            'When setting --concat_tokens, you must specify a --tokenizer',
        )

    # now that we have validated them, change BOS/EOS to strings
    if bos_text is None:
        bos_text = ''
    if eos_text is None:
        eos_text = ''

    convert_dataset_parquet(
        path=path,
        out_root=out_root,
        compression=compression,
        concat_tokens=concat_tokens,
        split=split,
        tokenizer=tokenizer,
        bos_text=bos_text,
        eos_text=eos_text,
        no_wrap=no_wrap,
        get_bos_token_id=get_bos_token_id,
        get_eos_token_id=get_eos_token_id,
        use_fast=use_fast,
        recurse=recurse,
        num_workers=num_workers,
    )


def parse_args() -> Namespace:
    """Parse commandline arguments."""
    parser = ArgumentParser(
        description=
        'Convert dataset into MDS format, optionally concatenating and tokenizing',
    )
    parser.add_argument('--path', type=str, required=True)
    parser.add_argument(
        '--recurse',
        action='store_true',
        help=(
            'Whether to recurse into subdirectories of the given path to look '
            'for data files.'
        ),
    )
    parser.add_argument('--out_root', type=str, required=True)
    parser.add_argument('--compression', type=str, default=None)

    group = parser.add_mutually_exclusive_group(required=False)
    group.add_argument(
        '--concat_tokens',
        type=int,
        help='Convert text to tokens and concatenate up to this many tokens',
    )
    parser.add_argument('--split', type=str, default='train')

    parser.add_argument('--tokenizer', type=str, required=False, default=None)
    parser.add_argument('--bos_text', type=str, required=False, default=None)
    parser.add_argument('--eos_text', type=str, required=False, default=None)
    parser.add_argument('--no_wrap', default=False, action='store_true')
    parser.add_argument('--get_bos_token_id', action='store_true')
    parser.add_argument('--get_eos_token_id', action='store_true')
    parser.add_argument('--no_use_fast', action='store_true')

    parsed = parser.parse_args()
    return parsed


if __name__ == '__main__':
    patch_dataset_sharding()
    args = parse_args()
    convert_dataset_parquet_from_args(
        path=args.path,
        out_root=args.out_root,
        compression=args.compression,
        concat_tokens=args.concat_tokens,
        split=args.split,
        tokenizer=args.tokenizer,
        bos_text=args.bos_text,
        eos_text=args.eos_text,
        no_wrap=args.no_wrap,
        get_bos_token_id=args.get_bos_token_id,
        get_eos_token_id=args.get_eos_token_id,
        use_fast=not args.no_use_fast,
        recurse=args.recurse,
    )
