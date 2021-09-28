#!/bin/bash

if [ $# != 5 ]; then
    echo "USAGE: bash process_iv.sh keywords asr_output_dir kws_output_dir tmp cache";
    exit 1;
fi

. path.sh

keywords=$1
asr_output_dir=$2
kws_output_dir=$3
tmp=$4
cache=$5
cache=$cache/`md5sum $keywords | awk '{print $1}'`

mkdir -p $tmp $cache $kws_output_dir

# Kaldi fix for cases with only one keyword
sed -i '/XMLin/s/STDIN)/STDIN, ForceArray=>["kw"])/' local/kws_data_prep*.sh

for RECORDING_TYPE in cs nb tb; do
    # Prepare data directories
    mkdir -p $tmp/data-$RECORDING_TYPE/iv

    # Copy segments
    cp $asr_output_dir/kws-$RECORDING_TYPE/data/* $tmp/data-$RECORDING_TYPE/iv/

    kws_dir=$asr_output_dir/kws-$RECORDING_TYPE
    if [ ! -d $kws_dir ]; then
        echo "There are no files with type $RECORDING_TYPE";
        continue;
    fi

    if [ -d $asr_output_dir/kws-$RECORDING_TYPE/.kws_lang ]; then
        lang_dir=$asr_output_dir/kws-$RECORDING_TYPE/.kws_lang/
    else
        lang_dir=$asr_output_dir/kws-$RECORDING_TYPE/.lang/
    fi

    if [ ! -f $lang_dir/words.txt ]; then
        echo "words.txt does not exist for type $RECORDING_TYPE";
        continue;
    fi

    if [ "$RECORDING_TYPE" == "cs" ]; then
        iv_cache_dir="$cache/narrowband-iv"
    else
        iv_cache_dir="$cache/wideband-iv"
    fi


    # Prepare kwlist.xml from $keywords
    awk '
        BEGIN { print("<kwlist ecf_filename=\"kwlist.xml\" language=\"lang\" encoding=\"UTF-8\" compareNormalize=\"\" version=\"keywords\">"); }
        { printf("\t<kw kwid=\"%04d\">\n\t\t<kwtext>%s</kwtext>\n\t</kw>\n", keywords++, $0); }
        END { print ("</kwlist>"); }
    ' $keywords > $tmp/data-$RECORDING_TYPE/iv/kwlist.xml
    awk '{ printf("%04d\t%s\n", keywords++, $0); }' $keywords > $tmp/data-$RECORDING_TYPE/iv/keywords_id

    # Prepare IV KWS data dirs
    if [ ! -d $iv_cache_dir ]; then
        local/kws_data_prep.sh \
            --case-insensitive true \
            $lang_dir $tmp/data-$RECORDING_TYPE/iv $tmp/data-$RECORDING_TYPE/iv

        cp -r $tmp/data-$RECORDING_TYPE/iv $iv_cache_dir
    else
        rm -rf $tmp/data-$RECORDING_TYPE/iv
        cp -r $iv_cache_dir $tmp/data-$RECORDING_TYPE/iv

        cp $asr_output_dir/kws-$RECORDING_TYPE/data/segments $tmp/data-$RECORDING_TYPE/iv/segments
        cat $asr_output_dir/kws-$RECORDING_TYPE/data/segments | \
            awk '{print $1}' | \
            sort | uniq | perl -e '
            $idx=1;
            while(<>) {
                chomp;
                print "$_ $idx\n";
                $idx++;
            }' > $tmp/data-$RECORDING_TYPE/iv/utter_id

        cat $asr_output_dir/kws-$RECORDING_TYPE/data/segments | awk '{print $1" "$2}' | sort | uniq > $tmp/data-$RECORDING_TYPE/iv/utter_map
    fi

    tmp_kws_output_dir=$tmp/kws-$RECORDING_TYPE

    # Search indices
    for word_type in iv; do
        mkdir -p $tmp_kws_output_dir/$word_type

        if [ ! -s $tmp/data-$RECORDING_TYPE/$word_type/keywords.fsts ]; then
            echo "There are no keywords.fsts for $RECORDING_TYPE and $word_type";
            continue
        fi

        local/search_index_parallel.sh --num_threads $NUMBER_OF_THREADS --strict false --indices-dir $kws_dir $tmp/data-$RECORDING_TYPE/$word_type $tmp_kws_output_dir/$word_type || exit 1;
    done
done

sort -u $tmp/kws-*/*/result.*.txt > $kws_output_dir/result.txt
chmod -R 777 $kws_output_dir/*
