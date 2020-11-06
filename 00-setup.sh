#! /bin/bash

tail -n +9 "${BASH_SOURCE[0]}" | head -n -1 | fold -s

exit 0

# Everything below this line is simple documentation
:'
This should be really be done manually. You just need to get the input data where it needs to go. There are two categories: the reference and the reads.
The reference needs to be located at data/assembly/asm.fa[.gz].
The reads should be located in data/pacbio. Example names might be raw.fa[.gz] and corrected.fa[.gz]. They could also be separated out with numbers like this: raw1.fa[.gz], raw2.fa[.gz], ..., rawN.fa[.gz]. If you wanted to try raw reads and corrected reads or if you had reads from more than on sample, you should name them something different, though ideally following the same theme and structure.
The names I used when I did this were raw.fa and corrected.fa.
'
