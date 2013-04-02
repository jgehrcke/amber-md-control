#!/bin/bash

STARTDIR="$PWD"
SCRIPT_TO_EXECUTE="./mmpbsa_freemd_last100frames.sh"
ABSPATH_TO_SCRIPT=$(readlink -f ${SCRIPT_TO_EXECUTE})
NBR_CPUS=$1

if [ -z "$NBR_CPUS" ]; then
    echo "First argument: number of CPUs (required)."
    exit 1
fi

echo "execute script in each free MD dir: ${ABSPATH_TO_SCRIPT}"

./find_unfinished_freemd_trajectories.sh --finished-only | while read FREEMDDIR
do
    cd "$FREEMDDIR"
    echo "Working in $FREEMDDIR (swallowing stdout)..."
    # Give it some STDIN to read from, otherwise the while loop might break.
    ${ABSPATH_TO_SCRIPT} "$NBR_CPUS" 1> /dev/null < /dev/null
    if [ $? -ne 0 ]; then
        echo "Error observed. Abort free MD dir iteration."
        exit 1
    else
        echo "Exit code 0. Continue."
    fi
    echo "cd $STARTDIR"
    cd "$STARTDIR"
done
