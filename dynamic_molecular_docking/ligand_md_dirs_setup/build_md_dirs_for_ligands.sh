#!/bin/bash
# Copyright 2011-2013 Jan-Philip Gehrcke
#

err() {
    # Print error message to stderr.
    echo "$@" 1>&2;
    }

source /projects/bioinfp_apps/Python-2.7.3/setup.sh
# os.path.relpath from Python 2.6 might be broken
relpath() {
    # relpath targetdir startdir returns the relative path start->target
    if [ -d "$1" ]; then
        if [ -d "$2" ]; then
            python -c "import os.path; print os.path.relpath('$1','$2')"
            return 0
        fi
    fi
    err "relpath called without both arguments being a directory."
    return 1
    }

SCRIPTNAME="$(basename "$0")"

# check command line arguments
if [[ $# -le 2 ]]; then
    err "Usage:"
    err "$SCRIPTNAME output_dir pdb1 [pdb2] ...."
    exit 1
fi

OUTDIR_ROOT="$1"
if [ ! -d "$OUTDIR_ROOT" ]; then
    err "$OUTDIR_ROOT directory does not exist. Exit."
    exit 1
fi

REQUIRED_FILES_DIR=link_to_each_ligand_dir
if [ ! -d "$REQUIRED_FILES_DIR" ]; then
    err "$REQUIRED_FILES_DIR directory does not exist. Exit."
    exit 1
fi

echo "* MD directory builder started."

# Process all args from the second argument onwards.
for LIGAND_PDB_FILEPATH in "${@:2}"
do

LIGAND_PDB_FILENAME=$LIGAND_PDB_FILEPATH
if [ "$LIGAND_PDB_FILEPATH" != "$(basename ${LIGAND_PDB_FILEPATH})" ]; then
    LIGAND_PDB_FILENAME=$(basename ${LIGAND_PDB_FILEPATH})
fi

# Check for existence of PDB file.
if [ ! -f "${LIGAND_PDB_FILEPATH}" ]; then
    err "Given PDB file does not exist: $LIGAND_PDB_FILEPATH. Skip."
    continue
fi

echo "* Working on PDB file ${LIGAND_PDB_FILEPATH}."

# Split given PDB file name into name, extension.
PDBNAME=${LIGAND_PDB_FILENAME%%.*}
#PDBEXT=$LIGAND_PDB_FILENAME##*.}

# The PDB file name without extension is the name for the project dir.
# The project dir is to be built in the OUTDIR_ROOT.
PROJECTDIR=${OUTDIR_ROOT}/${PDBNAME}

# create project dir
if [ ! -d "$PROJECTDIR" ]; then
    mkdir "$PROJECTDIR"
else
    echo "Project directory ${PROJECTDIR} already exists. Skip."
    continue
fi
echo "  Project directory ${PROJECTDIR} created."

echo "  Copy ligand PDB file into project directory."
cp ${LIGAND_PDB_FILEPATH} ${PROJECTDIR}

echo "  Linking the link-to-each-ligand-dir files into the project directory."
PROJECTDIR_TO_REQFILESDIR_REL=$(relpath ${REQUIRED_FILES_DIR} ${PROJECTDIR})
for F in ${REQUIRED_FILES_DIR}/*
do
    F_BASENAME=$(basename "${F}")
    LINK_TARGET=${PROJECTDIR_TO_REQFILESDIR_REL}/${F_BASENAME}
    LINK_NAME=${PROJECTDIR}/${F_BASENAME}
    ln -s "${LINK_TARGET}" "${LINK_NAME}"
done

LEAPINPUT="
logfile leap.log
source leaprc.GLYCAM_06h
source leaprc.GLYCAM_06h.sergeylibs
source leaprc.ff12SB

# Load prepared receptor and ligand molecules.
r=loadpdb 1BFB_protonly.pdb
charge r

l=loadpdb ${LIGAND_PDB_FILENAME}
charge l

# No disulfide bonds in FGF2

#bond r.9.SG r.34.SG
#bond r.11.SG r.50.SG
#bond r.77.SG r.102.SG
#bond r.79.SG r.118.SG

# Build complex,
c = combine {r l}
charge c

# Save unsolvated complex data (for potential MM-PBSA).
saveamberparm c complex_unsolvated.prmtop complex_unsolvated.crd
savepdb c leap_complex_unsolvated.pdb

# Add ions.
addions c Na+ 0
addions c Cl- 0

# For the short equi+tMD run, make it rectangular. The extended dimension of the
# solute should not rotate out of the box within 4 ns or less.
# Generally, solvateoct is a better choice.
# http://structbio.vanderbilt.edu/archives/amber-archive/2005/2420.php
# http://www.rosswalker.co.uk/tutorials/amber_workshop/Tutorial_one/section2.htm
solvatebox c TIP3PBOX 8


# Save solvated complex data + ligand/receptor for potential (MM-PBSA).
savepdb c leap_complex_solvated.pdb
saveamberparm c top.prmtop initcoords.crd
saveamberparm l ligand.prmtop ligand.crd
savepdb l leap_ligand.pdb
saveamberparm r receptor.prmtop receptor.crd
savepdb r leap_receptor.pdb

# Because we do not like leap, we quit at this point.
quit
"

echo "${LEAPINPUT}" > ${PROJECTDIR}/leap.in

done

echo "* MD directory builder finished."

