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

# Run the functions below asynchronously.

mov_freemd_lastNframes_ligrecrelmov() {
    LAST_N=$1
    PROJECT="mov_freemd_last${LAST_N}frames_ligrecrelmov"
    OUTFILE="${PROJECT}.dat"
    log "Working on project ${PROJECT} ..."
    # Overwrite file
    echo "run_id,${PROJECT}_mean,${PROJECT}_stddev" > $OUTFILE
    find ${MD_DIR} -wholename "*tmd_*/freemd/rmsd_ligand_relative_over_frames_last${LAST_N}frames.dat" | \
    while read FILE
    do
        log "Processing file '$FILE' ..."
        RUNID=$(echo "$FILE" | utils/collect_pdb_files_with_run_id.py --print-run-ids)
        MEAN=$(cat $FILE | tail -n+2 | awk '{print $2}' | mean_stddev --mean)
        STDDEV=$(cat $FILE | tail -n+2 | awk '{print $2}' | mean_stddev --stddev)
        wait
        # Append to file.
        echo "${RUNID},${MEAN},${STDDEV}" >> $OUTFILE
    done
    log "${PROJECT} done."
    }
mov_freemd_lastNframes_ligrecrelmov 250 &

mov_freemd_entire_ligrecrelmov() {
    PROJECT="mov_freemd_entire_ligrecrelmov"
    OUTFILE="${PROJECT}.dat"
    log "Working on project ${PROJECT} ..."
    # Overwrite file
    echo "run_id,${PROJECT}_mean,${PROJECT}_stddev" > $OUTFILE
    find ${MD_DIR} -wholename "*tmd_*/freemd/rmsd_ligand_relative_over_frames_entiretraj.dat" | \
    while read FILE
    do
        log "Processing file '$FILE' ..."
        RUNID=$(echo "$FILE" | utils/collect_pdb_files_with_run_id.py --print-run-ids)
        MEAN=$(cat $FILE | tail -n+2 | awk '{print $2}' | mean_stddev --mean)
        STDDEV=$(cat $FILE | tail -n+2 | awk '{print $2}' | mean_stddev --stddev)
        # Append to file.
        echo "${RUNID},${MEAN},${STDDEV}" >> $OUTFILE
    done
    log "${PROJECT} done."
    }
mov_freemd_entire_ligrecrelmov &


mov_freemd_lastNframes_liginternal() {
    LAST_N=$1
    PROJECT="mov_freemd_last${LAST_N}frames_liginternal"
    OUTFILE="${PROJECT}.dat"
    log "Working on project ${PROJECT} ..."
    # Overwrite file
    echo "run_id,${PROJECT}_mean,${PROJECT}_stddev" > $OUTFILE
    find ${MD_DIR} -wholename "*tmd_*/freemd/rmsd_ligand_internal_over_frames_last${LAST_N}frames.dat" | \
    while read FILE
    do
        log "Processing file '$FILE' ..."
        RUNID=$(echo "$FILE" | utils/collect_pdb_files_with_run_id.py --print-run-ids)
        MEAN=$(cat $FILE | tail -n+2 | awk '{print $2}' | mean_stddev --mean)
        STDDEV=$(cat $FILE | tail -n+2 | awk '{print $2}' | mean_stddev --stddev)
        # Append to file.
        echo "${RUNID},${MEAN},${STDDEV}" >> $OUTFILE
    done
    log "${PROJECT} done."
    }
mov_freemd_lastNframes_liginternal 250 &


mov_freemd_entire_liginternal() {
    PROJECT="mov_freemd_entire_liginternal"
    OUTFILE="${PROJECT}.dat"
    log "Working on project ${PROJECT} ..."
    # Overwrite file
    echo "run_id,${PROJECT}_mean,${PROJECT}_stddev" > $OUTFILE
    find ${MD_DIR} -wholename "*tmd_*/freemd/rmsd_ligand_internal_over_frames_entiretraj.dat" | \
    while read FILE
    do
        log "Processing file '$FILE' ..."
        RUNID=$(echo "$FILE" | utils/collect_pdb_files_with_run_id.py --print-run-ids)
        MEAN=$(cat $FILE | tail -n+2 | awk '{print $2}' | mean_stddev --mean)
        STDDEV=$(cat $FILE | tail -n+2 | awk '{print $2}' | mean_stddev --stddev)
        # Append to file.
        echo "${RUNID},${MEAN},${STDDEV}" >> $OUTFILE
    done
    log "${PROJECT} done."
    }

mov_freemd_entire_liginternal &

# Wait for background processes to finish.
wait
