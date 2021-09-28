FROM material/asr-base:mkl
MAINTAINER Ondrej Klejch

WORKDIR /opt/app
ADD process_iv.sh process_results.py /opt/app/
ADD src/search_index_parallel.sh /opt/app/local/
ADD src/kws-search-parallel.cc /opt/app/libs/kaldi/src/kwsbin/

RUN cd /opt/app/libs/kaldi/src/kwsbin/ && \
    sed -i 's/BINFILES =/\0 kws-search-parallel/' Makefile && \
    make kws-search-parallel

ENV RUN_IV true
ENV NUMBER_OF_JOBS 32
ENV NUMBER_OF_THREADS 4

CMD bash process_iv.sh /opt/app/keywords.txt /opt/app/asr-output /opt/app/kws-output /opt/app/tmp /opt/app/cache
