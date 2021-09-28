#!/bin/bash

if [ $# -ne 3 ]; then
    echo "Usage: $0 sample_frequency wav pitch_pov"
    exit 100
fi

SAMPLE_FREQUENCY=$1
WAV=$2
PITCH_POV=$3

mkdir -p $PITCH_POV

for wav in `ls -1 $WAV`; do
    name=`basename $wav .wav`
    echo "$name $WAV/$wav" > $PITCH_POV/pitch_pov.scp
    compute-kaldi-pitch-feats --verbose=2 --sample-frequency=$SAMPLE_FREQUENCY scp:$PITCH_POV/pitch_pov.scp ark:- | process-kaldi-pitch-feats --add-pov-feature=true --add-normalized-log-pitch=true --add-delta-pitch=false --add-raw-log-pitch=false --verbose=2 ark:- ark,t:- | awk '{if($NF!="["&&$NF!="]") print $0}' > $PITCH_POV/$name.pitch
done;
