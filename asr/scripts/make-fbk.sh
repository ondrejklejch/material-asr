#!/bin/bash

if [ $# -ne 3 ]; then
    echo "Usage: $0 cfg wav fbk"
    exit 100
fi

CFG=$1
WAV=$2
FBK=$3

mkdir -p $FBK

ls -1 $WAV | sed -e "s|\.wav||g" | awk -v wav=$WAV -v fbk=$FBK '{print wav"/"$1".wav "fbk"/"$1".fbk"}' > $FBK/hcopy.lst
HCopy -T 7 -A -D -V -C $CFG -S $FBK/hcopy.lst &> $FBK/hcopy.log
