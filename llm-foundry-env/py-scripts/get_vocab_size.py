from argparse import ArgumentParser

from transformers import AutoTokenizer


def get_vocab_size(tok_dir):
    tok = AutoTokenizer.from_pretrained(tok_dir)
    return tok.vocab_size


def main():
    parser = ArgumentParser()
    parser.add_argument(
        'tok_dir',
        required=True,
        help='Directory to load the HuggingFace tokenizer from.',
    )
    args = parser.parse_args()

    vocab_size = get_vocab_size(args.tok_dir)
    print(vocab_size)
