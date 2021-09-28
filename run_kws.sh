#!/bin/bash

LANG=$1

if [ "$LANG" != "sw" ] && [ "$LANG" != "tl" ]; then
    echo "Only 'sw' and 'tl' are supported at the moment."
    exit 1;
fi

docker run -i -t --rm \
    -v `pwd`/input/keywords.txt:/opt/app/keywords.txt \
    -v `pwd`/output/:/opt/app/asr-output \
    -v `pwd`/kws-output/:/opt/app/kws-output \
    material/kws-$LANG
