# Based on the NeMo implementation by @Apsod
# (https://github.com/TrustLLMeu/trustllm-envs/pull/2).

from argparse import ArgumentParser
import functools
import multiprocessing as mp
import os

import numpy as np
from streaming import MDSWriter, StreamingDataset
import tqdm


def write_data(writer_kwargs, ds, indices_shard, rank):
    assert 'out' in writer_kwargs
    writer_kwargs['out'] = os.path.join(writer_kwargs['out'], str(rank))
    with MDSWriter(**writer_kwargs) as writer:
        for index in tqdm.tqdm(indices_shard):
            writer.write(ds.get_item(index))


def parallelize_writing(writer_kwargs, ds, indices, num_workers):
    # Create indices shards.
    indices_shards = np.array_split(indices, num_workers)
    # Create a list of (shard, rank) pairs to pass to the workers.
    worker_args = [
        (indices_shard, rank)
        for (rank, indices_shard) in enumerate(indices_shards)
    ]

    # Write in parallel.
    with mp.Pool(processes=num_workers) as pool:
        # TODO get number of tokens and reduce afterwards
        pool.starmap(
            functools.partial(write_data, writer_kwargs, ds),
            worker_args,
        )


def parse_args():
    parser = ArgumentParser()
    parser.add_argument(
        '--in_path',
        required=True,
        help='Input path for `StreamingDataset`.',
    )
    parser.add_argument(
        '--left_path',
        default='train',
        help='Output path for the left (default: "train") split.',
    )
    parser.add_argument(
        '--right_path',
        default='valid',
        help='Output path for the right (default: "valid") split.',
    )
    parser.add_argument(
        '--right_prob',
        default=1e-3,
        type=float,
        help=(
            'Probability of a sample ending up in the right (valid) split. '
            'NOTE: The minimum (in expected number of samples) of '
            '`--right_prob` and `--right_max` is chosen during splitting.'
        ),
    )
    parser.add_argument(
        '--right_max',
        default=1000,
        type=int,
        help=(
            'Approximate number of samples that should end up in the right '
            '(valid) split. NOTE: The minimum (in expected number of samples) '
            'of right_prob and right_max is chosen during splitting.'
        ),
    )
    parser.add_argument(
        '--seed',
        default=0x5eed,
        type=int,
        help='Seed for the RNG',
    )
    parser.add_argument(
        '--compression',
        help='Compression algorithm to use.'
    )
    parser.add_argument(
        '--num_workers',
        default=4,
        type=int,
        help='Number of workers to use for parallel writing.',
    )
    return parser.parse_args()


def run_split(
        in_path,
        left_path,
        right_path,
        right_prob,
        right_max,
        seed,
        compression,
        num_workers,
):
    ds = StreamingDataset(
        local=in_path,
        batch_size=1,

        # Below can be set to default values to avoid warnings as they
        # appear.
        # split='all',
        # download_retry=download_retry,
        # download_timeout=download_timeout,
        # validate_hash=validate_hash,
        # keep_zip=keep_zip,
        # epoch_size=epoch_size,
        predownload=8,
        # cache_limit=cache_limit,
        # partition_algo=partition_algo,
        num_canonical_nodes=1,
        # batch_size=batch_size,
        # shuffle=shuffle,
        # shuffle_algo=shuffle_algo,
        # shuffle_seed=shuffle_seed,
        shuffle_block_size=1 << 18,
        # sampling_method=sampling_method,
        # sampling_granularity=sampling_granularity,
        # batching_method=batching_method,
        # allow_unsafe_types=allow_unsafe_types,
        # replication=replication,
    )

    has_tokens = 'tokens' in ds.get_item(0)
    if has_tokens:
        key = 'tokens'
        columns = {key: 'ndarray:int32'}
    else:
        key = 'text'
        columns = {key: 'str'}

    print(f'{in_path = }')
    print(f'{left_path = }')
    print(f'{right_path = }')
    print(f'{compression = }')
    print(f'{columns = }')

    rng = np.random.default_rng(seed)
    threshold = min(right_max / len(ds), right_prob)

    # This is the number of samples until the next index in the "right"
    # set. Always >= 1.
    num_samples_until_right = rng.geometric(threshold)
    # Convert number of samples to index.
    right_index = num_samples_until_right - 1
    right_indices = [right_index]
    while right_indices[-1] < len(ds):
        # This is the number of samples until the next index in the
        # "right" set. Always >= 1.
        num_samples_until_right = rng.geometric(threshold)
        # Use number of samples as "distance" to compute next index.
        right_index = right_indices[-1] + num_samples_until_right
        right_indices.append(right_index)

    # Remove last index that was too large and caused us to exit the
    # while-loop.
    right_indices.pop()

    all_indices = np.arange(len(ds))
    left_indices = np.setdiff1d(
        all_indices,
        right_indices,
        assume_unique=True,
    )

    print('number of total samples:', len(ds))
    print('number of left samples:', len(left_indices))
    print('number of right samples:', len(right_indices))
    assert np.all(
        np.sort(np.append(left_indices, right_indices)) == all_indices,
    )
    del all_indices
    assert len(np.unique(left_indices)) == len(left_indices)
    assert len(np.unique(right_indices)) == len(right_indices)

    common_kwargs = {
        'columns': columns,
        'compression': compression,
    }
    left_writer_kwargs = common_kwargs.copy()
    left_writer_kwargs['out'] = left_path
    right_writer_kwargs = common_kwargs.copy()
    right_writer_kwargs['out'] = right_path

    print('Writing left split...')
    parallelize_writing(
        left_writer_kwargs,
        ds,
        left_indices,
        num_workers=num_workers,
    )

    print('Writing right split...')
    parallelize_writing(
        right_writer_kwargs,
        ds,
        right_indices,
        num_workers=num_workers,
    )


if __name__ == '__main__':
    args = parse_args()
    run_split(
        in_path=args.in_path,
        left_path=args.left_path,
        right_path=args.right_path,
        right_prob=args.right_prob,
        right_max=args.right_max,
        seed=args.seed,
        compression=args.compression,
        num_workers=args.num_workers,
    )
