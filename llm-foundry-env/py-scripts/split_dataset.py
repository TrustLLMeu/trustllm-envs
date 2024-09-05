# Based on the NeMo implementation by @Apsod
# (https://github.com/TrustLLMeu/trustllm-envs/pull/2).

from argparse import ArgumentParser

import numpy as np
from streaming import MDSWriter, StreamingDataset
import tqdm


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
    return parser.parse_args()


def run_split(
        in_path,
        left_path,
        right_path,
        right_prob,
        right_max,
        seed,
        compression,
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

    num_elems_left = 0
    num_samples_left = 0
    num_elems_right = 0
    num_samples_right = 0
    with (
            MDSWriter(
                columns=columns,
                out=left_path,
                compression=compression,
            ) as left_out,
            MDSWriter(
                columns=columns,
                out=right_path,
                compression=compression,
            ) as right_out,
    ):
        rng = np.random.default_rng(seed)

        threshold = min(right_max / len(ds), right_prob)
        for sample in tqdm.tqdm(ds):
            num_elems = len(sample[key])
            if rng.random() > threshold:
                out = left_out
                num_elems_left += num_elems
                num_samples_left += 1
            else:
                out = right_out
                num_elems_right += num_elems
                num_samples_right += 1
            out.write(sample)

    print(f'{num_elems_left = }')
    print(f'{num_samples_left = }')
    print(f'{num_elems_right = }')
    print(f'{num_samples_right = }')


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
    )
