#!/usr/bin/env python

import os
import sys
import Bio.PDB
import numpy as np
from string import Template

path_output_restraint_file = 'link_to_each_ligand_dir/dmd_min_heat_equi.rest'
path_restraint_file_tmd_common = 'link_to_each_ligand_dir/dmd_tmd_common.rest'

try:
    path_to_solv_complex_pdb_file = sys.argv[1]
except IndexError:
    print "Required first argument: path to PDB file containing solvated complex as written by leap."


parser = Bio.PDB.PDBParser(PERMISSIVE=True, QUIET=True)
print "Parsing PDB file..."
s = parser.get_structure('system', path_to_solv_complex_pdb_file)

with open('link_to_each_ligand_dir/core_atom_id') as f:
    core_atom_id = int(f.read().strip())
with open('link_to_each_ligand_dir/ligand_center_atom_id') as f:
    ligand_center_atom_id = int(f.read().strip())
print "core atom id: %s" % core_atom_id
print "ligand center atom id: %s" % ligand_center_atom_id

for atom in s.get_atoms():
    if atom.get_serial_number() == ligand_center_atom_id:
        ligand_center_atom = atom
    elif atom.get_serial_number() == core_atom_id:
        core_atom = atom

def print_details(atom):
    print "Atom ", atom.get_name(), "in residue ", atom.get_parent()
    print "Coordinates: ", atom.get_coord()

print
print
print "core atom"
print "========="
print_details(core_atom)
print
print
print "ligand center atom"
print "=================="
print_details(ligand_center_atom)

print
print
distance = np.linalg.norm(core_atom.get_coord()-ligand_center_atom.get_coord())
print "Distance: %s Angstroms" % distance
print
print

# Create distance strings
distance_minus = "%.3f" % (distance-5, )
distance_plus = "%.3f" % (distance+5, )
distance = "%.3f" % distance


if os.path.exists(path_restraint_file_tmd_common):
    print "Reading %s" % path_restraint_file_tmd_common
    with open(path_restraint_file_tmd_common) as f:
        tmd_common_restraints = f.read()
else:
    print "%s does not exist." % path_restraint_file_tmd_common
    tmd_common_restraints = "# Nothing."

restraint_file_template = Template("""
# Distance restraint between ligand center atom and protein core atom.
# Just to keep things "fixed" during min/heat/equi.
&rst
    iat=$core_atom_id, $ligand_center_atom_id,
    r1=$distance_minus, r2=$distance, r3=$distance, r4=$distance_plus, rk2=200, rk3=200
&end

# tMD common restraints, to be applied during min/heat/equi and all tMD simulations.
# (Usually for GAG-internal restraints, such as for keeping IdoA in heparin in one
#  conformation, from dmd_tmd_common.rest)

$tmd_common_restraints

""")

restraint_file_content = restraint_file_template.substitute(
    core_atom_id=core_atom_id,
    ligand_center_atom_id=ligand_center_atom_id,
    distance_minus=distance_minus,
    distance=distance,
    distance_plus=distance_plus,
    tmd_common_restraints=tmd_common_restraints
    )

print "Writing restraint file..."

with open(path_output_restraint_file, 'w') as f:
    f.write(restraint_file_content)


