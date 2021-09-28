FROM material/asr-base
MAINTAINER Ondrej Klejch

WORKDIR /opt/app
ADD . /opt/app/

ARG lang
ARG lang_id
ARG nb_threshold
ARG wb_threshold

ENV LANGUAGE $lang
ENV LANGUAGE_ID $lang_id
ENV NB_THRESHOLD $nb_threshold
ENV WB_THRESHOLD $wb_threshold

CMD bash process.sh /opt/app/$LANGUAGE /opt/app/metadata/metadata.tsv /opt/app/asr-output /opt/app/language-verification-output $LANGUAGE_ID $NB_THRESHOLD $WB_THRESHOLD
