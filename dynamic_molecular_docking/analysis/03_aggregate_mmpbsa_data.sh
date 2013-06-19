#!/bin/bash
# Copyright 2012-2013 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de#

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


# Extract mmpbsa_200ps_after_freemd score
OUTFILE="mmpbsa_freemd_last100frames_all_ligands.dat"
log "Creating $OUTFILE ..."
# Overwrite file
echo "run_id,mmpbsa_freemdlast100frames_deltag,mmpbsa_freemdlast100frames_deltag_stddev,mmpbsa_freemdlast100frames_deltaeel,mmpbsa_freemdlast100frames_deltaeel_stddev" > $OUTFILE
find ${PREFIX} -wholename "*tmd_*/freemd/mmpbsa_last100frames/FINAL_RESULTS_MMPBSA.dat" | \
while read FILE
do
    log "Processing file '$FILE' ..."
    RUNID=$(echo "$FILE" | utils/collect_pdb_files_with_run_id.py --print-run-ids)
    DELTAG=$(cat $FILE | grep "DELTA TOTAL" | awk '{print $3}')
    DELTAG_STDDEV=$(cat $FILE | grep "DELTA TOTAL" | awk '{print $4}')
    EEL=$(cat $FILE | tail -n20 | head -n6 | grep EEL | awk '{print $2}')
    EEL_STDDEV=$(cat $FILE | tail -n20 | head -n6 | grep EEL | awk '{print $3}')
    # Append to file.
    echo "${RUNID},${DELTAG},${DELTAG_STDDEV},${EEL},${EEL_STDDEV}" >> $OUTFILE
done

exit

# Extract mmpbsa_after_smd score
OUTFILE="mmpbsa_after_smd_all_ligands.dat"
log "Creating $OUTFILE ..."
# Overwrite file
echo "run_id,mmpbsa_after_smd_deltag,mmpbsa_after_smd_deltaeel" > $OUTFILE
find ${PREFIX} -regextype posix-extended -regex ".*SMD_PROD_.*[[:digit:]]\/mmpbsa_lastframe/FINAL_RESULTS_MMPBSA.dat" | \
while read FILE
do
    RUNID=$(../scripts/run_id_from_path.py $FILE)
    DELTAG=$(cat $FILE | grep "DELTA G binding" | awk '{print $5}')
    EEL=$(cat $FILE | tail -n20 | head -n6 | grep EEL | awk '{print $2}')
    # Append to file.
    echo "${RUNID},${DELTAG},${EEL}" >> $OUTFILE
done







