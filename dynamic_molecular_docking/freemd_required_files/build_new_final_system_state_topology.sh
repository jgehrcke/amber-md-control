#!/bin/bash
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

# Set up environment for Amber.
AMBER_SETUP="/projects/bioinfp_apps/amber12_centos58_intel1213_openmpi16_cuda5/setup.sh"
MODULE_TEST_OUTPUT=$(command -v module) # valid on ZIH
if [ $? -eq 0 ]; then
    echo "Try loading ZIH module amber/12"
    module load amber/12
else
    echo "Sourcing $AMBER_SETUP"
    source "${AMBER_SETUP}"
fi

# exit upon error
set -e

PRMTOP="top.prmtop"
TRAJFILE="dmd_tmd_NVT.mdcrd"

err() {
    # Print error message to stderr.
    echo "$@" 1>&2;
    }

log() {
    # Print message to stdout.
    echo "INFO  >>> $@"
    }

check_delete () {
    # Delete file if existing.
    if [ -f "${1}" ]; then
        echo "Deleting ${1} ..."
        rm -f "${1}"
    fi
    }

check_required () {
    # Check if file is available, exit if not.
    if [ ! -f "${1}" ]; then
       err "File ${1} is required and does not exist. Exit."
       exit 1
    fi
    }

print_run_command () {
    echo "Running command:"
    echo "${1}"
    eval "${1}"
    }

# To be executed in freemd dir.
# One up is tMD dir. Two up is equi MD dir. Three up is main MD dir.

check_required "leap.in"
check_required "../${TRAJFILE}"
check_required "../${PRMTOP}"
check_required receptor_residues
check_required ligand_residues

RECEPTOR_RESIDUES=$(cat receptor_residues)
LIGAND_RESIDUES=$(cat ligand_residues)


log "Extracting receptor PDB from final state."
print_run_command "../../../trajframe_to_pdb_using_stripmask.sh ../${PRMTOP} ../${TRAJFILE} lastframe '!:${RECEPTOR_RESIDUES}' final_receptor_state.pdb"
log "Extracting ligand PDB from final state."
print_run_command "../../../trajframe_to_pdb_using_stripmask.sh ../${PRMTOP} ../${TRAJFILE} lastframe '!:${LIGAND_RESIDUES}' final_ligand_state.pdb"

print_run_command "tleap -I ~/leap_search_path -f leap.in > leap.stdouterr 2>&1"

if [ $? != 0 ]; then
    err "tleap failed. Exit."
    exit 1
fi

# A new topology file + coordinate file should be in this directory.
check_required top.prmtop
check_required initcoords.crd
