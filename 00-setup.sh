#! /bin/bash

tail -n +9 "${BASH_SOURCE[0]}" | head -n -1 | fold -s

exit 0

# Everything below this line is simple documentation
:'
This should be really be done manually. You just need to get the input data where it needs to go. There are two categories: the reference and the reads.
The reference needs to be located at data/assembly/asm.fa[.gz].
The reads should be located in data/pacbio. If you wanted to try reads from more than one sample, you should name them something different, though ideally following the same theme and structure; e.g., sample1.fa.[.gz], sample2.fa[.gz], ..., sampleN.fa[.gz].
'
