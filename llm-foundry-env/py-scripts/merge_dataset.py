"""
Merge a directory of sub-datasets into one file.
"""

from argparse import ArgumentParser, Namespace

from llmfoundry.utils.data_prep_utils import merge_shard_groups


def parse_args() -> Namespace:
    """Parse commandline arguments."""
    parser = ArgumentParser(
        description=(
            'Merge different sub-dataset in MDS format into an overarching one'
        ),
    )
    parser.add_argument('--out_root', type=str, required=True)
    parsed = parser.parse_args()
    return parsed


def main(args: Namespace) -> None:
    """Main: merge MDS sub-datasets into one.

    Args:
        args (Namespace): Commandline arguments.
    """
    # Write samples
    print('Merging MDS sub-datasets...')
    merge_shard_groups(args.out_root)


if __name__ == '__main__':
    main(parse_args())
