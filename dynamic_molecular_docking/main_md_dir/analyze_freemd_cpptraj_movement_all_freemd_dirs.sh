#!/bin/bash
# Copyright 2012-2013 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

SCRIPT_TO_EXECUTE="./analyze_freemd_cpptraj_movement.sh"

# Set up environment (Amber, Python, ...).
if [ -f "./env_setup.sh" ]; then
    source "./env_setup.sh"
fi
STARTDIR="$PWD"
ABSPATH_TO_SCRIPT=$(readlink -f ${SCRIPT_TO_EXECUTE})
echo "Execute script in each free MD dir: ${ABSPATH_TO_SCRIPT}"

#./find_unfinished_freemd_trajectories.sh --minframes 2200 | while read FREEMDDIR
./find_unfinished_freemd_trajectories.sh --finished-only | while read FREEMDDIR
do
cd "$FREEMDDIR"
echo "Working in '$FREEMDDIR' (swallowing stdout)..."
${ABSPATH_TO_SCRIPT} 1> /dev/null < /dev/null
if [ $? -ne 0 ]; then
    echo "Error observed. Abort free MD dir iteration."
    exit 1
fi
cd "$STARTDIR"
done
