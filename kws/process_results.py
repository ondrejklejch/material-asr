import sys
import codecs

keywords = {}
with codecs.open(sys.argv[1], 'r', 'utf-8') as f:
    for line in f:
        keyword_id, keyword = line.strip().split()
        keywords[keyword_id] = keyword

id2utt = {}
with open(sys.argv[2], 'r') as f:
    for line in f:
        utt, id = line.strip().split()
        id2utt[id] = utt

segments = {}
with open(sys.argv[3], 'r') as f:
    for line in f:
        (segment, wav, start, end) = line.strip().split()
        segments[segment] = (wav, float(start), float(end))

frame_subsampling_factor = int(sys.argv[4])
with codecs.open(sys.argv[5], 'w', 'utf-8') as f:
    for line in sys.stdin:
        (keyword_id, segment_id, start, end, neg_log_prob) = line.strip().split()
        segment = id2utt[segment_id]

        print >> f, "%s\t%s\t%.2f\t%.2f\t%s" % (
            keywords[keyword_id],
            segments[segment][0].replace("_c1", "").replace("_c2", ""),
            segments[segment][1] + int(start) * frame_subsampling_factor * 0.01,
            segments[segment][1] + int(end) * frame_subsampling_factor * 0.01,
            neg_log_prob
        )
