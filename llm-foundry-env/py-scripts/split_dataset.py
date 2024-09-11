# Based on the NeMo implementation by @Apsod
# (https://github.com/TrustLLMeu/trustllm-envs/pull/2).

from argparse import ArgumentParser

import numpy as np
from streaming import MDSWriter, StreamingDataset
import os
import tqdm
import multiprocessing as mp
from functools import partial

# Define worker function to handle writing data
def write_data(writer_kwargs, ds, idx_chunk, worker_id):
    assert 'out' in writer_kwargs
    writer_kwargs['out'] = os.path.join(writer_kwargs['out'], str(worker_id))
    with MDSWriter(**writer_kwargs) as writer:
        for idx in tqdm.tqdm(idx_chunk):
            writer.write(ds.get_item(idx))

def parallelize_writing(writer_kwargs, ds, indices, num_workers):
    # Split indices into chunks, excluding remainder
    idx_chunks = np.array_split(indices, num_workers)

    # Use multiprocessing to parallelize writing
    with mp.Pool(processes=num_workers) as pool:
        # Create a list of (chunk, worker_id) pairs to pass to the workers
        worker_args = [(idx_chunks[i], i) for i in range(len(idx_chunks))]
        # Pass worker_id and chunk to each worker using starmap
        pool.starmap(partial(write_data, writer_kwargs, ds), worker_args)

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
    right_idx = []
    while True:
        next_id = rng.geometric(threshold)
        if len(right_idx) > 0:
            next_id += right_idx[-1]
        else:
            next_id -= 1
        right_idx.append(next_id)

        if right_idx[-1] >= len(ds):
            right_idx.pop()
            break
    left_idx = np.setdiff1d(np.arange(len(ds)), right_idx, assume_unique=True)
    
    print('total samples:', len(ds))
    print('train samples:', len(left_idx))
    print('val samples:', len(right_idx))
    assert all(np.sort(np.append(left_idx, right_idx)) == range(len(ds)))
    assert len(np.unique(left_idx)) == len(left_idx)
    assert len(np.unique(right_idx)) == len(right_idx)

    # Parallelize writing for left and right indices
    left_writer_kwargs = {
        'columns': columns,
        'out': left_path,
        'compression': compression,
    }
    right_writer_kwargs = {
        'columns': columns,
        'out': right_path,
        'compression': compression,
    }

    # Parallelize writing left_idx
    print('Writing left_idx...')
    parallelize_writing(left_writer_kwargs, ds, left_idx, num_workers=num_workers)

    # Parallelize writing right_idx
    print('Writing right_idx...')
    parallelize_writing(right_writer_kwargs, ds, right_idx, num_workers=num_workers)

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
