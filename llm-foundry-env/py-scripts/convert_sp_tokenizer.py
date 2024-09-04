"""
Convert a SentencePiece tokenizer to HuggingFace.

Note that the "fast" versions are not compatible with the conversion
because their implementation does not match. They will not be able to
match the original SentencePiece tokenizer no matter which configuration
is used. That makes it imperative to pass the `use_fast=False` argument
to `AutoTokenizer.from_pretrained` when creating the tokenizer. If this
is omitted, the tokenizer **will not work as it should**.

Similarly, a `LlamaTokenizerFast` should never be instantiated manually
from a converted tokenizer.
"""

from argparse import ArgumentParser

import sentencepiece as spm
import sentencepiece.sentencepiece_model_pb2 as spm_model
from transformers import LlamaTokenizer


def parse_args():
    parser = ArgumentParser()
    parser.add_argument(
        '--spm_tok_path',
        required=True,
        help='Path to the original SentencePiece model file.',
    )
    parser.add_argument(
        '--out_dir',
        required=True,
        help='Where to save the converted HuggingFace tokenizer.',
    )
    return parser.parse_args()


def create_spm_tok(path):
    tok = spm.SentencePieceProcessor(path)
    return tok


def create_hf_tok(path, spm_tok):
    proto = spm_model.ModelProto()
    proto.ParseFromString(spm_tok.serialized_model_proto())

    assert proto.trainer_spec.byte_fallback, \
        'can only convert tokenizer with byte fallback enabled.'
    add_prefix_space = proto.normalizer_spec.add_dummy_prefix

    tok = LlamaTokenizer(
        path,
        split_special_tokens=True,
        add_bos_token=False,
        add_prefix_space=add_prefix_space,
        from_slow=True,
        legacy=False,
    )
    tok.pad_token_id = spm_tok.pad_id()
    return tok


def main():
    args = parse_args()
    spm_tok = create_spm_tok(args.spm_tok_path)
    hf_tok = create_hf_tok(args.spm_tok_path, spm_tok)

    hf_tok.save_pretrained(args.out_dir)


if __name__ == '__main__':
    main()
