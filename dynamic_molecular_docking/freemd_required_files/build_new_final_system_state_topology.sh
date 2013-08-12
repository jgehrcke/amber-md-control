#!/bin/bash
# Copyright 2012-2013 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

# To be executed in free MD directory.

# Set up environment (Amber, Python, ...), exit upon error.
if [ -f "../../../env_setup.sh" ]; then
    source "../../../env_setup.sh"
fi
# Now, DMD_CODE_DIR is defined.
source "${DMD_CODE_DIR}/common_code.sh"

# 'tleap' might be an alias defined in amber setup script, the alias should be used here.
shopt -s expand_aliases

PRMTOP="top.prmtop"
TRAJFILE="dmd_tmd_NVT.mdcrd"

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
DISTFILE="receptor_ligand_min_distance_after_tmd"
rm -f $DISTFILE
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
with open('$DISTFILE', 'w') as f:
    f.write(str(min_distance))
if min_distance > $MAXDIST:
    sys.exit(20)
sys.exit(0)
EOF
EXITCODE=$?
if [[ ( "${EXITCODE}" == 20 ) || ( "${EXITCODE}" == 0 ) ]]; then
    check_required $DISTFILE
    log "Minimal distance between receptor and ligand: $(cat $DISTFILE) Angstroms."
fi
if [[ ${EXITCODE} == 20 ]]; then
    err "Distance larger than $MAXDIST Angstroms. Exit (rc 0)."
    exit
elif [[ ${EXITCODE} != 0 ]]; then
    err "Distance extraction failed unexpectedly. Exit."
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
