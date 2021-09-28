FROM material/asr-base:mkl
MAINTAINER Ondrej Klejch

WORKDIR /opt/app/libs
ADD libs/HTK-3.4.1.tar.gz /opt/app/libs
ADD libs/hpf2hpf.c /opt/app/libs
RUN apt-get install -y libx11-dev libc6-dev-i386 && \
    cd htk && ./configure && \
    cd HTKLib && make -j 4 && \
    cd ../HTKTools && make -j 4 HCopy && \
    cd /opt/app/libs && gcc -o hpf2hpf hpf2hpf.c && mv hpf2hpf htk/HTKTools
ENV PATH="/opt/app/libs/htk/HTKLib:/opt/app/libs/htk/HTKTools/:$PATH"

WORKDIR /opt/app
ADD run.sh process.sh vad.py /opt/app/
ADD conf /opt/app/conf
ADD scripts /opt/app/scripts

ARG http_user
ARG http_pass
ARG model_address
ARG run_script=process.sh

RUN mkdir -p /opt/app/bn && \
    cd /opt/app/bn && \
    wget --http-user $http_user --http-password $http_pass http://data.cstr.inf.ed.ac.uk/material-scripts/models/asr/bn/v2.zip && \
    unzip *.zip

RUN mkdir -p /opt/app/nnet && \
    cd /opt/app/nnet && \
    wget --http-user $http_user --http-password $http_pass $model_address && \
    unzip *.zip

ENV run_script=$run_script
ENV NUMBER_OF_JOBS=8
ENV NUMBER_OF_THREADS=4

CMD bash $run_script /opt/app/input /opt/app/metadata/metadata.tsv /opt/app/output /opt/app/tmp /opt/app/nnet /opt/app/bn
