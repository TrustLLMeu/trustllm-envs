from argparse import ArgumentParser
import socket
import sys
import time

from torchtitan.tools.server.serve_model import (
    DEFAULT_PORT,
    receive_data,
    send_data,
    TorchTitanServerRequestHandler,
)


def parse_args(args_list: list[str] | None = None):
    parser = ArgumentParser()

    parser.add_argument(
        "--server_address",
        default="localhost",
        help="Address to query the server from.",
    )
    parser.add_argument(
        "--server_port",
        default=DEFAULT_PORT,
        type=int,
        help="Port to query the server from.",
    )

    if args_list is None:
        args_list = sys.argv[1:]
    args = parser.parse_args(args_list)
    return args


def main(args_list: list[str] | None = None):
    args = parse_args(args_list)

    while True:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
                sock.settimeout(1.0)
                sock.connect((args.server_address, args.server_port))
                send_data(
                    b"server ready?",
                    sock,
                    TorchTitanServerRequestHandler.MAX_SEND_DATA_BYTES,
                    TorchTitanServerRequestHandler.DATA_BYTES_PER_PIECE,
                )
                receive_data(
                    sock,
                    TorchTitanServerRequestHandler.MAX_RECV_DATA_BYTES,
                    TorchTitanServerRequestHandler.DATA_BYTES_PER_PIECE,
                )
            break
        except (ConnectionRefusedError, TimeoutError):
            time.sleep(1.0)


if __name__ == "__main__":
    main()
