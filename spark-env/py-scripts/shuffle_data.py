from argparse import ArgumentParser
import atexit
import glob
import math
import os
import tempfile

from pyspark.sql import SparkSession
from pyspark.sql import functions as sf


def parse_args():
    parser = ArgumentParser()
    parser.add_argument(
        '--dist-input-files',
        help='Colon-separated list of input files to process',
    )
    parser.add_argument(
        '--dist-input-files-glob',
        help='Glob of input files to process',
    )
    parser.add_argument(
        '--seed',
        default=0,
        help='Value to initialize the random number generator with.',
    )
    parser.add_argument(
        '--local-dir',
        default=os.getenv('SPARK_LOCAL_DIRS', tempfile.gettempdir()),
    )
    parser.add_argument(
        '--event-dir',
        default=os.path.join(tempfile.gettempdir(), 'spark-events'),
    )
    parser.add_argument('--available-mem-gb', type=float)
    parser.add_argument('--output-dir', required=True)
    parser.add_argument(
        '--num-shards',
        type=int,
        help='Uniformly shard across all input files into this many shards',
    )
    parser.add_argument('--rank', type=int)
    parser.add_argument(
        '--input-format',
        choices=['parquet', 'json'],
        default='parquet',
        help='Format of the input data, i.e., when reading.',
    )
    parser.add_argument(
        '--output-format',
        choices=['parquet', 'json'],
        default='parquet',
        help='Format of the output data, i.e., when writing.',
    )
    return parser.parse_args()


def main():
    args = parse_args()
    assert args.dist_input_files or args.dist_input_files_glob, (
        'need either `--dist-input-files` or `--dist-input-files-glob` '
        'to be specified'
    )
    assert (
        args.num_shards is None and args.rank is None
        or args.num_shards is not None and args.rank is not None
    ), 'cannot give only one of `--num-shards` and `--rank`; please set both'

    world_size = int(os.environ['WORLD_SIZE'])

    spark = SparkSession.builder.master(
        f'spark://{os.environ["MASTER_ADDR"]}:{os.environ["MASTER_PORT"]}',
    ).config(
        'spark.local.dir',
        args.local_dir,
    ).config(
        'spark.eventLog.dir',
        args.event_dir,
    ).config(
        'spark.serializer',
        'org.apache.spark.serializer.KryoSerializer',
    )
    if args.available_mem_gb:
        memory_gb = args.available_mem_gb
        spark = spark.config(
            'spark.executor.memory',
            f'{math.floor(memory_gb * 0.48)}g',
        ).config(
            'spark.driver.memory',
            f'{round(memory_gb * 0.25)}g',
        ).config(
            'spark.driver.maxResultSize',
            f'{round(memory_gb * 0.25)}g',
        )

    spark = spark.getOrCreate()

    def close_client():
        spark.sparkContext.stop()
        spark.stop()

    atexit.register(close_client)

    os.makedirs(os.path.dirname(args.output_dir), exist_ok=True)

    input_files = []
    if args.dist_input_files:
        input_files.extend(args.dist_input_files.split(':'))
    if args.dist_input_files_glob:
        input_files.extend(sorted(glob.glob(args.dist_input_files_glob)))

    if args.num_shards is not None:
        input_files = input_files[args.rank::args.num_shards]

    print(f'now reading {args.input_format}')
    if args.input_format == 'parquet':
        df = spark.read.parquet(*input_files)
    elif args.input_format == 'json':
        df = spark.read.json(input_files)
    else:
        print(f'unhandled data input format {args.input_format}...')
    print('read parquet, now adding random column')
    df = df.withColumn('randf', sf.rand(seed=args.seed))
    print('added random column, now sorting')
    df = df.sort('randf')
    print('sorted, now coalescing')
    df = df.drop('randf')
    df = df.coalesce(world_size)
    print(f'coalesced, now writing {args.output_format}')
    if args.output_format == 'parquet':
        df.write.parquet(
            args.output_dir,
            mode='overwrite',
            compression='zstd',
        )
    elif args.output_format == 'json':
        df.write.json(
            args.output_dir,
            mode='overwrite',
            compression='zstd',
        )
    else:
        print(f'unhandled data output format {args.output_format}...')
    print('done')

    close_client()
    atexit.unregister(close_client)


if __name__ == '__main__':
    main()
