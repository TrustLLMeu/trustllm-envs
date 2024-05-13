# This version of dataset merging for NeMo was implemented on top of
# `Megatron-LM/tools/merge_datasets.py` revision
# ad53b1e38689a0ceed75ade7821f4e6c7554abb4.

from argparse import ArgumentParser
import importlib
import os
import shutil
import sys
from typing import Type

import numpy

from nemo.collections.nlp.data.language_modeling.megatron.indexed_dataset import (
    MMapIndexedDataset as _MMapIndexedDataset,
    MMapIndexedDatasetBuilder as _MMapIndexedDatasetBuilder,
    data_file_path as get_bin_path,
    index_file_path as get_idx_path,
)


class MMapIndexedDataset(_MMapIndexedDataset):
    def __init__(self, path_prefix: str, multimodal: bool = False) -> None:
        super().__init__(path_prefix)

    @property
    def index(self):
        return self._index


class MMapIndexedDatasetBuilder(_MMapIndexedDatasetBuilder):
    def __init__(
            self,
            bin_path: str,
            dtype: Type[numpy.number] = numpy.int32,
            multimodal: bool = False,
    ):
        super().__init__(bin_path, dtype)

    def merge_file_(self, another_file):
        # Concatenate index
        index = MMapIndexedDataset.Index(get_idx_path(another_file))
        assert index.dtype == self._dtype

        offset = len(self._sizes)
        for size in index.sizes:
            self._sizes.append(size)
        self._doc_idx.extend((offset + index.doc_idx)[1:])

        # Concatenate data
        with open(get_bin_path(another_file), 'rb') as f:
            shutil.copyfileobj(f, self._data_file)

    def add_index(self, *args, **kwargs):
        return self.merge_file_(*args, **kwargs)


def parse_args():
    parser = ArgumentParser()
    parser.add_argument('--merge-script', required=True)
    return parser.parse_known_args()


def import_merge_datasets(merge_script: str):
    module_name = 'merge_datasets'
    spec = importlib.util.spec_from_file_location(module_name, merge_script)
    merge_datasets = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = merge_datasets
    spec.loader.exec_module(merge_datasets)
    return merge_datasets


def patch_imports(merge_datasets):
    merge_datasets.MMapIndexedDataset = MMapIndexedDataset
    merge_datasets.MMapIndexedDatasetBuilder = MMapIndexedDatasetBuilder
    merge_datasets.get_bin_path = get_bin_path
    merge_datasets.get_idx_path = get_idx_path


def main():
    args, passthrough_args = parse_args()
    assert os.path.isfile(args.merge_script)

    merge_datasets = import_merge_datasets(args.merge_script)
    patch_imports(merge_datasets)

    sys.argv = [args.merge_script] + passthrough_args
    merge_datasets.main()


if __name__ == '__main__':
    main()
