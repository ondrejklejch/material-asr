#!/bin/bash

if [ $# -ne 3 ]; then
    echo "Usage: $0 fbk pitch_pov fbk_pitch_pov"
    exit 100
fi

FBK=$1
PITCH_POV=$2
FBK_PITCH_POV=$3

mkdir -p $FBK_PITCH_POV

for fbk in `ls -1 $FBK/*.fbk`; do
    name=`basename $fbk .fbk`
    hpf2hpf $FBK/${name}.fbk $PITCH_POV/${name}.pitch 2 $FBK_PITCH_POV/${name}.fbk
done

