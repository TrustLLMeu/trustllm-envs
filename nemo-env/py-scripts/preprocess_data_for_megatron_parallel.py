# Builds on top of the same file without `_parallel` at revision
# 8f3855f241099a83b405d2057998d628789ec73b.

from argparse import ArgumentParser
import glob
import math
import os
import runpy
import sys


def parse_args():
    parser = ArgumentParser()
    parser.add_argument('--preprocessing-script', required=True)
    parser.add_argument(
        '--dist-input-files',
        help='Colon-separated list of input files to process',
    )
    parser.add_argument(
        '--dist-input-files-glob', help='Glob of input files to process')
    parser.add_argument('--output-prefix', required=True)
    return parser.parse_known_args()


def main():
    args, passthrough_args = parse_args()
    assert os.path.isfile(args.preprocessing_script)
    assert args.dist_input_files or args.dist_input_files_glob, (
        'need either `--dist-input-files` or `--dist-input-files-glob` '
        'to be specified'
    )

    world_size = int(os.environ['WORLD_SIZE'])
    rank = int(os.environ['RANK'])

    os.makedirs(args.output_prefix, exist_ok=True)

    input_files = []
    if args.dist_input_files:
        input_files.extend(args.dist_input_files.split(':'))
    input_files.extend(sorted(glob.glob(args.dist_input_files_glob)))

    shard_size = math.ceil(len(input_files) / world_size)
    shard_offset = shard_size * rank
    input_files_shard = input_files[shard_offset:shard_offset + shard_size]

    sys.argv = (
        [args.preprocessing_script]
        + passthrough_args
        + ['--input', '--output-prefix']
    )

    for (i, input_file) in enumerate(input_files_shard, shard_offset):
        print('Processing', input_file)
        output_prefix = os.path.join(
            args.output_prefix,
            (
                f'{os.path.basename(args.output_prefix)}'
                f'_{i:0{len(str(len(input_files)))}}'
            ),
        )
        sys.argv = sys.argv[:-2] + [
            f'--input={input_file}',
            f'--output-prefix={output_prefix}',
        ]
        runpy.run_path(args.preprocessing_script, run_name='__main__')


if __name__ == '__main__':
    main()
