#!/bin/bash

STARTDIR="$PWD"
SCRIPT_TO_EXECUTE="./minimize_freemd_finalsystemstate.sh"
ABSPATH_TO_SCRIPT=$(readlink -f ${SCRIPT_TO_EXECUTE})

if [[ ! -x "$SCRIPT_TO_EXECUTE" ]]; then
    echo "Does not exist or not executable: $SCRIPT_TO_EXECUTE"
    exit 1
fi

# Set up environment (Amber, Python, ...).
if [ -f "./env_setup.sh" ]; then
    source "./env_setup.sh"
fi

echo "execute script in each free MD dir: ${ABSPATH_TO_SCRIPT}"

./find_unfinished_freemd_trajectories.sh --finished-only | while read FREEMDDIR
do
    cd "$FREEMDDIR"
    echo "Working in $FREEMDDIR (swallowing stdout)..."
    # Hardcode topology and coordinate file, forward args to this script to
    # gpu/cpu args of minimization script.
    ${ABSPATH_TO_SCRIPT} top.prmtop production_NVT.rst "$@" 1> /dev/null < /dev/null
    if [ $? -ne 0 ]; then
        echo "Error observed. Abort free MD dir iteration."
        exit 1
    fi
    cd "$STARTDIR"
done
