#/bin/bash

output=${1:-output}

for f in $output/*.ctm; do
    out=`echo $f | sed 's/\.ctm$//'`

    (
        python3 split_segments.py <(awk '{if($2 == "A") print $0}' $f | sort -k 3,3n) A /dev/stdout
        python3 split_segments.py <(awk '{if($2 == "B") print $0}' $f | sort -k 3,3n) B /dev/stdout
        python3 split_segments.py <(awk '{if($2 == "0") print $0}' $f | sort -k 3,3n) 0 /dev/stdout
        python3 split_segments.py <(awk '{if($2 == "1") print $0}' $f | sort -k 3,3n) 1 /dev/stdout
    ) | sort -k 1,1 -k 3,3n > $out.utt

    cut -f5 $out.utt > $out.txt
done
