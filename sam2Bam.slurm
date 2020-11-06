#! /bin/bash

# Set the max number of threads to use for programs using OpenMP. Should be <= ppn. Does nothing if the program doesn't use OpenMP.
if [ -n "$SLURM_CPUS_ON_NODE" ]
then
	export OMP_NUM_THREADS=$SLURM_CPUS_ON_NODE
fi

# LOAD MODULES, INSERT CODE, AND RUN YOUR PROGRAMS HERE

#	Some handy variables
#${SLURM_MEM_PER_CPU}
#${SLURM_MEM_PER_NODE}
#${SLURM_JOB_NAME}
#${SLURM_NTASKS}
#${SLURM_JOB_NUM_NODES}
#${SLURM_JOB_ID}

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

	TMP="/tmp/${SLURM_JOB_ID}"
else
	TMP="/tmp/${$}"
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
	elif [ -e /tmp/${$} ]
	then
		rm -rf /tmp/${$} &> /dev/null
	fi

	# move successful/failed job files to the correct place
	local SUCCESS_FAIL_STATUS_SUBDIR
	SUCCESS_FAIL_STATUS_SUBDIR="${1:-success}"

	mv \
		${SLURM_SUBMIT_DIR}/job_files/${SLURM_JOB_NAME}__${SLURM_JOB_ID}.{err,out} \
		${SLURM_SUBMIT_DIR}/job_files/${SUCCESS_FAIL_STATUS_SUBDIR} \
		&> /dev/null
}

control_c()
{
	kill -SIGINT `jobs -p`
	cleanup "failed"
	exit 1
}

trap control_c SIGHUP SIGINT SIGTERM SIGQUIT

outOfTime()
{
	printf "%s\n" "This job ran out of time! SLURM sent signal USR1 and now we're trying to quite gracefully. (fingers crossed!)" 1>&2
	kill -SIGINT `jobs -p`

	printf "%s\n" "Now using 'cleanup' function with status 'success'. Be advised: this process ran out of time- you will need to run this again with more time (unless it checkpoints, in which case it will still need to run again, just not necessarily with more time)." 1>&2
	cleanup "success"

	exit 10 # SIGUSR1 == 10
}

trap outOfTime USR1

# 	load modules
module purge
module load samtools/1.10

#	check that enough input was given
if [ $# -ne 2 ]
then
	printf "%s\n" "ERROR: Expected 2 argument to this slurm file." 1>&2
	cleanup "failed"
	exit 1
fi

#	setup variables for the job
INPUT_SAM="${1}"
OUTPUT_BAM="${2}"
OUTPUT_DIRS=($(readlink -f `dirname "${OUTPUT_BAM}"`))
OUTPUT_DIRS=($(printf "%s\n" "${OUTPUT_DIRS[@]}" | sort | uniq | tr '\n' ' '))
EXTRA_THREADS=$((${SLURM_NTASKS:-2}-2))

# 	check for existence of input file(s)
#		We assume samtools is capable of recognizing whether the
#		file(s) it requires exists.

# 	check for existence of expected output file(s)
if [ -e "${OUTPUT_BAM}" ]
then
	printf "%s\n" "INFO: ${OUTPUT_BAM} already exists! We assume this means we can quit this process without running the intended command. Bye!" 1>&2
	cleanup "success"
	exit 0
fi

#	create output directory(ies), if needed
mkdir -p "${OUTPUT_DIRS[@]}" &> /dev/null
unset OUTPUT_DIRS

#	create tmp directory
TMP_DIR="/tmp/${SLURM_JOB_ID}"
mkdir "${TMP_DIR}" &> /dev/null

#	run the program of interest
set -o pipefail
time samtools view \
	-bu \
	-h \
	-F 4 \
	"${INPUT_SAM}" \
	| samtools sort \
		-@ "${EXTRA_THREADS:-0}" \
		-m "${MEM_TASK_IN_MB}M" \
		-T "${TMP_DIR}" \
		-O "BAM" \
		-o "${OUTPUT_BAM}" \
		- &

wait `jobs -p`
EXIT_CODE=$?
set +o pipefail

#	cleanup and exit
if [ ${EXIT_CODE} -eq 0 ]
then
	chmod 444 "${OUTPUT_BAM}" &> /dev/null
	printf "%s\n\t%s\n" \
		"You should be safe to run the following:" \
		"rm -f \"${INPUT_SAM}\"" \
		1>&2
else
	rm -f "${OUTPUT_BAM}" &> /dev/null
fi

cleanup
exit ${EXIT_CODE}

# Usage: samtools view [options] <in.bam>|<in.sam>|<in.cram> [region ...]
# 
# Options:
#   -b       output BAM
#   -C       output CRAM (requires -T)
#   -1       use fast BAM compression (implies -b)
#   -u       uncompressed BAM output (implies -b)
#   -h       include header in SAM output
#   -H       print SAM header only (no alignments)
#   -c       print only the count of matching records
#   -o FILE  output file name [stdout]
#   -U FILE  output reads not selected by filters to FILE [null]
#   -t FILE  FILE listing reference names and lengths (see long help) [null]
#   -L FILE  only include reads overlapping this BED FILE [null]
#   -r STR   only include reads in read group STR [null]
#   -R FILE  only include reads with read group listed in FILE [null]
#   -q INT   only include reads with mapping quality >= INT [0]
#   -l STR   only include reads in library STR [null]
#   -m INT   only include reads with number of CIGAR operations consuming
#            query sequence >= INT [0]
#   -f INT   only include reads with all  of the FLAGs in INT present [0]
#   -F INT   only include reads with none of the FLAGS in INT present [0]
#   -G INT   only EXCLUDE reads with all  of the FLAGs in INT present [0]
#   -s FLOAT subsample reads (given INT.FRAC option value, 0.FRAC is the
#            fraction of templates/read pairs to keep; INT part sets seed)
#   -x STR   read tag to strip (repeatable) [null]
#   -B       collapse the backward CIGAR operation
#   -?       print long help, including note about region specification
#   -S       ignored (input format is auto-detected)
#       --input-fmt-option OPT[=VAL]
#                Specify a single input file format option in the form
#                of OPTION or OPTION=VALUE
#   -O, --output-fmt FORMAT[,OPT[=VAL]]...
#                Specify output format (SAM, BAM, CRAM)
#       --output-fmt-option OPT[=VAL]
#                Specify a single output file format option in the form
#                of OPTION or OPTION=VALUE
#   -T, --reference FILE
#                Reference sequence FASTA FILE [null]
#   -@, --threads INT
#                Number of additional threads to use [0]
