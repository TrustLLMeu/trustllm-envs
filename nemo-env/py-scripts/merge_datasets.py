# Implementation adapted from `Megatron-LM/tools/merge_datasets.py` for
# NeMo at revision ad53b1e38689a0ceed75ade7821f4e6c7554abb4.
# This standalone version obviously does not benefit from updates to the
# original version, but is thus supposed to be more stable.

import os
import sys
import json
import argparse
import shutil

from nemo.collections.nlp.data.language_modeling.megatron.indexed_dataset import (
    MMapIndexedDataset,
    MMapIndexedDatasetBuilder as _MMapIndexedDatasetBuilder,
    data_file_path as get_bin_path,
    index_file_path as get_idx_path,
)


class MMapIndexedDatasetBuilder(_MMapIndexedDatasetBuilder):
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


def get_args():
    parser = argparse.ArgumentParser()

    group = parser.add_argument_group(title="input data")
    group.add_argument(
        "--input",
        type=str,
        required=True,
        help="Path to directory containing all document files to merge",
    )

    group = parser.add_argument_group(title="output data")
    group.add_argument(
        "--output-prefix",
        type=str,
        required=True,
        help="Path to binary output file without suffix",
    )

    group = parser.add_argument_group(title="miscellaneous")
    group.add_argument(
        "--multimodal",
        action="store_true",
        help="Whether the datasets are assumed to be multimodal"
    )

    args = parser.parse_args()

    assert os.path.isdir(
        args.input
    ), f"ERROR: {args.input} is not a directory or does not exist"

    assert os.path.isdir(
        os.path.dirname(args.output_prefix)
    ), f"ERROR: {os.path.dirname(args.output_prefix)} is not a directory or does not exist"

    return args


def main():
    args = get_args()

    prefixes = set()
    for basename in os.listdir(args.input):
        prefix, ext = os.path.splitext(basename)

        if prefix in prefixes:
            continue

        if not os.path.isfile(os.path.join(args.input, basename)):
            continue

        ext_pair = ".bin" if ext == ".idx" else ".idx"
        assert os.path.isfile(
            os.path.join(args.input, prefix) + ext_pair
        ), f"ERROR: {ext_pair} file not provided for {os.path.join(args.input, prefix)}"

        prefixes.add(prefix)

    builder = None
    for prefix in sorted(prefixes):
        if builder is None:
            dataset = MMapIndexedDataset(os.path.join(args.input, prefix))  # , multimodal=args.multimodal)
            builder = MMapIndexedDatasetBuilder(
                get_bin_path(args.output_prefix), dtype=dataset._index.dtype,  # multimodal=args.multimodal
            )
            del dataset

        builder.merge_file_(os.path.join(args.input, prefix))

    builder.finalize(get_idx_path(args.output_prefix))


if __name__ == '__main__':

    main()
