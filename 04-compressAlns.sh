#! /bin/bash

tail -n +9 "${BASH_SOURCE[0]}" | head -n -1 | fold -s

exit 0

# Everything below this line is simple documentation
:'
Depending on your choice of paf or sam format for the output alignments, you will need to run different scripts for step #5. If you chose sam format, use 05sam-a and 05sam-b (in that order). If you chose paf format, use 05paf. In either case, the goal is to compress the format from what is in the plain-text paf or sam file. In the case of the sam format, it will also be sorted (by position) and indexed.
'
