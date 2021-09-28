FROM material/asr-base
MAINTAINER Ondrej Klejch

WORKDIR /opt/app
ADD process.sh print_nbest.py reformat.py lowercase_words.py /opt/app/
ENV N 10
ENV LAT_DIR .lats
ENV LANG_DIR .lang
CMD bash process.sh /opt/app/asr-output /opt/app/nbest-output /opt/app/tmp
