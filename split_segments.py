from __future__ import print_function
import codecs
import sys



def load_words(path):
    with codecs.open(path, "r", "utf-8") as f:
        lines = [l for l in f.read().strip().split("\n") if l]

        last_start = None
        last_utt = None
        words = []
        for line in reversed(lines):
            line = line.strip().split()
            utt = line[0]
            start = float(line[2])
            end = start + float(line[3])
            word = line[4]

            if last_start is None or last_utt != utt:
                pause = 0.0
            else:
                pause = last_start - end

            last_start = float(start)
            last_utt = utt

            words.append((utt, start, end, pause, word))

        return list(reversed(words))


def split_files(words):
    while words:
        file_id = words[0][0]

        file_words = []
        while words and words[0][0] == file_id:
            file_words.append(words.pop(0))

        yield file_words


def split_utterances(file_words):
    for utt_words in split_by_pause_duration_threshold(file_words):
        for utterance in split_hierarchically_by_longest_pause(utt_words):
            yield utterance


def split_by_pause_duration_threshold(file_words):
    silences = sorted([w[3] for w in file_words])
    threshold = silences[int(len(silences) * 0.95)]

    utt = []
    for word in file_words:
        if word[3] >= threshold:
            utt.append(word)
            yield utt
            utt = []
        else:
            utt.append(word)

    if utt:
        yield utt


def split_hierarchically_by_longest_pause(file_words):
    if len(file_words) <= 40:
        yield file_words
        return

    argmax = max(range(len(file_words) - 1), key=lambda x: file_words[x][3])
    for utt in split_hierarchically_by_longest_pause(file_words[:argmax + 1]):
        yield utt

    for utt in split_hierarchically_by_longest_pause(file_words[argmax + 1:]):
        yield utt


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.stderr.write('Usage: python3 split_segments.py data.ctm channel\n')
        sys.exit(1)

    words = load_words(sys.argv[1])
    channel = sys.argv[2]
    output = sys.argv[3]

    with codecs.open(output, 'w', 'utf-8') as f:
        for file_words in split_files(words):
            for utterance in split_utterances(file_words):
                file_id = utterance[0][0]
                start = utterance[0][1]
                end = utterance[-1][2]
                text = u" ".join([w[-1] for w in utterance])
                print(file_id, channel, "%.2f" % start, "%.2f" % end, text, sep = '\t', file=f)
