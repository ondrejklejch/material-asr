#!/bin/bash

LANG=$1
NUMBER_OF_JOBS=${2:-1}

if [ "$LANG" != "sw" ] && [ "$LANG" != "tl" ]; then
    echo "Only 'sw' and 'tl' are supported at the moment."
    exit 1;
fi

docker run -i -t --rm \
    -v `pwd`/input:/opt/app/input \
    -v `pwd`/metadata/metadata.tsv:/opt/app/metadata/metadata.tsv \
    -v `pwd`/output:/opt/app/output \
    -e NUMBER_OF_JOBS=$NUMBER_OF_JOBS \
    material/asr-$LANG
