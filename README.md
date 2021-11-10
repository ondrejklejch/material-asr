# ASR and KWS Docker components
This repository contains Docker components for ASR and KWS for MATERIAL-SCRIPTS project.

## Building Docker images
All Docker images can be build with ```bash build.sh```. Note that ~20GB will be downloaded during build.

## Data preparation
Create ```input``` and ```output``` directories. ```input``` should contain:
  * all wav files,
  * metadata.tsv file,
  * a plain-text file with keywords called keywords.txt.

## Running whole ASR & KWS & Language Verification pipeline
1. See ```run_asr.sh```, ```run_kws.sh``` and ```run_language_verification.sh```.

## ASR model directory
```
cmvn_opts
feats_nb
feats_wb
final_nb.mdl
final_wb.mdl
frame_subsampling_factor
phones.txt
extractor-nb
├── final.dubm
├── final.ie
├── final.ie.id
├── final.mat
├── global_cmvn.stats
├── num_jobs
├── online_cmvn.conf
└── splice_opts
extractor-wb
├── final.dubm
├── final.ie
├── final.ie.id
├── final.mat
├── global_cmvn.stats
├── num_jobs
├── online_cmvn.conf
└── splice_opts
graph-nb
├── LMWT
├── WIP
├── disambig_tid.int
├── G.fst
├── HCLG.fst
├── num_pdfs
├── phones
│   ├── align_lexicon.int
│   ├── align_lexicon.txt
│   ├── disambig.int
│   ├── disambig.txt
│   ├── optional_silence.csl
│   ├── optional_silence.int
│   ├── optional_silence.txt
│   ├── silence.csl
│   ├── word_boundary.int
│   └── word_boundary.txt
├── phones.txt
└── words.txt
graph-wb
├── LMWT
├── WIP
├── disambig_tid.int
├── G.fst
├── HCLG.fst
├── num_pdfs
├── phones
│   ├── align_lexicon.int
│   ├── align_lexicon.txt
│   ├── disambig.int
│   ├── disambig.txt
│   ├── optional_silence.csl
│   ├── optional_silence.int
│   ├── optional_silence.txt
│   ├── silence.csl
│   ├── word_boundary.int
│   └── word_boundary.txt
├── phones.txt
└── words.txt
rnnlm-nb
├── WEIGHT
├── feat_embedding.final.mat
├── final.raw
├── info.txt
├── report.txt
├── special_symbol_opts.txt
├── unigram_probs.txt
└── word_feats.txt
rnnlm-wb
├── WEIGHT
├── feat_embedding.final.mat
├── final.raw
├── info.txt
├── report.txt
├── special_symbol_opts.txt
├── unigram_probs.txt
└── word_feats.txt
```

## Running the pipeline without Docker
  * install Kaldi and HTK and setup Kaldi project structure. See ```base/prepare_env.sh``` and ```asr/Dockerfile``` for details.
  * in ```asr``` folder run ASR with:
```
#!/bin/bash

set -e

export OMP_NUM_THREADS=1
export NUMBER_OF_JOBS=20
export NUMBER_OF_THREADS=4
export RESCORE_RNNLM=true


for version in v1.0; do
    for dset in DEV ANALYSIS; do
        in="/group/project/material-scripts/data2/rawdata/NIST-data/3C/IARPA_MATERIAL_OP2-3C/${dset}/audio/src/"
        metadata="/group/project/material-scripts/data2/rawdata/NIST-data/3C/IARPA_MATERIAL_OP2-3C/${dset}/audio/metadata/metadata.tsv"
        out="/disk/data2/s1569734/material/docker/asr/exp/nnet_kazakh_${version}/${dset}"
        tmp="/disk/data2/s1569734/material/docker/asr/tmp_kazakh_${dset}"
        nnet="/disk/data2/s1569734/material/docker/asr/exp/nnet_kazakh_${version}/"
        bn="/disk/data2/s1569734/material/docker/asr/exp/bn/"

        time bash process.sh $in $metadata $out $tmp $nnet $bn || exit 1;
        rm -rf $tmp
    done
done
```
  * in ```nbest``` folder run n-best generation with:
```
#!/bin/bash

for version in v1.0; do
    for dset in DEV ANALYSIS; do
        ASR_OUTPUT_DIR="/disk/data2/s1569734/material/docker/asr/exp/nnet_kazakh_${version}/${dset}"
        NBEST_OUTPUT_DIR="/disk/data2/s1569734/material/docker/asr/exp/nnet_kazakh_${version}/${dset}"
        TMP_DIR="tmp/kazakh_${dset}"

        echo "Processing $dset"
        bash process.sh $ASR_OUTPUT_DIR $NBEST_OUTPUT_DIR $TMP_DIR || exit 1;
    done
done
```

## Acknowledgements
This work was funded by the IARPA MATERIAL program.
