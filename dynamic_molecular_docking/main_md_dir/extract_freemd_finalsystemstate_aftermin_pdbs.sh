#!/bin/bash
#
#   Copyright 2012-2013 Jan-Philip Gehrcke
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#

STARTDIR="$PWD"
SCRIPT_TO_EXECUTE="./trajframe_to_pdb_using_stripmask.sh"
ABSPATH_TO_SCRIPT=$(readlink -f ${SCRIPT_TO_EXECUTE})

if [ ! -f "$ABSPATH_TO_SCRIPT" ]; then
    echo "No such file: '${ABSPATH_TO_SCRIPT}'" 1>&2
    exit 1
fi

# Set up environment (Amber, Python, ...).
if [ -f "./env_setup.sh" ]; then
    source "./env_setup.sh"
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
