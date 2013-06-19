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
OUT_DIR_PER_RUN_DATA="per_run_data"
if [[ ! -d "$OUT_DIR_PER_RUN_DATA" ]]; then
    mkdir "$OUT_DIR_PER_RUN_DATA"
fi

LAST_N=250
OUTFILE="${OUT_DIR_PER_RUN_DATA}/mmpbsa_freemd_last${LAST_N}frames.dat"
log "Creating $OUTFILE ..."
# Write column headers to output file (overwrite existing file)
echo "run_id,mmpbsa_freemdlast${LAST_N}frames_deltag,mmpbsa_freemdlast${LAST_N}frames_deltag_stddev,mmpbsa_freemdlast${LAST_N}frames_deltaeel,mmpbsa_freemdlast${LAST_N}frames_deltaeel_stddev" > $OUTFILE
find ${MD_DIR} -wholename "*tmd_*/freemd/mmpbsa_last${LAST_N}frames/FINAL_RESULTS_MMPBSA.dat" | \
while read FILE
do
    log "Processing file '$FILE' ..."
    RUNID=$(echo "$FILE" | utils/collect_pdb_files_with_run_id.py --print-run-ids)
    # The code below has been validated to work with the output of MMPBSA.py
    # of AmberTools 13, patched version June 19, 2013
    DELTAG=$(cat $FILE | grep "DELTA TOTAL" | awk '{print $3}')
    DELTAG_STDDEV=$(cat $FILE | grep "DELTA TOTAL" | awk '{print $4}')
    EEL=$(cat $FILE | tail -n20 | head -n6 | grep EEL | awk '{print $2}')
    EEL_STDDEV=$(cat $FILE | tail -n20 | head -n6 | grep EEL | awk '{print $3}')
    # Append to file.
    echo "${RUNID},${DELTAG},${DELTAG_STDDEV},${EEL},${EEL_STDDEV}" >> $OUTFILE
done

exit
