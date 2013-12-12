#!/bin/bash
# Copyright 2012-2013 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

STARTDIR="$PWD"
SCRIPT_TO_EXECUTE="./trajframe_to_pdb_using_stripmask.sh"
ABSPATH_TO_SCRIPT=$(readlink -f ${SCRIPT_TO_EXECUTE})

if [ ! -f "$ABSPATH_TO_SCRIPT" ]; then
    echo "No such file: '${ABSPATH_TO_SCRIPT}'" 1>&2
    exit 1
fi


MD_DIR="."
# Set up environment (Amber, Python, ...), exit upon error.
if [[ -f "${MD_DIR}/env_setup.sh" ]]; then
    source "${MD_DIR}/env_setup.sh"
else
    echo "file missing: ${MD_DIR}/env_setup.sh"
    exit 1
fi


echo "Execute script for each finished freeMD: ${ABSPATH_TO_SCRIPT}"

# Filter started free MDs (not finished), i.e. if after_freemd_min2.rst exists
# in free MD dir, then extract PDB. It's up to the final minimization script
# to decide which free MD states are 'final' enough to be minimized. (At the time of
# writing this comment, after_freemd_min2.rst has been created from free MD
# trajectories with at least 2200 frames (while 2500 was the goal).
RST_FILE="after_freemd_min2.rst"
./find_unfinished_freemd_trajectories.sh --started-only | while read FREEMDDIR
do
    cd "$FREEMDDIR"
    echo "Working in $FREEMDDIR ..."
    if [ ! -f "$RST_FILE" ];then
        echo "No $RST_FILE, skipping."
        continue
    fi
    ${ABSPATH_TO_SCRIPT} top.prmtop "$RST_FILE" lastframe ':WAT,Cl-,Na+' freemd_final_system_state_aftermin.pdb 1> /dev/null < /dev/null
    if [ $? -ne 0 ]; then
        echo "Error observed. Abort freeMD dir iteration."
        exit 1
    fi
    cd "$STARTDIR"
done
