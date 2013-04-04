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

echo "Execute script for each finished freeMD: ${ABSPATH_TO_SCRIPT}"

./find_unfinished_freemd_trajectories.sh --finished-only | while read FREEMDDIR
do
    cd "$FREEMDDIR"
    echo "Working in $FREEMDDIR (swallowing stdout)..."

    # ERROR >>> 1st arg: Amber topology file.
    # ERROR >>> 2nd arg: NetCDF trajectory file.
    # ERROR >>> 3rd arg: cpptraj frame selection, e.g. '2 2' or 'lastframe'.
    # ERROR >>> 4th arg: ambmask selecting the atoms to strip before writing PDB file.
    # ERROR >>> 5th arg: output PDB filename.

    ${ABSPATH_TO_SCRIPT} top.prmtop after_freemd_min2.rst lastframe ':WAT,Cl-,Na+' freemd_final_system_state_aftermin.pdb 1> /dev/null < /dev/null
    if [ $? -ne 0 ]; then
        echo "Error observed. Abort freeMD dir iteration."
        exit 1
    fi
    cd "$STARTDIR"
done
