#!/bin/bash

if [ $# != 6 ]; then
    echo "USAGE: bash process.sh keywords asr_output_dir kws_output_dir model_dir tmp cache";
    exit 1;
fi

. path.sh

keywords=$1
asr_output_dir=$2
kws_output_dir=$3
model_dir=$4
tmp=$5
cache=$6
cache=$cache/`md5sum $keywords | awk '{print $1}'`

mkdir -p $tmp $cache

# Kaldi fix for cases with only one keyword
sed -i '/XMLin/s/STDIN)/STDIN, ForceArray=>["kw"])/' local/kws_data_prep*.sh

if [ ! -f $model_dir/lexiconp_nb.txt -a "$RUN_OOV" == true ]; then
    cp $model_dir/lexiconp.txt $model_dir/lexiconp_nb.txt
fi

if [ ! -f $model_dir/lexiconp_wb.txt -a "$RUN_OOV" == true ]; then
    cp $model_dir/lexiconp.txt $model_dir/lexiconp_wb.txt
fi

if [ ! -f $model_dir/words_nb.txt ]; then
    cp $model_dir/words.txt $model_dir/words_nb.txt
fi

if [ ! -f $model_dir/words_wb.txt ]; then
    cp $model_dir/words.txt $model_dir/words_wb.txt
fi

if [ ! -f $model_dir/confusions_nb.txt ]; then
    cp $model_dir/confusions.txt $model_dir/confusions_nb.txt
fi

if [ ! -f $model_dir/confusions_wb.txt ]; then
    cp $model_dir/confusions.txt $model_dir/confusions_wb.txt
fi


for RECORDING_TYPE in cs nb tb; do
    # Prepare data directories
    mkdir -p $tmp/data-$RECORDING_TYPE/iv $tmp/data-$RECORDING_TYPE/oov

    # Copy segments
    cp $asr_output_dir/kws-$RECORDING_TYPE/data/* $tmp/data-$RECORDING_TYPE/iv/
    cp $asr_output_dir/kws-$RECORDING_TYPE/data/* $tmp/data-$RECORDING_TYPE/oov/

    kws_dir=$asr_output_dir/kws-$RECORDING_TYPE
    if [ ! -d $kws_dir ]; then
        echo "There are no files with type $RECORDING_TYPE";
        continue;
    fi

    if [ "$RECORDING_TYPE" == "cs" ]; then
        words=words_nb
        lexiconp=lexiconp_nb
        confusions=confusions_nb
        oov_cache_dir="$cache/narrowband-oov"
        iv_cache_dir="$cache/narrowband-iv"
    else
        words=words_wb
        lexiconp=lexiconp_wb
        confusions=confusions_wb
        oov_cache_dir="$cache/wideband-oov"
        iv_cache_dir="$cache/wideband-iv"
    fi

    lang_dir=$model_dir/lang
    mkdir -p $lang_dir
    cp $model_dir/$words.txt $lang_dir/words.txt

    # Prepare kwlist.xml from $keywords
    awk '
        BEGIN { print("<kwlist ecf_filename=\"kwlist.xml\" language=\"lang\" encoding=\"UTF-8\" compareNormalize=\"\" version=\"keywords\">"); }
        { printf("\t<kw kwid=\"%04d\">\n\t\t<kwtext>%s</kwtext>\n\t</kw>\n", keywords++, $0); }
        END { print ("</kwlist>"); }
    ' $keywords > $tmp/data-$RECORDING_TYPE/oov/kwlist.xml
    awk '{ printf("%04d\t%s\n", keywords++, $0); }' $keywords > $tmp/data-$RECORDING_TYPE/oov/keywords_id

    cp $tmp/data-$RECORDING_TYPE/oov/{keywords_id,kwlist.xml} $tmp/data-$RECORDING_TYPE/iv/

    # Prepare lexicon for OOVs
    if [ "$RUN_OOV" == true ]; then
        if [ ! -d $oov_cache_dir ]; then
            join -v 1 -j 1 <(cat $keywords | tr ' ' '\n' | sort -u) <(awk '{print $1}' $model_dir/$words.txt | sort -u) > $tmp/data-$RECORDING_TYPE/oov/oov.txt
            bash local/apply_g2p.sh --var-counts 3 --var-mass 0.9 $tmp/data-$RECORDING_TYPE/oov/oov.txt $model_dir $tmp/oov_lexicon
            sed -i 's/^\(.*\t.*\t\)1.0 /\1/' $tmp/oov_lexicon/lexicon.lex
        fi
    fi

    # Prepare OOV KWS data dirs
    if [ "$RUN_OOV" == true ]; then
        if [ ! -d $oov_cache_dir ]; then
            local/kws_data_prep_proxy.sh \
                --nj $NUMBER_OF_JOBS \
                --case-insensitive true \
                --confusion-matrix $model_dir/$confusions.txt \
                --phone-cutoff $PHONE_CUTOFF \
                --pron-probs true \
                --beam $BEAM \
                --nbest $NBEST \
                --phone-beam $PHONE_BEAM \
                --phone-nbest $PHONE_NBEST \
                $lang_dir $tmp/data-$RECORDING_TYPE/oov $model_dir/$lexiconp.txt $tmp/oov_lexicon/lexicon.lex $tmp/data-$RECORDING_TYPE/oov

            cp -r $tmp/data-$RECORDING_TYPE/oov $oov_cache_dir
        else
            rm -rf $tmp/data-$RECORDING_TYPE/oov
            cp -r $oov_cache_dir $tmp/data-$RECORDING_TYPE/oov

            cp $asr_output_dir/kws-$RECORDING_TYPE/data/segments $tmp/data-$RECORDING_TYPE/oov/segments
            cat $asr_output_dir/kws-$RECORDING_TYPE/data/segments | \
                awk '{print $1}' | \
                sort | uniq | perl -e '
                $idx=1;
                while(<>) {
                    chomp;
                    print "$_ $idx\n";
                    $idx++;
                }' > $tmp/data-$RECORDING_TYPE/oov/utter_id

            cat $asr_output_dir/kws-$RECORDING_TYPE/data/segments | awk '{print $1" "$2}' | sort | uniq > $tmp/data-$RECORDING_TYPE/oov/utter_map
        fi
    fi

    # Prepare IV KWS data dirs
    if [ "$RUN_IV" == true ]; then
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
    fi

    tmp_kws_output_dir=$tmp/kws-$RECORDING_TYPE

    # Search indices
    for word_type in iv oov; do
        mkdir -p $tmp_kws_output_dir/$word_type

        if [ ! -s $tmp/data-$RECORDING_TYPE/$word_type/keywords.fsts ]; then
            echo "There are no keywords.fsts for $RECORDING_TYPE and $word_type";
            continue
        fi

        local/search_index_parallel.sh --num_threads $NUMBER_OF_THREADS --strict false --indices-dir $kws_dir $tmp/data-$RECORDING_TYPE/$word_type $tmp_kws_output_dir/$word_type || exit 1;
    done
done

sort -u $tmp/kws-*/*/result.*.txt > $kws_output_dir/result.txt
chmod -R 777 $kws_output_dir/* $cache
