#!/bin/bash

if [ $# != 6 ]; then
    echo "USAGE: bash run.sh input_dir metadata.tsv output_dir tmp_dir nnet_dir bn_dir";
    exit 1;
fi

source path.sh
set -e

in=$1
metadata=$2
out=$3
tmp=$4
nnet=$5
bn=$6

bash process.sh $in $metadata $tmp/uedin_tdnnf_decode $tmp $nnet/uedin_tdnnf $bn
bash process.sh $in $metadata $tmp/cued_tdnnf_decode $tmp $nnet/cued_tdnnf $bn

mkdir -p $out/debug/{uedin_tdnnf,cued_tdnnf}
cp -r $nnet/uedin_tdnnf/decode-* $out/debug/uedin_tdnnf
cp -r $tmp/uedin_tdnnf_decode/kws-* $out/debug/uedin_tdnnf
cp -r $nnet/cued_tdnnf/decode-* $out/debug/cued_tdnnf
cp -r $tmp/cued_tdnnf_decode/kws-* $out/debug/cued_tdnnf

cp -r $tmp/uedin_tdnnf_decode/*.ctm $out
cp -r $tmp/cued_tdnnf_decode/kws-* $out

chmod -R 777 $out/*
