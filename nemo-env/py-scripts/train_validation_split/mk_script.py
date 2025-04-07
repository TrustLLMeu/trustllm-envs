import os
import json
import string

from dataclasses import dataclass

CFG_FILE = os.path.abspath('config.txt')
RUN_TEMPLATE = string.Template(open('batch.template').read())
RUN_FILE = 'batch.sh'

IN_ROOT = "/gpfs/scratch/ehpc09/data/baseline-tokenized_equal-sampling/data_tokenized"
OUT_ROOT = "/gpfs/scratch/ehpc09/split"
VALID_PROB = 1e-2
VALID_MAX = 1000

NAMES = (
    'complete_afr_text_document',
    'complete_fao_text_document',
    'complete_fry_text_document',
    'complete_gsw_text_document',
    'complete_lim_text_document',
    'complete_ltz_text_document',
    'complete_nds_text_document',
    'complete_dan_text_document',
    'complete_isl_text_document',
    'complete_nld_text_document',
    'complete_nno_text_document',
    'complete_nob_text_document',
    'complete_nor_text_document',
    'complete_swe_text_document',
    'deu-merged_text_document',
    'eng-merged_text_document',
    'code-merged_text_document',
)


def to_args(**kwargs):
    return ' '.join([f'--{k} {v}' for k, v in kwargs.items()])

with open(CFG_FILE, 'wt') as outfp:
    for NAME in NAMES:
        outfp.write(
                to_args(
                    in_path=f'{IN_ROOT}/{NAME}', 
                    left_path=f'{OUT_ROOT}/train/{NAME}', 
                    right_path=f'{OUT_ROOT}/valid/{NAME}', 
                    right_prob=VALID_PROB,
                    right_max=VALID_MAX,
                    )
                )
        outfp.write('\n')

with open(RUN_FILE, 'wt') as outfp:
    outfp.write(
            RUN_TEMPLATE.substitute(
                num_jobs=len(NAMES),
                config=CFG_FILE,
                )
            )
