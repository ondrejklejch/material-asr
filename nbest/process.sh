#!/bin/bash

if [ $# != 3 ]; then
    echo "USAGE: bash process.sh asr_output_dir nbest_output_dir tmp";
    exit 1;
fi

source path.sh
set -e

asr_output_dir=$1
nbest_output_dir=$2
tmp_dir=$3
n=${N:-10}
lat_dir=${LAT_DIR:-".lats"}
lang_dir=${LANG_DIR:-".lang"}

mkdir -p $nbest_output_dir $tmp
rm -f $nbest_output_dir/*.{ctm,txt,utt,conf,rest.bst}

for RECORDING_TYPE in cs tb nb; do
    data=$asr_output_dir/kws-$RECORDING_TYPE/data/
    lats=$asr_output_dir/kws-$RECORDING_TYPE/$lat_dir
    lang=$asr_output_dir/kws-$RECORDING_TYPE/$lang_dir
    model=$asr_output_dir/kws-$RECORDING_TYPE/.model/final.mdl

    nj=`cat $lats/num_jobs`
    wip=`cat $lang/WIP 2> /dev/null || echo 0.5`
    lmwt=`cat $lang/LMWT 2> /dev/null || echo 10`

    tmp=$tmp_dir/$RECORDING_TYPE
    mkdir -p $tmp
    rm -rf $tmp/*

    python lowercase_words.py $lang/words.txt $tmp/words.txt

    run.pl JOB=1:$nj $nbest_output_dir/log/$RECORDING_TYPE/lattice_mbr_decode.JOB.log \
        lattice-scale --inv-acoustic-scale=$lmwt "ark:gunzip -c $lats/lat.JOB.gz|" ark:- \| \
        lattice-add-penalty --word-ins-penalty=$wip ark:- ark:- \| \
        lattice-prune --beam=5 ark:- ark:- \| \
        lattice-align-words $lang/phones/word_boundary.int $model ark:- ark:- \| \
        lattice-mbr-decode --one-best-times=true ark:- ark,t:$tmp/transcript.JOB.txt ark:/dev/null ark,t:$tmp/sausage_stats.JOB.txt ark,t:$tmp/times.JOB.txt || exit 1

    run.pl JOB=1:$nj $nbest_output_dir/log/$RECORDING_TYPE/print_nbest.JOB.log \
        python print_nbest.py $tmp/transcript.JOB.txt $tmp/times.JOB.txt $tmp/sausage_stats.JOB.txt $n $data/reco2file_and_channel $data/segments $tmp/JOB.ctm $tmp/JOB.nbest.txt

    # Sort nbest files by start time
    cat $tmp/*.nbest.txt | \
        int2sym.pl -f 7- $tmp/words.txt - | \
        sed 's/ /\t/;s/ /\t/;s/ /\t/;s/ /\t/;s/ /\t/;s/ /\t/;' | \
        sort -k 1,1 -k 4,4n -k 5,5n -k 2,2 -k 6,6nr > $tmp/nbest.txt

    # Create .txt files
    awk -v n=$n '(NR-1) % n == 0' $tmp/nbest.txt | \
        awk -F $'\t' -v out=$nbest_output_dir '{print $7 >> out"/"$1".txt"}'

    # Create .utt files
    awk -v n=$n '(NR-1) % n == 0' $tmp/nbest.txt | \
        awk -F $'\t' -v out=$nbest_output_dir '{print $1, $2, $4, $5, $7 >> out"/"$1".utt"}'

    # Create .conf files
    awk -v n=$n '(NR-1) % n == 0' $tmp/nbest.txt | \
        awk -F $'\t' -v out=$nbest_output_dir '{print $6 >> out"/"$1".conf"}'

    # Create .rest.bst files
    awk -v n=$n '(NR-1) % n != 0' $tmp/nbest.txt | \
        awk -F $'\t' -v out=$tmp '{print $7 >> out"/"$1".rest.bst"}'

    # Create .rest.bst.conf files
    awk -v n=$n '(NR-1) % n != 0' $tmp/nbest.txt | \
        awk -F $'\t' -v out=$tmp '{print $6 >> out"/"$1".rest.bst.conf"}'

    # Reformat .rest* files
    ls -1 $tmp | grep .rest.bst | \
        xargs -I {} python reformat.py $tmp/{} $nbest_output_dir/{} $n

    # Sort CTM by start time and split it into files
    cat $tmp/*.ctm | \
        int2sym.pl -f 5 $tmp/words.txt - | \
        sort -k 1,1 -k 3,3n | \
        awk -v out=$nbest_output_dir '{print $0 >> out"/"$1".ctm"}'
done

chmod -R 777 $nbest_output_dir $tmp_dir
