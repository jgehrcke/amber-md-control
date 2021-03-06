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

OUT_DIR_MERGED_DATA="${PWD}/hbond_analysis"
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

if [ -r "resnum_offset" ]; then
    log "Found resnum_offset file."
    RESNUMOFFSET=$(cat resnum_offset)
else
    RESNUMOFFSET="0"
fi

# Analyze cpptraj's hbond AVGOUT files.
# During this analysis, hbond data among all DMD runs are merged.
# This creates various output files in $OUT_DIR_MERGED_DATA.
log "Collecting cpptraj's AVGOUT files and merging data..."
find "$MD_DIR" -name "hbonds_rec_lig_average_last_${LAST_N}.dat" | \
    python utils/analyze_hbond_avgout.py \
    --receptor-resnum-offset "${RESNUMOFFSET}" \
    "${OUT_DIR_MERGED_DATA}/freemd_last${LAST_N}frames"

# Analyze cpptraj's hbond OUT files.
# Creates measures for each DMD run.
# For each free MD simulation, the H-bond count with receptor being H-bond donor
# is averaged over the last N frames of the simulation.
analyze_last_n_frames() {
    OUTFILE="${OUT_DIR_PER_RUN_DATA}/hbonds_freemd_avg_number_last${LAST_N}frames.dat"
    log "Creating $OUTFILE ..."
    # Overwrite file
    echo "run_id,hbonds_freemd_avg_number_last250frames_mean,hbonds_freemd_avg_number_last250frames_stddev" > "$OUTFILE"
    find "${MD_DIR}" -wholename "*tmd_*/freemd/hbonds_out_last_250.dat" | \
    while read FILE
    do
        log "Processing file '$FILE' ..."
        RUNID=$(echo "$FILE" | utils/collect_pdb_files_with_run_id.py --print-run-ids)
        MEAN_STDDEV_DATASTRING=$(tail -n +2 "$FILE" | mean_stddev --formatted)
        MEAN=$(echo $MEAN_STDDEV_DATASTRING | awk '{print $3}')
        STDDEV=$(echo $MEAN_STDDEV_DATASTRING | awk '{print $4}')
        # Append to file.
        echo "${RUNID},${MEAN},${STDDEV}" >> $OUTFILE
    done
    }
analyze_last_n_frames &

analyze_entire_trajectory() {
    OUTFILE="${OUT_DIR_PER_RUN_DATA}/hbonds_freemd_avg_number_entiretraj.dat"
    log "Creating $OUTFILE ..."
    # Overwrite file
    echo "run_id,hbonds_freemd_avg_number_entiretraj_mean,hbonds_freemd_avg_number_entiretraj_stddev" > "$OUTFILE"
    find "${MD_DIR}" -wholename "*tmd_*/freemd/hbonds_out_entire.dat" | \
    while read FILE
    do
        log "Processing file '$FILE' ..."
        RUNID=$(echo "$FILE" | utils/collect_pdb_files_with_run_id.py --print-run-ids)
        MEAN_STDDEV_DATASTRING=$(tail -n +2 "$FILE" | mean_stddev --formatted)
        MEAN=$(echo $MEAN_STDDEV_DATASTRING | awk '{print $3}')
        STDDEV=$(echo $MEAN_STDDEV_DATASTRING | awk '{print $4}')
        # Append to file.
        echo "${RUNID},${MEAN},${STDDEV}" >> $OUTFILE
    done
    }
analyze_entire_trajectory &

wait
