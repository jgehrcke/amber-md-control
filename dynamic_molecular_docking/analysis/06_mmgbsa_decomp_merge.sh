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

OUT_DIR_MERGED_DATA="${PWD}/mmgbsa_decomp_merged_analysis"
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
OUT_DIR_PER_RUN_DATA="per_run_data"
if [[ ! -d "$OUT_DIR_PER_RUN_DATA" ]]; then
    mkdir "$OUT_DIR_PER_RUN_DATA"
fi

LAST_N=250
PROJECTNAME="mmgbsa_decomp_last${LAST_N}frames"

if [ -r resnum_offset ]; then
    log "Found resnum_offset file."
    RESNUMOFFSET=$(cat resnum_offset)
else
    RESNUMOFFSET="0"
fi

# Analyze FINAL_DECOMP_MMPBSA.dat files as written by MMPBSA.py from AT 13.
# During this analysis, decomp data among all DMD runs are merged.
# This creates various output files in $OUT_DIR_MERGED_DATA.
log "Collecting decomp data files and merging data..."
find "$MD_DIR" -wholename "*/${PROJECTNAME}/FINAL_DECOMP_MMPBSA.dat" | \
    python utils/merge_mmgbsa_decomp_data.py \
        --receptor-resnum-offset "${RESNUMOFFSET}" \
        "${OUT_DIR_MERGED_DATA}/${PROJECTNAME}" \
        "${OUT_DIR_PER_RUN_DATA}/mmpbsa_freemd_last${LAST_N}frames.dat"
exit
