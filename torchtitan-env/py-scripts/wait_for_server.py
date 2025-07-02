from argparse import ArgumentParser
import sys
import time
import urllib.request


def parse_args(args_list: list[str] | None = None):
    parser = ArgumentParser()

    parser.add_argument(
        "--server_protocol",
        default="http",
        help="Protocol to query the server with.",
    )
    parser.add_argument(
        "--server_address",
        default="localhost",
        help="Address to query the server from.",
    )
    parser.add_argument(
        "--server_port",
        type=int,
        help="Port to query the server from.",
    )

    if args_list is None:
        args_list = sys.argv[1:]
    args = parser.parse_args(args_list)
    return args


def main(args_list: list[str] | None = None):
    args = parse_args(args_list)

    server_uri = f"{args.server_protocol}://{args.server_address}"
    if args.server_port is not None:
        server_uri = f"{server_uri}:{args.server_port}"
    while True:
        try:
            urllib.request.urlopen(server_uri, timeout=1.0)
            break
        except urllib.request.URLError:
            time.sleep(1.0)


if __name__ == "__main__":
    main()
