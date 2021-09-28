import sys
import codecs

input_file = sys.argv[1]
output_file = sys.argv[2]
n = int(sys.argv[3])

lines = []
with codecs.open(input_file, 'r', 'utf-8') as f:
    for l in f:
        lines.append(l.strip())

with codecs.open(output_file, 'w', 'utf-8') as f:
    for start in range(n - 1):
        for i in range(start, len(lines), n - 1):
            print >> f, lines[i]

        print >> f
