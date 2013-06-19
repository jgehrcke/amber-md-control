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

CRYSTAL_RECEPTOR_PDB="receptor.pdb"

# Collect and rename final tMD states.
TMD_STATES_DIR="tmd_final_states"
rm -rf $TMD_STATES_DIR
mkdir $TMD_STATES_DIR
find $PREFIX -name "tmd_final_system_state.pdb" | utils/collect_pdb_files_with_run_id.py $TMD_STATES_DIR tmd_finalstate.pdb

# Collect and rename final free MD states.
FREEMD_STATES_DIR="freemd_final_states_aftermin"
rm -rf $FREEMD_STATES_DIR
mkdir $FREEMD_STATES_DIR
find $PREFIX -name "freemd_final_system_state_aftermin.pdb" | utils/collect_pdb_files_with_run_id.py $FREEMD_STATES_DIR freemd_finalstate_aftermin.pdb

foreachpdb_align_receptor() {
    PDBDIR="${1}"
    ALIGNEDDIR="${PDBDIR}_recaligned"
    rm -rf $ALIGNEDDIR
    mkdir $ALIGNEDDIR
    mkdir $ALIGNEDDIR/outerr
    for PDB in ${PDBDIR}/*.pdb; do
        [ -e "$PDB" ] || break # Credit: bash pitfalls.
        filename=$(basename "$PDB")
        extension="${filename##*.}"
        filenamewoext="${filename%.*}"
        outerr="${ALIGNEDDIR}/outerr/${filenamewoext}.outerr"
        alignedpdb="${ALIGNEDDIR}/${filenamewoext}_aligned.pdb"
        log "Attempt to create ${alignedpdb}"
        utils/align_final_state_to_crystal.sh ${CRYSTAL_RECEPTOR_PDB} ${PDB} ${alignedpdb} > ${outerr} 2>&1 &
    done
    log "Waiting for PyMOL processes to finish..."
    wait
    log "Finished."
    }

foreachpdb_extract_ligand() {
    PDBDIR="${1}"
    LIGANDDIR="${PDBDIR}_ligandonly"
    rm -rf $LIGANDDIR
    mkdir $LIGANDDIR
    mkdir $LIGANDDIR/outerr
    for PDB in ${PDBDIR}/*.pdb; do
        [ -e "$PDB" ] || break # Credit: bash pitfalls.
        filename=$(basename "$PDB")
        extension="${filename##*.}"
        filenamewoext="${filename%.*}"
        outerr="${LIGANDDIR}/outerr/${filenamewoext}.outerr"
        ligandpdb="${LIGANDDIR}/${filenamewoext}_ligand.pdb"
        log "attempt to create ${ligandpdb}"
        utils/extract_ligand_from_pdb.sh ${PDB} ${ligandpdb} > ${outerr} 2>&1 &
    done
    log "Waiting for PyMOL processes to finish..."
    wait
    log "Finished."
    }

foreachpdb_align_receptor ${TMD_STATES_DIR}
foreachpdb_extract_ligand ${TMD_STATES_DIR}_recaligned
foreachpdb_align_receptor ${FREEMD_STATES_DIR}
foreachpdb_extract_ligand ${FREEMD_STATES_DIR}_recaligned
