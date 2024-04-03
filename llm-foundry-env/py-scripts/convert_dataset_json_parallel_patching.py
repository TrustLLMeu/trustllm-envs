# This patching version of parallel data processing was implemented on
# top of `scripts/convert_dataset_json.py` at revision
# 1ef7409c8fa8f8a4ece7dd5935ecb02a09f6044a.

"""
Parallel streaming dataset conversion scripts for JSON files.
"""

import functools
import itertools
import os

import convert_dataset_json


def patch_build_hf_dataset(world_size: int, rank: int) -> None:
    old_build_hf_dataset = convert_dataset_json.build_hf_dataset

    @functools.wraps(old_build_hf_dataset)
    def new_build_hf_dataset(*args, **kwargs):
        dataset = old_build_hf_dataset(*args, **kwargs)
        dataset = itertools.islice(dataset, rank, None, world_size)
        return dataset

    convert_dataset_json.build_hf_dataset = new_build_hf_dataset


if __name__ == '__main__':
    if 'WORLD_SIZE' not in os.getenv or 'RANK' not in os.getenv:
        print(
            'The `WORLD_SIZE` and `RANK` environment variables need to be '
            'defined for parallel data processing, where `WORLD_SIZE` is the '
            'number of processes, and `RANK` is the index of this process.'
        )
        exit(1)

    world_size = int(os.environ['WORLD_SIZE'])
    rank = int(os.environ['RANK'])
    patch_build_hf_dataset(world_size=world_size, rank=rank)

    args = convert_dataset_json.parse_args()
    # Give each process its own output directory
    args.out_root = os.path.join(args.out_root, str(rank))

    convert_dataset_json.main(args)
