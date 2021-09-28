FROM ubuntu:16.04
MAINTAINER Ondrej Klejch

WORKDIR /opt/app
RUN apt-get update && \
    apt-get install -y build-essential libatlas-base-dev python python-dev python-pip python3 python3-dev python3-pip git wget gfortran g++ unzip zlib1g-dev automake autoconf libtool sox subversion libicu-dev swig libxml-simple-perl

ADD requirements.txt prepare_env.sh path.sh /opt/app/
RUN pip install numpy==1.14.2 && pip install -r requirements.txt && bash prepare_env.sh
