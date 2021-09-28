from __future__ import print_function
import codecs
import sys
import heapq
import math
from itertools import izip


def load_data(transcript, times, sausage_stats):
    return izip(load_transcript(transcript), load_times(times), load_sausage_stats(sausage_stats))


def load_transcript(transcript):
    with open(transcript, 'r') as f:
        for line in f:
            # Handles empty transcript
            if " " not in line.strip():
                yield line.strip(), []
                continue

            utt, word_ids = line.strip().split(None, 1)
            yield utt, [int(w) for w in word_ids.split()]


def load_times(times):
    parse_times = lambda times: tuple([float(t) for t in times.strip().split()])

    with open(times, 'r') as f:
        for line in f:
            # Handles empty transcript
            if " " not in line.strip():
                yield line.strip(), []
                continue

            utt, times = line.strip().split(None, 1)
            yield utt, [parse_times(t) for t in times.split(";")]


def load_sausage_stats(sausage_stats):
    with open(sausage_stats, 'r') as f:
        for line in f:
            utt, sausage_stats = line.strip().split(None, 1)

            sausage_stats = sausage_stats.strip(" []").split("] [")
            yield utt, [dict(parse_sausage_stats(s)) for s in sausage_stats]


def parse_sausage_stats(sausage_stats):
    sausage_stats = sausage_stats.split()

    for word, prob in zip(sausage_stats, sausage_stats[1:])[::2]:
        yield int(word), float(prob)


def load_reco2file_and_channel(reco2file_and_channel):
    d = {}

    with open(reco2file_and_channel, 'r') as f:
        for line in f:
            (reco, filename, channel) = line.strip().split()
            d[reco] = (filename, channel)

    return d


def load_segments(segments):
    d = {}

    with open(segments, 'r') as f:
        for line in f:
            (utt, reco, start, end) = line.strip().split()
            d[utt] = (reco, float(start), float(end))

    return d


def generate_nbest_list(sausage_stats, n=1):
    pq = [(0., [])]

    for sausage in sausage_stats:
        new_pq = []

        for (p1, words) in pq:
            for (word, p2) in sausage.items():
                new_pq.append((p1 + math.log(p2), words + [word]))

        pq = heapq.nlargest(n, new_pq, lambda x: x[0])

    return pq


def get_sentences(transcript, times, sausage_stats):
    pause_durations = [max(s - e, 0) for (_,e), (s,_) in zip(times, times[1:])] + [0]
    words = zip(transcript, times, pause_durations)
    best_path = generate_nbest_list(sausage_stats, 1)[0][1]

    for utt in split_hierarchically_by_longest_pause(words):
        start_time = utt[0][1][0]
        end_time = utt[-1][1][1]
        current_sausage_length = compute_current_sausage_length(utt, best_path)

        yield (utt[0][1][0], utt[-1][1][1], sausage_stats[:current_sausage_length])

        best_path = best_path[current_sausage_length:]
        sausage_stats = sausage_stats[current_sausage_length:]


def compute_current_sausage_length(utt, best_path):
    current_sausage_length = 0
    for word in utt:
        while best_path[current_sausage_length] == 0:
            current_sausage_length += 1

        current_sausage_length += 1

        while current_sausage_length < len(best_path) and best_path[current_sausage_length] == 0:
            current_sausage_length += 1

    return current_sausage_length


def split_hierarchically_by_longest_pause(words):
    if len(words) <= 40:
        yield words
        return

    argmax = max(range(len(words) - 1), key=lambda x: words[x][2])
    for utt in split_hierarchically_by_longest_pause(words[:argmax + 1]):
        yield utt

    for utt in split_hierarchically_by_longest_pause(words[argmax + 1:]):
        yield utt


if __name__ == "__main__":
    transcript = sys.argv[1]
    times = sys.argv[2]
    sausage_stats = sys.argv[3]
    n = int(sys.argv[4])
    reco2file_and_channel = sys.argv[5]
    segments = sys.argv[6]
    ctm_output = sys.argv[7]
    nbest_output = sys.argv[8]
    frame_shift = 0.03

    reco2file_and_channel = load_reco2file_and_channel(reco2file_and_channel)
    segments = load_segments(segments)

    with open(nbest_output, 'w') as f_nbest, open(ctm_output, 'w') as f_ctm:
        for (utt, transcript), (_, times), (_, sausage_stats) in load_data(transcript, times, sausage_stats):
            # We don't care about utterances that are most probably silence.
            if len(transcript) == 0:
                continue

            # Extract confidence scores for best path
            best_path = generate_nbest_list(sausage_stats, 1)[0][1]
            confidences = [dict(sausage)[word] for (sausage, word) in zip(sausage_stats, best_path) if word != 0]

            # Print CTM
            for word, (start_time, end_time), conf in zip(transcript, times, confidences):
                filename, channel = reco2file_and_channel[segments[utt][0]]
                start = segments[utt][1] + start_time * frame_shift
                duration = (end_time - start_time) * frame_shift

                print("%s %s %.2f %.2f %s %.2f" % (filename, channel, start, duration, word, conf), file=f_ctm)

            # Print N-BEST
            for i, (start_time, end_time, sausage_stats) in enumerate(get_sentences(transcript, times, sausage_stats)):
                nbest_list = list(generate_nbest_list(sausage_stats, n))
                nbest_list = nbest_list + [(math.log(1e-40), nbest_list[0][1]) for _ in range(max(0, n - len(nbest_list)))]

                for conf, nbest in nbest_list:
                    filename, channel = reco2file_and_channel[segments[utt][0]]
                    start = segments[utt][1] + start_time * frame_shift
                    end = segments[utt][1] + end_time * frame_shift
                    text = " ".join([str(x) for x in nbest if x != 0])

                    print("%s %s %s-sen-%03d %.2f %.2f %.6f %s" % (filename, channel, utt, i, start, end, conf, text), file=f_nbest)
