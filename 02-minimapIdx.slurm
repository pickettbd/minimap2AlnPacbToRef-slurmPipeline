#! /bin/bash

# Set the max number of threads to use for programs using OpenMP. Should be <= ppn. Does nothing if the program doesn't use OpenMP.
export OMP_NUM_THREADS=$SLURM_CPUS_ON_NODE

# LOAD MODULES, INSERT CODE, AND RUN YOUR PROGRAMS HERE

#	Some handy variables
#${SLURM_MEM_PER_CPU}
#${SLURM_MEM_PER_NODE}
#${SLURM_JOB_NAME}
#${SLURM_NTASKS}
#${SLURM_JOB_NUM_NODES}

#	move into the correct place
if [ -n "$SLURM_JOB_ID" ] # basically, if this is managed by slurm vs being run locally
then
	if [ -n "$SLURM_JOB_NUM_NODES" ] && [ $SLURM_JOB_NUM_NODES -ne 1 ]
	then
		printf "%s\n" "This job is meant to be run with a single node" 1>&2
		exit 1
	elif [ -n "$SLURM_MEM_PER_CPU" ]
	then
		MEM_TASK_IN_MB=${SLURM_MEM_PER_CPU}
		MEM_JOB_IN_MB=$((${MEM_TASK_IN_MB}*${SLURM_NTASKS}))
		MEM_JOB_IN_GB=$((${MEM_JOB_IN_MB}/1024))
	elif [ -n "$SLURM_MEM_PER_NODE" ]
	then
		MEM_JOB_IN_MB=$((${SLURM_MEM_PER_NODE}*${SLURM_JOB_NUM_NODES}))
		MEM_JOB_IN_GB=$((${MEM_JOB_IN_MB}/1024))
		MEM_TASK_IN_MB=$(bc <<< "${MEM_JOB_IN_MB}/${SLURM_NTASKS}")
	else
		printf "%s\n" '$SLURM_MEM_PER_NODE and $SLURM_MEM_PER_CPU not specificed.' 1>&2
		exit 1
	fi
fi

#	move into the correct place
if [ -n "${SLURM_SUBMIT_DIR}" ]
then
	cd "$SLURM_SUBMIT_DIR"
else
	SLURM_SUBMIT_DIR=.
fi


#	manage job cleanup
cleanup()
{
	# cleanup tmp dir
	if [ -n $SLURM_JOB_ID ] && [ -e /tmp/${SLURM_JOB_ID} ]
	then
		rm -rf /tmp/${SLURM_JOB_ID} &> /dev/null
	fi
}

control_c()
{
	cleanup
	exit 1
}

trap control_c SIGHUP SIGINT SIGTERM SIGQUIT

# 	load modules
module purge
module load minimap2/2.17-r941

#	setup variables for the job
ASM_IDX="${1}"
OUTPUT_DIRS=($(readlink -n -m `dirname "${ASM_IDX}"`))
ASM_FA="${2}"

# 	check for existence of input file(s)
#		We assume minimap2 is capable of recognizing whether the
#		file(s) it requires exists.

# 	check for existence of expected output file(s)
if [ -e ${ASM_IDX} ]
then
	printf "%s\n" "INFO: All ${ASM_IDX} already exists! We assume that means this process can quit without running the intended command. Bye!" 1>&2
	cleanup
	exit 0
fi

#	create output directory(ies), if needed
mkdir -p "${OUTPUT_DIRS[@]}" &> /dev/null

#	run the program of interest
time minimap2 \
	-x "map-pb" \
	-I 2G \
	-P \
	-d "${ASM_IDX}" \
	"${ASM_FA}"

#	cleanup and exit
EXIT_CODE=$?
if [ ${EXIT_CODE} -eq 0 ]
then
	chmod 444 "${ASM_IDX}" &> /dev/null
else
	rm -f "${ASM_IDX}" &> /dev/null
fi

cleanup
exit ${EXIT_CODE}

#Usage: minimap2 [options] <target.fa>|<target.idx> [query.fa] [...]
#Options:
#  Indexing:
#    -H           use homopolymer-compressed k-mer (preferrable for PacBio)
#    -k INT       k-mer size (no larger than 28) [15]
#    -w INT       minimizer window size [10]
#    -I NUM       split index for every ~NUM input bases [4G]
#    -d FILE      dump index to FILE []
#  Mapping:
#    -f FLOAT     filter out top FLOAT fraction of repetitive minimizers [0.0002]
#    -g NUM       stop chain enlongation if there are no minimizers in INT-bp [5000]
#    -G NUM       max intron length (effective with -xsplice; changing -r) [200k]
#    -F NUM       max fragment length (effective with -xsr or in the fragment mode) [800]
#    -r NUM       bandwidth used in chaining and DP-based alignment [500]
#    -n INT       minimal number of minimizers on a chain [3]
#    -m INT       minimal chaining score (matching bases minus log gap penalty) [40]
#    -X           skip self and dual mappings (for the all-vs-all mode)
#    -p FLOAT     min secondary-to-primary score ratio [0.8]
#    -N INT       retain at most INT secondary alignments [5]
#  Alignment:
#    -A INT       matching score [2]
#    -B INT       mismatch penalty [4]
#    -O INT[,INT] gap open penalty [4,24]
#    -E INT[,INT] gap extension penalty; a k-long gap costs min{O1+k*E1,O2+k*E2} [2,1]
#    -z INT[,INT] Z-drop score and inversion Z-drop score [400,200]
#    -s INT       minimal peak DP alignment score [80]
#    -u CHAR      how to find GT-AG. f:transcript strand, b:both strands, n:don't match GT-AG [n]
#  Input/Output:
#    -a           output in the SAM format (PAF by default)
#    -o FILE      output alignments to FILE [stdout]
#    -L           write CIGAR with >65535 ops at the CG tag
#    -R STR       SAM read group line in a format like '@RG\tID:foo\tSM:bar' []
#    -c           output CIGAR in PAF
#    --cs[=STR]   output the cs tag; STR is 'short' (if absent) or 'long' [none]
#    --MD         output the MD tag
#    --eqx        write =/X CIGAR operators
#    -Y           use soft clipping for supplementary alignments
#    -t INT       number of threads [3]
#    -K NUM       minibatch size for mapping [500M]
#    --version    show version number
#  Preset:
#    -x STR       preset (always applied before other options; see minimap2.1 for details) []
#                 - map-pb/map-ont: PacBio/Nanopore vs reference mapping
#                 - ava-pb/ava-ont: PacBio/Nanopore read overlap
#                 - asm5/asm10/asm20: asm-to-ref mapping, for ~0.1/1/5% sequence divergence
#                 - splice: long-read spliced alignment
#                 - sr: genomic short-read mapping
#
#See `man ./minimap2.1' for detailed description of these and other advanced command-line options.

