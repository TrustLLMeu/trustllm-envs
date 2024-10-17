from argparse import ArgumentParser
from collections import OrderedDict
import re

from transformers import (
    AutoConfig,
    AutoModelForCausalLM,
    AutoTokenizer,
    LlamaConfig,
    LlamaForCausalLM,
)

EPS = 1e-8


def get_kv_n_heads(mpt_config):
    attn_config = mpt_config.attn_config
    assert attn_config is not None, 'currently need an attention configuration'

    if (
            attn_config.get('attn_type', 'multihead_attention')
            == 'multihead_attention'
    ):
        kv_n_heads = mpt_config.n_heads
    elif attn_config['attn_type'] == 'multiquery_attention':
        kv_n_heads = 1
    elif attn_config['attn_type'] == 'grouped_query_attention':
        kv_n_heads = attn_config['kv_n_heads']
    else:
        raise ValueError('unknown attention type')

    return kv_n_heads


# Config conversion
# =================

def expansion_ratio_to_intermediate_size(mpt_config):
    ffn_hidden_size = mpt_config.ffn_config.get('ffn_hidden_size', None)
    if ffn_hidden_size is None:
        ffn_hidden_size = int(
            mpt_config.d_model
            * mpt_config.expansion_ratio
        )
    return dict(intermediate_size=ffn_hidden_size)


def assert_no_resid_pdrop(mpt_config):
    assert (
        abs(mpt_config.resid_pdrop) < EPS
    ), 'post-attention residual dropout not supported'


def assert_no_emb_pdrop(mpt_config):
    assert abs(mpt_config.emb_pdrop) < EPS, 'embedding dropout not supported'


def assert_no_learned_pos_emb(mpt_config):
    assert not mpt_config.learned_pos_emb, \
        'learned position embeddings not supported'


def attn_config_to_various(mpt_config):
    attn_config = mpt_config.attn_config
    assert attn_config is not None, 'currently need an attention configuration'
    assert attn_config.get('attn_impl', 'flash') in ['flash', 'torch'], \
        'unknown attention implementation'
    assert not attn_config.get('qk_ln', False), \
        'Q/K layer normalization not supported'
    assert not attn_config.get('qk_gn', False), \
        'Q/K group normalization not supported'
    # don't care about `fused_qkv`
    assert attn_config.get('clip_qkv', None) is None, \
        'Q/K/V clipping not supported'
    assert (
        attn_config.get('softmax_scale', None) is None
        or abs(
            attn_config['softmax_scale']
            - (mpt_config.d_model / mpt_config.n_heads)**-0.5
        ) < EPS
    ), 'attention softmax scaling not supported'
    assert not attn_config.get('attn_uses_sequence_id', False), 'not supported'
    assert attn_config.get('sliding_window_size', -1) == -1, \
        'SWA not supported'
    assert attn_config.get('attn_logit_softcapping', None) is None, \
        'attention logit softcapping not supported'
    assert not attn_config.get('alibi', False), 'ALiBi not supported'
    # don't care about `alibi_bias_max`
    assert attn_config.get('rope', False), 'only models using RoPE supported'
    assert (
        attn_config.get('kv_dim', None) is None
        or attn_config['kv_dim'] == mpt_config.d_model
    ), 'attention logit softcapping not supported'

    num_key_value_heads = get_kv_n_heads(mpt_config)

    rope_scaling = None
    if attn_config.get('rope_impl', 'dail') == 'dail':
        rope_config = attn_config['rope_dail_config']
        assert rope_config['type'] == 'original', \
            'only models using RoPE supported'
        # don't care about `pos_idx_in_fp32`
        # don't care about `xpos_scale_base`
    elif attn_config['rope_impl'] == 'hf':
        rope_config = attn_config['rope_hf_config']

        # We can forego supplying a RoPE scaling config if scaling is
        # disabled.
        if rope_config['type'] != 'no_scaling':
            rope_scaling = rope_config.copy()
            del rope_scaling['type']

            rope_scaling['rope_type'] = (
                'default'
                if rope_config['type'] == 'no_scaling'
                else rope_config['type']
            )
            rope_scaling['factor'] = (
                1.0
                if rope_config['type'] == 'no_scaling'
                else rope_config['factor']
            )
    else:
        raise ValueError('unknown RoPE implementation')

    return dict(
        attention_dropout=attn_config.get('attn_pdrop', 0.0),
        num_key_value_heads=num_key_value_heads,
        rope_theta=attn_config.get('rope_theta', 10000),
        rope_scaling=rope_scaling,
    )


def ffn_config_to_various(mpt_config):
    ffn_config = mpt_config.ffn_config
    assert ffn_config is not None, \
        'currently need an feedforward network configuration'
    assert ffn_config.get('ffn_type', 'mptmlp') in ['mptglu', 'te_ln_mlp'], \
        'unsupported feedforward network type'
    # don't care about `fc_type`

    if ffn_config.get('ffn_type', 'mptmlp') == 'te_ln_mlp':
        hidden_act = 'gelu'
    else:
        # 'gelu' and 'quick_gelu' map correctly; for rest, we depend on
        # HuggingFace using the PyTorch-native implementation by default
        hidden_act = ffn_config.get('ffn_act_fn', dict(name='gelu'))
        assert (
            len(hidden_act) == 1 and 'name' in hidden_act
            or (
                len(hidden_act) == 2
                and 'name' in hidden_act
                and 'approximate' in hidden_act
                and hidden_act['name'] == 'gelu'
                and hidden_act['approximate'] == 'none'
            )
        ), 'arbitrary activation function arguments unsupported'
        hidden_act = hidden_act['name']
    return dict(
        hidden_act=hidden_act,
    )


def assert_no_logit_scale(mpt_config):
    assert (
        mpt_config.logit_scale is None
        or abs(mpt_config.logit_scale - 1.0) < EPS
    ), 'logit scaling not supported'


def no_bias_to_various(mpt_config):
    return dict(
        attention_bias=not mpt_config.no_bias,
        mlp_bias=not mpt_config.no_bias,
    )


def assert_full_embedding(mpt_config):
    assert abs(mpt_config.embedding_fraction - 1.0) < EPS, \
        'partial embeddings not supported'


def assert_rmsnorm(mpt_config):
    assert mpt_config.norm_type in ['rmsnorm', 'triton_rmsnorm'], \
        'only models using RMSNorm supported'


def assert_use_pad_tok_in_ffn(mpt_config):
    assert mpt_config.use_pad_tok_in_ffn, \
        'only models using pad tokens in feedforward network supported'


def assert_no_block_overrides(mpt_config):
    assert mpt_config.block_overrides is None, \
        'block overrides not supported'


def assert_no_final_logit_softcapping(mpt_config):
    assert getattr(mpt_config, 'final_logit_softcapping', None) is None, \
        'final logit softcapping not supported'


MPT_CONFIG_TO_LLAMA_DICT = dict(
    d_model='hidden_size',
    n_heads='num_attention_heads',
    n_layers='num_hidden_layers',
    expansion_ratio=expansion_ratio_to_intermediate_size,
    max_seq_len='max_position_embeddings',
    vocab_size='vocab_size',
    resid_pdrop=assert_no_resid_pdrop,
    emb_pdrop=assert_no_emb_pdrop,
    learned_pos_emb=assert_no_learned_pos_emb,
    attn_config=attn_config_to_various,
    ffn_config=ffn_config_to_various,
    # don't care about `init_device`
    logit_scale=assert_no_logit_scale,
    no_bias=no_bias_to_various,
    embedding_fraction=assert_full_embedding,
    norm_type=assert_rmsnorm,
    norm_eps='rms_norm_eps',
    use_cache='use_cache',
    # don't care about `init_config`
    # don't care about `fc_type`
    tie_word_embeddings='tie_word_embeddings',
    use_pad_tok_in_ffn=assert_use_pad_tok_in_ffn,
    block_overrides=assert_no_block_overrides,
    final_logit_softcapping=assert_no_final_logit_softcapping,

    torch_dtype='torch_dtype',
    transformers_version='transformers_version',
)


def convert_mpt_config_to_llama(mpt_config):
    llama_config_kwargs = {}

    for (mpt_key, llama_conversion) in MPT_CONFIG_TO_LLAMA_DICT.items():
        if (
                llama_conversion is not None
                and not isinstance(llama_conversion, (dict, str))
        ):
            assert callable(llama_conversion)
            llama_conversion = llama_conversion(mpt_config)

        if isinstance(llama_conversion, dict):
            llama_config_kwargs.update(llama_conversion)
        elif isinstance(llama_conversion, str):
            llama_key = llama_conversion
            llama_config_kwargs[llama_key] = getattr(mpt_config, mpt_key)
        elif llama_conversion is None:
            # Nothing to convert; don't do anything.
            pass
        else:
            raise TypeError(f'unknown conversion handler for {mpt_key = }')

    return LlamaConfig(**llama_config_kwargs)


def add_args_config(parser, require_mpt_config=False):
    parser.add_argument(
        '--mpt_config_path',
        '--mpt_config_dir',
        required=require_mpt_config,
    )
    parser.add_argument('--llama_config_dir')
    return parser


def parse_args_config():
    parser = ArgumentParser()
    add_args_config(parser, require_mpt_config=True)
    return parser.parse_args()


def main_config():
    args = parse_args_config()
    mpt_config = AutoConfig.from_pretrained(args.mpt_config_path)
    llama_config = convert_mpt_config_to_llama(mpt_config)
    if args.llama_config_dir is not None:
        llama_config.save_pretrained(args.llama_config_dir)
        print(
            f'Saved {type(llama_config).__name__} to {args.llama_config_dir}',
        )
    else:
        print(llama_config)


# Model conversion
# =================

def split_fused_qkv_weight(mpt_config, mpt_state_dict, mpt_key, match_result):
    assert mpt_key.endswith('.Wqkv.weight')
    fused_qkv_weights = mpt_state_dict[mpt_key]

    head_dim = mpt_config.d_model // mpt_config.n_heads
    kv_n_heads = get_kv_n_heads(mpt_config)
    query_weight, key_weight, value_weight = fused_qkv_weights.split(
        [
            mpt_config.d_model,
            kv_n_heads * head_dim,
            kv_n_heads * head_dim,
        ],
        dim=0,
    )

    layer_number = match_result.group(1)
    return {
        f'model.layers.{layer_number}.self_attn.q_proj.weight': query_weight,
        f'model.layers.{layer_number}.self_attn.k_proj.weight': key_weight,
        f'model.layers.{layer_number}.self_attn.v_proj.weight': value_weight,
    }


def split_fused_qkv_bias(mpt_config, mpt_state_dict, mpt_key, match_result):
    assert mpt_key.endswith('.Wqkv.bias')
    fused_qkv_biases = mpt_state_dict[mpt_key]

    head_dim = mpt_config.d_model // mpt_config.n_heads
    kv_n_heads = get_kv_n_heads(mpt_config)
    query_bias, key_bias, value_bias = fused_qkv_biases.split(
        [
            mpt_config.d_model,
            kv_n_heads * head_dim,
            kv_n_heads * head_dim,
        ],
        dim=0,
    )

    layer_number = match_result.group(1)
    return {
        f'model.layers.{layer_number}.self_attn.q_proj.bias': query_bias,
        f'model.layers.{layer_number}.self_attn.k_proj.bias': key_bias,
        f'model.layers.{layer_number}.self_attn.v_proj.bias': value_bias,
    }


MPT_STATE_DICT_TO_LLAMA_DICT = {
    r'^transformer\.wte\.(weight|bias)$': r'model.embed_tokens.\1',
    r'^transformer\.blocks\.([0-9]+)\.norm_1\.(weight|bias)$': (
        r'model.layers.\1.input_layernorm.\2'
    ),
    # TODO handle other Wqkv combinations
    r'^transformer\.blocks\.([0-9]+)\.attn\.Wqkv\.weight$': (
        split_fused_qkv_weight
    ),
    r'^transformer\.blocks\.([0-9]+)\.attn\.Wqkv\.bias$': split_fused_qkv_bias,
    r'^transformer\.blocks\.([0-9]+)\.attn\.out_proj\.(weight|bias)$': (
        r'model.layers.\1.self_attn.o_proj.\2'
    ),
    r'^transformer\.blocks\.([0-9]+)\.norm_2\.(weight|bias)$': (
        r'model.layers.\1.post_attention_layernorm.\2'
    ),
    r'^transformer\.blocks\.([0-9]+)\.ffn\.up_proj\.(weight|bias)$': (
        r'model.layers.\1.mlp.up_proj.\2'
    ),
    r'^transformer\.blocks\.([0-9]+)\.ffn\.down_proj\.(weight|bias)$': (
        r'model.layers.\1.mlp.down_proj.\2'
    ),
    r'^transformer\.blocks\.([0-9]+)\.ffn\.gate_proj\.(weight|bias)$': (
        r'model.layers.\1.mlp.gate_proj.\2'
    ),
    r'^transformer\.norm_f\.(weight|bias)$': r'model.norm.\1',
    r'^lm_head\.(weight|bias)$': r'lm_head.\1',
}


def convert_mpt_state_dict_to_llama(mpt_config, mpt_state_dict):
    llama_state_dict = OrderedDict()

    mpt_state_dict_to_llama_dict_regexes = {
        re.compile(pattern): replacement
        for (pattern, replacement) in MPT_STATE_DICT_TO_LLAMA_DICT.items()
    }
    for (mpt_key, mpt_value) in mpt_state_dict.items():
        match_result = None
        for (
                pattern,
                replacement,
        ) in mpt_state_dict_to_llama_dict_regexes.items():
            match_result = pattern.search(mpt_key)
            if match_result is not None:
                break

        if not isinstance(replacement, str):
            llama_replacements = replacement(
                mpt_config,
                mpt_state_dict,
                mpt_key,
                match_result,
            )
        else:
            llama_key = pattern.sub(replacement, mpt_key)
            llama_value = mpt_value
            llama_replacements = {llama_key: llama_value}

        for (llama_key, llama_value) in llama_replacements.items():
            llama_state_dict[llama_key] = llama_value

    return llama_state_dict


def add_args_model(parser):
    parser.add_argument('--mpt_model_dir', required=True)
    parser.add_argument('--llama_model_dir', required=True)
    return parser


def parse_args_model():
    parser = ArgumentParser()
    add_args_config(parser, require_mpt_config=False)
    add_args_model(parser)
    return parser.parse_args()


def main_model():
    args = parse_args_model()
    mpt_config = AutoConfig.from_pretrained(
        args.mpt_model_dir,
        trust_remote_code=True,
    )
    mpt_model = AutoModelForCausalLM.from_pretrained(
        args.mpt_model_dir,
        trust_remote_code=True,
        torch_dtype='bfloat16',
        device_map='auto',
    )
    mpt_state_dict = mpt_model.state_dict()
    del mpt_model

    llama_state_dict = convert_mpt_state_dict_to_llama(
        mpt_config,
        mpt_state_dict,
    )
    del mpt_state_dict

    llama_config = convert_mpt_config_to_llama(mpt_config)
    llama_model = LlamaForCausalLM(llama_config)
    llama_model.load_state_dict(llama_state_dict)
    llama_model.save_pretrained(args.llama_model_dir)

    tok = AutoTokenizer.from_pretrained(args.mpt_model_dir, use_fast=False)
    tok.save_pretrained(args.llama_model_dir)


if __name__ == '__main__':
    main_model()
