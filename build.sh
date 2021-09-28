#!/bin/bash

cd base
docker build -t material/asr-base:mkl .
cd ..

cd asr

TL_ASR_MODEL_URL="http://data.cstr.inf.ed.ac.uk/material-scripts/models/asr/tl/v3.zip"
SW_ASR_MODEL_URL="http://data.cstr.inf.ed.ac.uk/material-scripts/models/asr/sw/v3.zip"
SO_ASR_MODEL_URL="http://data.cstr.inf.ed.ac.uk/material-scripts/models/asr/so/v3.zip"
LT_ASR_MODEL_URL="http://data.cstr.inf.ed.ac.uk/material-scripts/models/asr/lt/v3.zip"
BG_ASR_MODEL_URL="http://data.cstr.inf.ed.ac.uk/material-scripts/models/asr/bg/v4.zip"
PS_ASR_MODEL_URL="http://data.cstr.inf.ed.ac.uk/material-scripts/models/asr/ps/v6.zip"
FA_ASR_MODEL_URL="http://data.cstr.inf.ed.ac.uk/material-scripts/models/asr/ps/v2.2.zip"

docker build \
    --build-arg http_user=$HTTP_USER \
    --build-arg http_pass=$HTTP_PASS \
    --build-arg model_address=$TL_ASR_MODEL_URL \
    --build-arg run_script=run.sh \
    -t material/asr-tl .

docker build \
    --build-arg http_user=$HTTP_USER \
    --build-arg http_pass=$HTTP_PASS \
    --build-arg model_address=$SW_ASR_MODEL_URL \
    --build-arg run_script=run.sh \
    -t material/asr-sw .

docker build \
    --build-arg http_user=$HTTP_USER \
    --build-arg http_pass=$HTTP_PASS \
    --build-arg model_address=$SO_ASR_MODEL_URL \
    --build-arg run_script=run.sh \
    -t material/asr-so .

docker build \
    --build-arg http_user=$HTTP_USER \
    --build-arg http_pass=$HTTP_PASS \
    --build-arg model_address=$LT_ASR_MODEL_URL \
    --build-arg run_script=run.sh \
    -t material/asr-lt .

docker build \
    --build-arg http_user=$HTTP_USER \
    --build-arg http_pass=$HTTP_PASS \
    --build-arg model_address=$BG_ASR_MODEL_URL \
    --build-arg run_script=run.sh \
    -t material/asr-bg .

docker build \
    --build-arg http_user=$HTTP_USER \
    --build-arg http_pass=$HTTP_PASS \
    --build-arg model_address=$PS_ASR_MODEL_URL \
    --build-arg run_script=process.sh \
    -t material/asr-ps .

docker build \
    --build-arg http_user=$HTTP_USER \
    --build-arg http_pass=$HTTP_PASS \
    --build-arg model_address=$FA_ASR_MODEL_URL \
    --build-arg run_script=process.sh \
    -t material/asr-fa .
cd ..

cd kws

TL_KWS_MODEL_URL="http://data.cstr.inf.ed.ac.uk/material-scripts/models/kws/tl/v3.zip"
SW_KWS_MODEL_URL="http://data.cstr.inf.ed.ac.uk/material-scripts/models/kws/sw/v1.zip"
SO_KWS_MODEL_URL="http://data.cstr.inf.ed.ac.uk/material-scripts/models/kws/so/v1.zip"
LT_KWS_MODEL_URL="http://data.cstr.inf.ed.ac.uk/material-scripts/models/kws/lt/v1.zip"
BG_KWS_MODEL_URL="http://data.cstr.inf.ed.ac.uk/material-scripts/models/kws/bg/v1.zip"

docker build \
    --build-arg http_user=$HTTP_USER \
    --build-arg http_pass=$HTTP_PASS \
    --build-arg model_address=$TL_KWS_MODEL_URL \
    -t material/kws-tl .

docker build \
    --build-arg http_user=$HTTP_USER \
    --build-arg http_pass=$HTTP_PASS \
    --build-arg model_address=$SW_KWS_MODEL_URL \
    -t material/kws-sw .

docker build \
    --build-arg http_user=$HTTP_USER \
    --build-arg http_pass=$HTTP_PASS \
    --build-arg model_address=$SO_KWS_MODEL_URL \
    -t material/kws-so .

docker build \
    --build-arg http_user=$HTTP_USER \
    --build-arg http_pass=$HTTP_PASS \
    --build-arg model_address=$LT_KWS_MODEL_URL \
    -t material/kws-lt .

docker build \
    --build-arg http_user=$HTTP_USER \
    --build-arg http_pass=$HTTP_PASS \
    --build-arg model_address=$BG_KWS_MODEL_URL \
    -t material/kws-lt .

docker build -t material/kws-language-independent .

cd ..

cd language_verification

docker build \
    --build-arg lang=tagalog \
    --build-arg lang_id=1B \
    --build-arg wb_threshold=0.53 \
    --build-arg nb_threshold=0.53 \
    -t material/language-verification-tl:v1.0 .

docker build \
    --build-arg lang=swahili \
    --build-arg lang_id=1A \
    --build-arg wb_threshold=0.53 \
    --build-arg nb_threshold=0.53 \
    -t material/language-verification-sw:v1.0 .

docker build \
    --build-arg lang=somali \
    --build-arg lang_id=1S \
    --build-arg wb_threshold=0.53 \
    --build-arg nb_threshold=0.53 \
    -t material/language-verification-so:v1.0 .

cd ..

cd nbest

docker build -t material/nbest:v1.0 .

cd ..

docker rmi material/asr-base
