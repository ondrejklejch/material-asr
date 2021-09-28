#!/usr/bin/env bash
set -e

KALDI_REV=98f2edfeb7c6b6efab42d0ab48cff070f37ca363

if [ ! -d libs ]; then
    mkdir -p libs

    # Get Kaldi.
    git clone https://github.com/kaldi-asr/kaldi.git libs/kaldi
    (
        cd libs/kaldi/src;
        git checkout ${KALDI_REV}
    )

    # Prepare Kaldi dependencies.
    (
        # Patch OpenFST makefile so that we can link with it statically.
        cd libs/kaldi/tools;
        sed -i "s/--enable-ngram-fsts/--enable-ngram-fsts --with-pic/g" Makefile
        make -j 16 openfst
    )

    # Install MKL
    (
	cd libs/kaldi/tools/extras
	wget https://raw.githubusercontent.com/kaldi-asr/kaldi/master/tools/extras/install_mkl.sh
	bash install_mkl.sh
    )

    # Configure Kaldi.
    (
        cd libs/kaldi/src;
        git checkout ${KALDI_REV}
        ./configure --use-cuda=no --mkl-root=/opt/intel/mkl/
    )

    # Build Kaldi.
    make -j 16 -C libs/kaldi/src
    make -j 16 -C libs/kaldi/src test
else
    echo "It appears that the env is prepared. If there are errors, try deleting libs/ and rerunning the script."
fi


export KALDI_ROOT=/opt/app/libs/kaldi

ln -s $KALDI_ROOT/egs/wsj/s5/utils .
ln -s $KALDI_ROOT/egs/wsj/s5/steps .
ln -s $KALDI_ROOT/egs/babel/s5d/local .

. $KALDI_ROOT/tools/config/common_path.sh
export PATH="/opt/app/utils/:$PATH"
