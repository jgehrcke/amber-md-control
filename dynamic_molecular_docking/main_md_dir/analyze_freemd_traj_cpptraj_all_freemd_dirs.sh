#!/bin/bash

STARTDIR="$PWD"
SCRIPT_TO_EXECUTE="./analyze_freemd_traj_cpptraj.sh"
ABSPATH_TO_SCRIPT=$(readlink -f ${SCRIPT_TO_EXECUTE})

echo "execute script in each free MD dir: ${ABSPATH_TO_SCRIPT}"

./find_unfinished_freemd_trajectories.sh --finished-only | while read FREEMDDIR
do
cd "$FREEMDDIR"
echo "Working in $FREEMDDIR (swallowing stdout)..."
${ABSPATH_TO_SCRIPT} 1> /dev/null
if [ $? -ne 0 ]; then
    echo "Error observed. Abort free MD dir iteration."
    exit 1
fi
cd "$STARTDIR"
done
