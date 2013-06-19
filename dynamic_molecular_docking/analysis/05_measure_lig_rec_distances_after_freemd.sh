#!/bin/bash
# Copyright 2012-2013 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

MD_DIR="../06_md"
# Set up environment (Amber, Python, ...), exit upon error.
if [ -f "${MD_DIR}/env_setup.sh" ]; then
    source "${MD_DIR}/env_setup.sh"
else
    echo "file missing: ${MD_DIR}/env_setup.sh"
    exit 1
fi
# Now, DMD_CODE_DIR is defined.
source "${DMD_CODE_DIR}/common_code.sh"
set -e

check_required "${MD_DIR}/ligand_residues"
check_required "${MD_DIR}/receptor_residues"
LIGAND_RESIDUES=$(cat "${MD_DIR}/ligand_residues")
RECEPTOR_RESIDUES=$(cat "${MD_DIR}/receptor_residues")
STARTDIR=$(pwd)

# Define filename for data file to be created in analysis directory.
OUTFILE="lig_rec_distances_after_freemd.dat"

# Define filename for data file to be created in every single free MD dir,
# containing only the numerical value of the minimal distance in Angstrom.
MINDISTFILE="receptor_ligand_min_distance_after_freemd_min"
AVGDISTFILE="receptor_ligand_avg_distance_after_freemd_min"
log "Creating $OUTFILE ..."
# Overwrite file
echo "run_id,lig_rec_min_distance_after_freemd_min,lig_rec_avg_distance_after_freemd_min" > $OUTFILE
find ${MD_DIR} -wholename "*tmd_*/freemd/freemd_final_system_state_aftermin.pdb" | \
while read FILE
do
    log "Processing file '$FILE' ..."
    RUNID=$(echo "$FILE" | utils/collect_pdb_files_with_run_id.py --print-run-ids)
    DIR=$(dirname "$FILE")
    cd "$DIR"
    python - <<EOF
import sys
import numpy as np
from scipy.spatial import distance
from Bio.PDB.PDBParser import PDBParser # Requires Biopython

p = PDBParser(PERMISSIVE=1)
s = p.get_structure('system', 'freemd_final_system_state_aftermin.pdb')

# Get first chain in structure which is a priori known to contain the system.
system_chain = list(s.get_chains())[0]

# Get residue start/end numbers from environment.
ligand_res_start, ligand_res_end = map(int, '${LIGAND_RESIDUES}'.split('-'))
receptor_res_start, receptor_res_end = map(int, '${RECEPTOR_RESIDUES}'.split('-'))

# Create collections of residue objects, one for receptor, one for ligand.
ligand_res_numbers = xrange(ligand_res_start, ligand_res_end+1)
receptor_res_numbers = xrange(receptor_res_start, receptor_res_end+1)
ligand_residues = [system_chain[x] for x in ligand_res_numbers]
receptor_residues = [system_chain[x] for x in receptor_res_numbers]

# Create collections of atom objects, one for receptor, one for ligand.
r_atoms_coords = [a.get_coord() for r in receptor_residues for a in r]
l_atoms_coords = [a.get_coord() for l in ligand_residues for a in l]

# Calculate all pairwise distances between both sets of atoms.
distancematrix = distance.cdist(r_atoms_coords, l_atoms_coords, 'euclidean')

# Retrieve distance between ligand and receptor: use minimal distance between
# any ligand atom and any receptor atom.
min_distance = np.min(distancematrix)
with open('$MINDISTFILE', 'w') as f:
    f.write(str(min_distance))

# Retrieve distance between ligand and receptor: averaged over all ligand
# atoms, whereas for each ligand atom the minimal distance to the receptor
# is determined.
# In the distance matrix, each column contains distances for one
# ligand atom to all receptor atoms. np.min(A, axis=0) determines the
# minum value for each column, resulting in a one-dimensional array.
# Ref: SciPy docs: scipy/reference/generated/scipy.spatial.distance.cdist.html
#      "For each i and j, the metric dist(u=XA[i], v=XB[j])
#       is computed and stored in the ij th entry"
avg_distance = np.mean(np.min(distancematrix, axis=0))
with open('$AVGDISTFILE', 'w') as f:
    f.write(str(avg_distance))
EOF
    if [ $? -ne 0 ]; then
        err "Distance extraction failed unexpectedly. Exit."
        exit 1
    fi
    MINDISTANCE=$(cat "$MINDISTFILE")
    AVGDISTANCE=$(cat "$AVGDISTFILE")
    log "minimal distance: $MINDISTANCE Angstroms."
    log "average distance: $AVGDISTANCE Angstroms."
    cd "$STARTDIR"
    # Append data to output file.
    echo "${RUNID},${MINDISTANCE},${AVGDISTANCE}" >> $OUTFILE
done
