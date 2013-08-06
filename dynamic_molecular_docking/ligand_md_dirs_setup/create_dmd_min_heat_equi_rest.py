#!/usr/bin/env python

import sys
import Bio.PDB

path_to_solv_complex_pdb_file = sys.argv[1]

parser = Bio.PDB.PDBParser(PERMISSIVE=1)
s = parser.get_structure('system', path_to_solv_complex_pdb_file)

with open('link_to_each_ligand_dir/core_atom_id') as f:
    core_atom_id = int(f.read().strip())

with open('link_to_each_ligand_dir/ligand_center_atom_id') as f:
    ligand_center_atom_id = int(f.read().strip())

for atom in s.get_atoms():
    if atom.get_serial_number() == ligand_center_atom_id:
        ligand_center_atom = atom
    elif atom.get_serial_number() == ligand_center_atom_id:
        core_atom = atom
        
print ligand_center_atom
print core_atom


