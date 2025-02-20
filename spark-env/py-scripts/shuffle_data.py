from argparse import ArgumentParser
import atexit
import glob
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
    parser.add_argument('--output-dir', required=True)
    return parser.parse_args()


def main():
    args = parse_args()
    assert args.dist_input_files or args.dist_input_files_glob, (
        'need either `--dist-input-files` or `--dist-input-files-glob` '
        'to be specified'
    )

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
    ).config(
        'spark.executor.memory',
        '23g',
    ).config(
        'spark.driver.memory',
        '12g',
    ).config(
        'spark.driver.maxResultSize',
        '12g',
    ).getOrCreate()

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

    print('now reading parquet')
    df = spark.read.parquet(*input_files)
    print('read parquet, now adding random column')
    df = df.withColumn('randf', sf.rand(seed=args.seed))
    print('added random column, now sorting')
    df = df.sort('randf')
    print('sorted, now coalescing')
    df = df.drop('randf')
    df = df.coalesce(world_size)
    print('coalesced, now writing')
    df.write.parquet(
        args.output_dir,
        mode='overwrite',
        compression='zstd',
    )
    print('done')

    close_client()
    atexit.unregister(close_client)


if __name__ == '__main__':
    main()
