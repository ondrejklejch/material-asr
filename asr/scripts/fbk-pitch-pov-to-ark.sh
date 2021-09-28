#!/bin/bash

if [ $# -ne 5 ]; then
    echo "Usage: $0 fbk_pitch_pov segments utt2spk spk2utt fbk_pitch_pov_ark"
    exit 100
fi

HTK=$1
SEG=$2
U2S=$3
S2U=$4
ARK=$5

mkdir -p $ARK

cat $SEG | awk -v src=$HTK -v tgt=$ARK '{print $1".fbk="src"/"$2".fbk["$3*100","$4*100"] "tgt"/"$1".fbk"}' > $ARK/hcopy.lst
HCopy -A -D -T 1 -C conf/kaldi.cfg -S $ARK/hcopy.lst &> $ARK/hcopy.log

cat $SEG | awk -v tgt=$ARK '{print $1" "tgt"/"$1".fbk:0"}' > $ARK/kaldi.lst

pipeline="ark:copy-feats --htk-in=true scp:$ARK/kaldi.lst ark:- |"
copy-feats "$pipeline" ark,scp:$ARK/fbk_pitch_pov.ark,$ARK/fbk_pitch_pov.scp || exit 1
cat $ARK/fbk_pitch_pov.scp | sort > $ARK/tmp.scp
mv $ARK/tmp.scp $ARK/fbk_pitch_pov.scp
ln -s fbk_pitch_pov.scp $ARK/feats.scp

rm -f $ARK/*.fbk

# Compute CMVN statistics
compute-cmvn-stats --spk2utt=ark:$S2U scp:$ARK/fbk_pitch_pov.scp ark,scp:$ARK/cmvn_fbk_pitch_pov.ark,$ARK/fbk_pitch_pov.cmvn.scp || exit 1
ln -s fbk_pitch_pov.cmvn.scp $ARK/cmvn.scp
