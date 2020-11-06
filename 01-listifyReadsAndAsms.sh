#! /bin/bash

tail -n +9 "${BASH_SOURCE[0]}" | head -n -1 | fold -s

exit 0

# Everything below this line is simple documentation
:'
This should be really be done manually. You just need to make a record of inputs.
Create a file called data/asms.list. Each line should be a record. It should contain the filename of an assembly without the path. This assumes the file is in the data/assembly directory.
Create a file called data/pacbs.list. Each line should be a record. Each record should contain one or more filenames. A read set, whether in a single file or spread across multiple files, that should be treated independantly from other read sets (if they exist) should be contained in a single line with a tab character between file names. The files are provided without the path, meaning they are assumed to be (and must actually be) in data/pacbio.
These files will be used instead of hardcoding important file names into the submission scripts.
Similarly, some helpful variables should be included in the data/vars-longAln.list file. This should take the form of a bash script format file that can be directly sourced in whatever other script is being run. So, each line should be: VARIABLE="value".
'
