#!/bin/bash
# Copyright 2012-2013 Jan-Philip Gehrcke, http://gehrcke.de

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

check_required ligand_residues
check_reuqired receptor_residues
LIGAND_RESIDUES=$(cat ligand_residues)
RECEPTOR_RESIDUES=$(cat receptor_residues)

# Extract mmpbsa_200ps_after_freemd score
OUTFILE="lig_rec_mindistance_after_freemd.dat"
log "Creating $OUTFILE ..."
# Overwrite file
echo "run_id,lig_rec_mindistance_after_freemd" > $OUTFILE
find ${PREFIX} -wholename "*tmd_*/freemd/freemd_final_system_state_aftermin.pdb" | \
while read FILE
do
    log "Processing file '$FILE' ..."
    RUNID=$(echo "$FILE" | utils/collect_pdb_files_with_run_id.py --print-run-ids)
    python - <<EOF
    import sys
    import numpy as np
    from scipy.spatial import distance
    from Bio.PDB.PDBParser import PDBParser # Requires Biopython

    p = PDBParser(PERMISSIVE=1)
    s = p.get_structure('system', 'freemd_final_system_state_aftermin.pdb')
    system_chain = s[0][0] # structure, model 0, chain 0
    ligand_res_start, ligand_res_end = '${LIGAND_RESIDUES}'.split('-')
    ligand_res_start -= 1
    receptor_res_start, receptor_res_end = '${LIGAND_RESIDUES}'.split('-')
    receptor_res_start -= 1
    ligand_residues = system_chain[ligand_res_start:ligand_res_end]
    receptor_residues = system_chain[receptor_res_start:receptor_res_end]

    sys.exit(0)

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
    # Append to file.
    echo "${RUNID},${MINDISTANCE}" >> $OUTFILE
    exit 1
done




