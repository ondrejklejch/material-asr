#!/bin/bash

echo "$0 $*"

if [ $# != 7 ]; then
    echo "USAGE: bash process.sh conf_tree_dir metadata asr_output_dir language_verification_dir lang-id nb_threshold wb_threshold";
    exit 1;
fi

conf_tree_dir=$1
metadata=$2
asr_output_dir=$3
language_verification_dir=$4
lang_id=$5
nb_threshold=$6
wb_threshold=$7

mkdir -p $language_verification_dir/report

if [ ! -f $conf_tree_dir/conf_nb.tree ]; then
    cp $conf_tree_dir/conf.tree $conf_tree_dir/conf_nb.tree
fi

if [ ! -f $conf_tree_dir/conf_wb.tree ]; then
    cp $conf_tree_dir/conf.tree $conf_tree_dir/conf_wb.tree
fi

while read line; do
    name=`echo $line | awk '{print $1}' | sed 's/.wav//'`
    type=`echo $line | awk '{print $2}' | sed 's/NB/wb/;s/TB/wb/;s/CS/nb/;'`

    if [ "$type" == "wb" ]; then
        threshold=$wb_threshold
    else
        threshold=$nb_threshold
    fi

    if [ ! -f $asr_output_dir/$name.ctm ]; then
	>&2 echo "File $asr_output_dir/$name.ctm doesn't exist"
	continue
    fi

    bash conftree-apply $asr_output_dir/$name.ctm $conf_tree_dir/conf_$type.tree $language_verification_dir/$name.conf
    bash ctm-conf-average $language_verification_dir/$name.conf | \
        awk -v threshold=$threshold -v name=$name '{if ($4 >= threshold) {printf("%s\tY\t%.4f\n", name, $4)} else {printf("%s\tN\t%.4f\n", name, $4)} }'
    rm $language_verification_dir/$name.conf
done < <(tail -n +2 $metadata | grep -xv "") | sort -k 3,3nr > $language_verification_dir/report/$lang_id.tsv

chmod -R 777 $language_verification_dir
