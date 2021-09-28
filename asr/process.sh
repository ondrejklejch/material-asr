#!/bin/bash

if [ $# != 6 ]; then
    echo "USAGE: bash process.sh input_dir metadata.tsv output_dir tmp_dir nnet_dir bn_dir";
    exit 1;
fi

source path.sh
set -e

in=$1
metadata=$2
out=$3
tmp=$4
nnet=$5
bn=$6

if [ ! -d rnnlm ]; then
    ln -s $KALDI_ROOT/scripts/rnnlm .
fi

rm -rf $out/* $tmp/{nb,tb,cs,files} $tmp/data*
mkdir -p $tmp/{nb,tb,cs}/{input,output} $out || exit 1;
awk -v source=$in -v target=$tmp '/^MATERIAL_/ {printf("ln -s %s/%s %s/%s/input/\n", source, $1, target, tolower($2))}' $metadata | bash

for RECORDING_TYPE in cs tb nb; do
    if [ "$RECORDING_TYPE" == "cs" ]; then
        GRAPH_TYPE="nb"
    else
        GRAPH_TYPE="wb"
    fi

    iter=final
    if [ -f "${nnet}/final_${GRAPH_TYPE}.mdl" ]; then
        iter=final_${GRAPH_TYPE}
    fi

    # Resample all recordings to 8kHz
    rm -rf $tmp/files $tmp/data*
    mkdir -p $tmp/{files,data}

    # Check that there are files of the given type
    num_files=`ls -1 $tmp/$RECORDING_TYPE/input/*.wav 2> /dev/null | wc -l`
    if [ $num_files == 0 ]; then
        echo "There are no files with type $RECORDING_TYPE";
        continue;
    fi

    feats=`cat $nnet/feats_${GRAPH_TYPE} 2> /dev/null || echo bottleneck`
    ivector_feats=`cat $nnet/ivector_feats_${GRAPH_TYPE} 2> /dev/null || echo $feats`
    for f in $tmp/$RECORDING_TYPE/input/*.wav; do
        basename=`basename $f | sed 's/.wav$//'`

        if [ "$RECORDING_TYPE" == "cs" ]; then
            sox $f -t wav -r 8000 -e signed-integer $tmp/files/${basename}_c1.wav remix 1
            sox $f -t wav -r 8000 -e signed-integer $tmp/files/${basename}_c2.wav remix 2
        else
            if [ "$feats" == "bottleneck" ] || [ "$feats" == "fbank+ppov8k" ]; then
                sox $f -t wav -r 8000 -e signed-integer -c 1 $tmp/files/$basename.wav
            else
                sox $f -t wav -r 16000 -e signed-integer -c 1 $tmp/files/$basename.wav
            fi
        fi
    done

    # Split input file into segments and prepare data dir
    if [ ! -f $tmp/wav-${RECORDING_TYPE}.scp ]; then
        python vad.py 0 $tmp/files/ $tmp/wav-${RECORDING_TYPE}.scp $tmp/segments-${RECORDING_TYPE}
    fi

    cp $tmp/wav-${RECORDING_TYPE}.scp $tmp/data/wav.scp
    cp $tmp/segments-${RECORDING_TYPE} $tmp/data/segments
    awk '{print $1, "text"}' $tmp/data/segments > $tmp/data/text
    awk '{print $2, $2, 1}' $tmp/data/segments | sed 's/_c1 1$/ A/;s/_c2 1$/ B/' > $tmp/data/reco2file_and_channel

    if [ "$GRAPH_TYPE" == "nb" ]; then
        awk '{print $1, $2}' $tmp/data/segments > $tmp/data/utt2spk
    else
        awk '{print $1, $1}' $tmp/data/segments > $tmp/data/utt2spk
    fi

    utils/utt2spk_to_spk2utt.pl < $tmp/data/utt2spk > $tmp/data/spk2utt
    utils/fix_data_dir.sh $tmp/data
    utils/validate_data_dir.sh --no-feats $tmp/data

    num_spks=`cat $tmp/data/spk2utt | wc -l`
    nj=$(($NUMBER_OF_JOBS * $NUMBER_OF_THREADS))
    nj=$(($nj>$num_spks?$num_spks:$nj))

    # Extract fbank + ppov features
    data=data
    if [ "$feats" == "bottleneck" ]; then
        bash scripts/make-fbk.sh conf/fbk-nb.cfg $tmp/files $tmp/data-fbk || (echo "make-fbk failed" && exit 1)
        bash scripts/make-pitch-pov.sh 8000 $tmp/files $tmp/data-pitch-pov || (echo "make-pitch-pov failed" && exit 1)
        bash scripts/make-fbk-pitch-pov.sh $tmp/data-fbk $tmp/data-pitch-pov $tmp/data-fbk-pitch-pov || (echo "make-fbk-pitch-pov failed" && exit 1)
        bash scripts/fbk-pitch-pov-to-ark.sh $tmp/data-fbk-pitch-pov $tmp/data/segments $tmp/data/utt2spk $tmp/data/spk2utt $tmp/data
        steps/nnet3/make_bottleneck_features.sh --cmd run.pl --nj $nj tdnn_bn.renorm $tmp/data $tmp/data-bnf $bn
        steps/append_feats.sh --cmd run.pl --nj $nj $tmp/data-bnf $tmp/data $tmp/data-all $tmp/data-all/log $tmp/data-all
        steps/compute_cmvn_stats.sh $tmp/data-all
        ln -s $tmp/data $tmp/data_fbank+ppov8k
        ln -s $tmp/data-all $tmp/data_bottleneck
        data=data-all
    elif [ "$feats" == "fbank16k" ]; then
        steps/make_fbank.sh --fbank-config conf/fbank16k.conf $tmp/data
        steps/compute_cmvn_stats.sh $tmp/data
        ln -s $tmp/data $tmp/data_${feats}
        data=data
    elif [ "$feats" == "mfcc16k" ]; then
        steps/make_mfcc.sh --mfcc-config conf/mfcc16k_hires.conf $tmp/data
        steps/compute_cmvn_stats.sh $tmp/data
        ln -s $tmp/data $tmp/data_${feats}
        data=data
    elif [ "$feats" == "mfcc8k" ]; then
        steps/make_mfcc.sh --mfcc-config conf/mfcc8k_hires.conf $tmp/data
        steps/compute_cmvn_stats.sh $tmp/data
        ln -s $tmp/data $tmp/data_${feats}
        data=data
    elif [ "$feats" == "fbank+ppov8k" ]; then
        bash scripts/make-fbk.sh conf/fbk-nb.cfg $tmp/files $tmp/data-fbk || (echo "make-fbk failed" && exit 1)
        bash scripts/make-pitch-pov.sh 8000 $tmp/files $tmp/data-pitch-pov || (echo "make-pitch-pov failed" && exit 1)
        bash scripts/make-fbk-pitch-pov.sh $tmp/data-fbk $tmp/data-pitch-pov $tmp/data-fbk-pitch-pov || (echo "make-fbk-pitch-pov failed" && exit 1)
        bash scripts/fbk-pitch-pov-to-ark.sh $tmp/data-fbk-pitch-pov $tmp/data/segments $tmp/data/utt2spk $tmp/data/spk2utt $tmp/data
        ln -s $tmp/data $tmp/data_${feats}
        data=data
    else
        bash scripts/make-fbk.sh conf/fbk-wb.cfg $tmp/files $tmp/data-fbk || (echo "make-fbk failed" && exit 1)
        bash scripts/make-pitch-pov.sh 16000 $tmp/files $tmp/data-pitch-pov || (echo "make-pitch-pov failed" && exit 1)
        bash scripts/make-fbk-pitch-pov.sh $tmp/data-fbk $tmp/data-pitch-pov $tmp/data-fbk-pitch-pov || (echo "make-fbk-pitch-pov failed" && exit 1)
        bash scripts/fbk-pitch-pov-to-ark.sh $tmp/data-fbk-pitch-pov $tmp/data/segments $tmp/data/utt2spk $tmp/data/spk2utt $tmp/data
        ln -s $tmp/data $tmp/data_${feats}
        data=data
    fi

    # Decode
    nj=${NUMBER_OF_JOBS:-1}
    nj=$(($nj>$num_spks?$num_spks:$nj))
    decode_dir=$nnet/decode-$RECORDING_TYPE

    rm -rf $decode_dir
    if [ -f $nnet/graph-$GRAPH_TYPE/phones.txt ]; then
        cp $nnet/graph-$GRAPH_TYPE/phones.txt $nnet/phones.txt
    else
        touch $nnet/graph-$GRAPH_TYPE/phones.txt $nnet/phones.txt
    fi
    decode_opts="--nj $nj --num-threads $NUMBER_OF_THREADS --iter $iter --frames-per-chunk 140 --extra-left-context 0 --acwt 1.0 --post-decode-acwt 10.0 --skip_diagnostics true --skip-scoring true"

    if [ -d $nnet/extractor-$GRAPH_TYPE ]; then
        if [ ! -f $tmp/data_${ivector_feats}/feats.scp ]; then
            echo "Missing features for the i-vector extractor $tmp/data_${ivector_feats}/feats.scp"
            exit 1;
        fi

        steps/online/nnet2/extract_ivectors_online.sh --cmd "run.pl" --nj $nj \
            $tmp/data_${ivector_feats} $nnet/extractor-$GRAPH_TYPE $tmp/ivectors_$RECORDING_TYPE || exit 1;
        decode_opts="$decode_opts --online-ivector-dir $tmp/ivectors_$RECORDING_TYPE"
    fi

    steps/nnet3/decode.sh $decode_opts $nnet/graph-$GRAPH_TYPE $tmp/$data $decode_dir

    if [ -d $nnet/rnnlm-$GRAPH_TYPE ]; then
        #nj=$(($NUMBER_OF_JOBS * $NUMBER_OF_THREADS))
        #steps/copy_lat_dir.sh --cmd run.pl --nj $nj $tmp/$data $decode_dir ${decode_dir}/split${nj}

        WEIGHT=$(cat $nnet/rnnlm-$GRAPH_TYPE/WEIGHT 2> /dev/null || echo 0.5)
        rnnlm/lmrescore_pruned.sh \
            --cmd "run.pl --mem 4G" \
            --weight $WEIGHT --max-ngram-order 4 \
            --skip-scoring true \
            $nnet/graph-$GRAPH_TYPE $nnet/rnnlm-$GRAPH_TYPE $tmp/$data $decode_dir ${decode_dir}_rnnlm_rescore

        rescore_dir="${decode_dir}_rnnlm_rescore"
    else
        rescore_dir=$decode_dir
    fi

    # Generate ctm
    LMWT=$(cat $nnet/graph-$GRAPH_TYPE/LMWT)
    WIP=$(cat $nnet/graph-$GRAPH_TYPE/WIP 2> /dev/null || echo 0.5)
    local/lattice_to_ctm.sh --word-ins-penalty $WIP --model $nnet/$iter.mdl $tmp/$data $nnet/graph-$GRAPH_TYPE $rescore_dir

    # Make index for KWS
    mkdir -p $tmp/data-kws-$RECORDING_TYPE
    cp $tmp/data/segments $tmp/data-kws-$RECORDING_TYPE/segments
    cp $tmp/data/reco2file_and_channel $tmp/data-kws-$RECORDING_TYPE/reco2file_and_channel

    cat $tmp/data/segments | \
        awk '{print $1}' | \
        sort | uniq | perl -e '
        $idx=1;
        while(<>) {
            chomp;
            print "$_ $idx\n";
            $idx++;
        }' > $tmp/data-kws-$RECORDING_TYPE/utter_id

    acwt=0.06
    lmwt=0.6

    make_index_opts="--model $nnet/$iter.mdl --frame_subsampling_factor 3 --acwt $acwt --lmwt $lmwt"
    steps/make_index.sh $make_index_opts $tmp/data-kws-$RECORDING_TYPE $nnet/graph-$GRAPH_TYPE $decode_dir $decode_dir/kws-$RECORDING_TYPE

    mv $decode_dir/kws-$RECORDING_TYPE $out/kws-$RECORDING_TYPE
    mv $tmp/data-kws-$RECORDING_TYPE $out/kws-$RECORDING_TYPE/data
    awk -v out=$out '{print $0 >> out"/"$1".ctm"}' $rescore_dir/score_${WIP}_${LMWT}/$data.ctm

    mkdir -p $out/kws-$RECORDING_TYPE/.lats
    cp $rescore_dir/num_jobs $out/kws-$RECORDING_TYPE/.lats/
    cp $rescore_dir/lat.*.gz $out/kws-$RECORDING_TYPE/.lats/
    cp -r $rescore_dir/log $out/kws-$RECORDING_TYPE/.lats/

    mkdir -p $out/kws-$RECORDING_TYPE/.kws_lats
    cp $decode_dir/num_jobs $out/kws-$RECORDING_TYPE/.kws_lats/
    cp $decode_dir/lat.*.gz $out/kws-$RECORDING_TYPE/.kws_lats/
    cp -r $decode_dir/log $out/kws-$RECORDING_TYPE/.kws_lats/

    mkdir -p $out/kws-$RECORDING_TYPE/.model
    cp $nnet/$iter.mdl $out/kws-$RECORDING_TYPE/.model/final.mdl

    mkdir -p $out/kws-$RECORDING_TYPE/.lang
    cp $nnet/graph-$GRAPH_TYPE/words.txt $out/kws-$RECORDING_TYPE/.lang
    cp -r $nnet/graph-$GRAPH_TYPE/phones $out/kws-$RECORDING_TYPE/.lang
    cp -r $nnet/graph-$GRAPH_TYPE/{LMWT,WIP} $out/kws-$RECORDING_TYPE/.lang

    mkdir -p $out/kws-$RECORDING_TYPE/.kws_lang
    if [ ! -f $nnet/graph-$GRAPH_TYPE/words_kws.txt ]; then
        cp $nnet/graph-$GRAPH_TYPE/words.txt $out/kws-$RECORDING_TYPE/.kws_lang/words.txt
    else
        cp $nnet/graph-$GRAPH_TYPE/words_kws.txt $out/kws-$RECORDING_TYPE/.kws_lang/words.txt
    fi
    cp -r $nnet/graph-$GRAPH_TYPE/phones $out/kws-$RECORDING_TYPE/.kws_lang
    cp -r $nnet/graph-$GRAPH_TYPE/{LMWT,WIP} $out/kws-$RECORDING_TYPE/.kws_lang
done

chmod -R 777 $out/*
chmod -R 777 $tmp/*
