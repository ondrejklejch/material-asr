#!/bin/bash

docker run -i -t --rm \
    -v `pwd`/asr_output:/opt/app/asr-output \
    -v `pwd`/nbest_output:/opt/app/nbest-output \
    -e N=5 \
    material/nbest
