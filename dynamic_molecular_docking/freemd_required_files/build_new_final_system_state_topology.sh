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

# To be executed in free MD directory.

# Set up environment (Amber, Python, ...).
if [ -f "../../../env_setup.sh" ]; then
    source "../../../env_setup.sh"
fi
# Don't exit upon error, exit code interpretation is done below.
#set -e

# 'tleap' might be an alias defined in amber setup script, the alias should be used here.
shopt -s expand_aliases

PRMTOP="top.prmtop"
TRAJFILE="dmd_tmd_NVT.mdcrd"

err() {
    # Print error message to stderr.
    echo "ERROR >>> $@" 1>&2;
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

# Check the distance between receptor and ligand after pulling process.
# Actually, evaluate the minimal distance.
# If the minimal distance is larger than a certain threshold, do not
# prepare this system for free MD (do not run leap).

# Delete output file if existing.
rm -f receptor_ligand_min_distance
# Define maximum allowed distance in Angstrom.
MAXDIST=3
# Extract minimal distance with Python (scipy, Biopython).
python - <<EOF
import sys
import numpy as np
from scipy.spatial import distance
from Bio.PDB.PDBParser import PDBParser # Requires Biopython
p = PDBParser(PERMISSIVE=1)
r = p.get_structure('receptor', 'final_receptor_state.pdb')
l = p.get_structure('ligand', 'final_ligand_state.pdb')
r_atom_coords = [a.get_coord() for a in r.get_atoms()]
l_atom_coords = [a.get_coord() for a in l.get_atoms()]
distancematrix = distance.cdist(r_atom_coords, l_atom_coords, 'euclidean')
min_distance = np.min(distancematrix)
with open('receptor_ligand_min_distance', 'w') as f:
    f.write(str(min_distance))
if min_distance > $MAXDIST:
    sys.exit(20)
sys.exit(0)
EOF
EXITCODE=$?
if [[ ( "${EXITCODE}" == 20 ) || ( "${EXITCODE}" == 0 ) ]]; then
    check_required receptor_ligand_min_distance
    log "Minimal distance between receptor and ligand: $(cat receptor_ligand_min_distance) Angstroms."
fi
if [[ ${EXITCODE} == 20 ]]; then
    err "Distance larger than $MAXDIST Angstroms. Exit."
    exit 1
elif [[ ${EXITCODE} != 0 ]]; then
    err "Distance extraction failed. Exit."
    exit 1
fi


if [ -d ~/leap_search_path ]; then
    print_run_command "tleap -I ~/leap_search_path -f leap.in > leap.stdouterr 2>&1"
else
    print_run_command "tleap -f leap.in > leap.stdouterr 2>&1"
fi

if [ $? != 0 ]; then
    err "tleap failed. Exit."
    exit 1
fi

# A new topology file + coordinate file should be in this directory.
check_required top.prmtop
check_required initcoords.crd
