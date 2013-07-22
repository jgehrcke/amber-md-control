#!/bin/bash
# Copyright 2012-2013 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

STARTDIR="$PWD"
SCRIPT_TO_EXECUTE="./mmgbsa_decomp_freemd_lastNframes.sh"
ABSPATH_TO_SCRIPT=$(readlink -f ${SCRIPT_TO_EXECUTE})
NBR_CPUS="$1"
BATCH_SYSTEM="$2"

if [[ ! -x "$SCRIPT_TO_EXECUTE" ]]; then
    echo "Does not exist or not executable: $SCRIPT_TO_EXECUTE"
    exit 1
fi

# Set up environment (Amber, Python, ...).
if [ -f "./env_setup.sh" ]; then
    source "./env_setup.sh"
fi

if [ -z "$NBR_CPUS" ]; then
    echo "First argument: number of CPUs (required)."
    exit 1
fi

echo "execute script in each free MD dir: ${ABSPATH_TO_SCRIPT}"

./find_unfinished_freemd_trajectories.sh --finished-only | while read FREEMDDIR
do
    cd "$FREEMDDIR"
    echo "Working in $FREEMDDIR (swallowing stdout)..."
    # Some MMPBSA-related process reads from STDIN and therefore swallows
    # the output of find_unfinished... provided to `while read...` above.
    # Give MMPBSA some STDIN to read from in order to keep the loop intact.
    if [[ "$BATCH_SYSTEM" == "--sge" ]]; then
        qsub -pe smp $NBR_CPUS -cwd -V -q bioinfp.q -b yes -o mmgbsa_sge.log -j y "/bin/bash ${ABSPATH_TO_SCRIPT} $NBR_CPUS" < /dev/null
    elif [[ "$BATCH_SYSTEM" == "--lsf" ]]; then
        echo "Not implemented for LSF. Exit."
        exit 1
    elif [[ "$BATCH_SYSTEM" == "--slurm" ]]; then
        echo "Not implemented for Slurm. Exit."
        exit 1
    else
        ${ABSPATH_TO_SCRIPT} "$NBR_CPUS" 1> /dev/null < /dev/null
    fi
    if [ $? -ne 0 ]; then
        echo "Error observed. Abort free MD dir iteration."
        exit 1
    fi
    cd "$STARTDIR"
done
