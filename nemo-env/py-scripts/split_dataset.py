import os
import sys
import json
import argparse
import shutil
import random

from nemo.collections.nlp.data.language_modeling.megatron.indexed_dataset import (
    MMapIndexedDataset,
    MMapIndexedDatasetBuilder as _MMapIndexedDatasetBuilder,
    data_file_path as get_bin_path,
    index_file_path as get_idx_path,
)


class MMapIndexedDatasetBuilder(_MMapIndexedDatasetBuilder):
    def add_item(self, np_array):
        # Changed due to superflous roundtrip through torch tensors
        self._data_file.write(np_array.tobytes(order='C'))
        self._sizes.append(np_array.size)

def run_split(in_path, left_fmt, right_fmt, right_prob):
    ds = MMapIndexedDataset(in_path)
    dtype = ds._index.dtype
    
    left_path = left_fmt.format(in_path)
    left_builder = MMapIndexedDatasetBuilder(get_bin_path(left_path), dtype)

    right_path = right_fmt.format(in_path)
    right_builder = MMapIndexedDatasetBuilder(get_bin_path(right_path), dtype)

    #for d in tqdm.tqdm(ds):
    for d in ds:
        if random.random() > right_prob:
            builder = left_builder
        else:
            builder = right_builder
        builder.add_item(d)
        builder.end_document()

    left_builder.finalize(get_idx_path(left_path))
    right_builder.finalize(get_idx_path(right_path))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('infile', required=True)
    parser.add_argument('--left_fmt', default='train_{}')
    parser.add_argument('--right_fmt', default='valid_{}')
    parser.add_argument('--right_prob', default=0.1)
    args = parser.parse_args()
    run_split(args.infile, args.left_fmt, args.right_fmt, args.right_prob)
