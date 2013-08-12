#!/bin/bash
# Copyright 2012-2013 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

MD_DIR="../06_md"
# Set up environment (Amber, Python, ...), exit upon error.
if [[ -f "${MD_DIR}/env_setup.sh" ]]; then
    source "${MD_DIR}/env_setup.sh"
else
    echo "file missing: ${MD_DIR}/env_setup.sh"
    exit 1
fi
# Now, DMD_CODE_DIR is defined.
source "${DMD_CODE_DIR}/common_code.sh"
set -e

OUT_DIR_MERGED_DATA="${PWD}/dihedral_merged_analysis"
if [[ -d "$OUT_DIR_MERGED_DATA" ]]; then
    rm -rf "$OUT_DIR_MERGED_DATA"
    mkdir "$OUT_DIR_MERGED_DATA"
    echo "Output directory $OUT_DIR_MERGED_DATA removed and re-created."
elif [[ -f "$OUT_DIR_MERGED_DATA" ]]; then
    err "$OUT_DIR_MERGED_DATA unexpectedly exists as a file. Exit."
    exit 1
else
    mkdir "$OUT_DIR_MERGED_DATA"
    echo "Output directory $OUT_DIR_MERGED_DATA created."
fi

# Analyze cpptraj's dihedral data files. For each free MD within one DMD run,
# (currently) two data files are available: one for the entire trajectory and
# one for the last N frames. Each file contains one column per specific
# dihedral. The goal is to merge all data for one specific dihedral, i.e.
# append all columns and evaluate the merged data in histogram-fasion.
# During this analysis, hbond data among all DMD runs are merged.
# This creates various output files in $OUT_DIR_MERGED_DATA.

# These files are currently available in each free MD dir:
# DIHEDRALOUT_ENTIRE="dihedrals_over_frames_entiretraj.dat"
# DIHEDRALOUT_LAST="dihedrals_over_frames_last${LAST_N}frames.dat"

LAST_N=250
log "Collecting cpptraj's dihedral data files for the ${LAST_N} free MD frames and merging data..."
find "$MD_DIR" -name "dihedrals_over_frames_last${LAST_N}frames.dat" | \
    python utils/merge_dihedral_data.py "${OUT_DIR_MERGED_DATA}/freemd_last${LAST_N}frames"

log "Collecting cpptraj's dihedral data files for the entire free MD trajectories and merging data..."
log "Collecting cpptraj's dihedral data files and merging data..."
find "$MD_DIR" -name "dihedrals_over_frames_entiretraj.dat" | \
    python utils/merge_dihedral_data.py "${OUT_DIR_MERGED_DATA}/freemd_entiretraj"

# The merging could be done in a more sophisticated fashion, e.g. merge only
# data of those trajectories that end up with a strong binding as measured
# via e.g. MM-PBSA.
