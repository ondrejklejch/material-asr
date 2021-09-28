from __future__ import print_function

import codecs
import sys

with codecs.open(sys.argv[1], 'r', 'utf-8') as f_in, codecs.open(sys.argv[2], 'w', 'utf-8') as f_out:
  for l in f_in:
    print(l.strip().lower().replace('=', ''), file=f_out)
