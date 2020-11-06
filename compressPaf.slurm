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

#	check that enough input was given
if [ $# -ne 1 ]
then
	printf "%s\n" "ERROR: Expected 1 argument to this slurm file." 1>&2
	cleanup "failed"
	exit 1
fi

#	setup variables for the job
PAF_FILE=`readlink -n -m "${1}"` # .paf that needs to be gzipped

# 	check for existence of input files
#		We assume gzip is capable of recognizing whether the file(s)
#		it requires exist(s).

#	check for existence of output files
OUTPUT_FILES=("${PAF_FILE}.gz")
declare -a OUTPUT_DIRS
declare -a EXISTING_OUTPUT_FILES
for OUTPUT_FILE in "${OUTPUT_FILES[@]}"
do
	OUTPUT_DIRS+=($(readlink -n -m `dirname "${OUTPUT_FILE}"`))

	if [ -e "${OUTPUT_FILE}" ]
	then
		EXISTING_OUTPUT_FILES+=("${OUTPUT_FILE}")
	fi
done
OUTPUT_DIRS=($(printf "%s\n" "${OUTPUT_DIRS[@]}" | sort | uniq | tr '\n' ' '))

if [ ${#EXISTING_OUTPUT_FILES} -gt 0 ]
then
	printf "%s\n" "One or more output file existed already. We assume you don't want to overwrite" "it; quitting now. To overwrite it, first remove the following:" 1>&2
	printf "\t%s\n" "${EXISTING_OUTPUT_FILES[@]}" 1>&2
	cleanup "failed"
	exit 1
fi
unset EXISTING_OUTPUT_FILES

#	create output directory(ies), if needed
mkdir -p "${OUTPUT_DIRS[@]}" &> /dev/null
unset OUTPUT_DIRS

# move into the correct location
# not needed this time

#	run the program of interest
echo "CMD: gzip -c \"${PAF_FILE}\" \> \"${PAF_FILE}.gz\" \&" 1>&2
time gzip \
	-c \
	"${PAF_FILE}" \
	> "${PAF_FILE}.gz" &

wait `jobs -p`
EXIT_CODE=$?

# move back to the submit directory
#cd - &> /dev/null

#	cleanup and exit
if [ ${EXIT_CODE} -eq 0 ]
then
	chmod 444 "${OUTPUT_FILES[@]}" &> /dev/null
	printf "%s\n" "Okay to rm \"${PAF_FILE}\"" 1>&2
	cleanup "success"
else
	rm -f "${OUTPUT_FILES[@]}" &> /dev/null
	cleanup "failed"
fi
exit ${EXIT_CODE}

