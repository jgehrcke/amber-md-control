#!/bin/bash

STARTDIR="$PWD"
SCRIPT_TO_EXECUTE="./mmgbsa_decomp_freemd_last100frames.sh"
ABSPATH_TO_SCRIPT=$(readlink -f ${SCRIPT_TO_EXECUTE})
NBR_CPUS=$1

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
    ${ABSPATH_TO_SCRIPT} "$NBR_CPUS" 1> /dev/null < /dev/null
    if [ $? -ne 0 ]; then
        echo "Error observed. Abort free MD dir iteration."
        exit 1
    fi
    cd "$STARTDIR"
done
