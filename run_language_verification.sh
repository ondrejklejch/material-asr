#!/bin/bash

LANG=$1

if [ "$LANG" != "sw" ] && [ "$LANG" != "tl" ]; then
    echo "Only 'sw' and 'tl' are supported at the moment."
    exit 1;
fi

docker run -i -t --rm \
    -v `pwd`/output/:/opt/app/asr-output \
    -v `pwd`/metadata/metadata.tsv:/opt/app/metadata/metadata.tsv \
    -v `pwd`/language-verification-output/:/opt/app/language-verification-output \
    material/language-verification-$LANG
