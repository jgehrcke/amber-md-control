#!/bin/bash
#
#   Copyright (C) 2012 Jan-Philip Gehrcke
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#

err() {
    # Print error message to stderr.
    echo "ERROR >>> $@" 1>&2
    }

log() {
    # Print message to stdout.
    echo "INFO  >>> $@"
    }

PREFIX="/home/bioinfp/jang/project/md/smd/docking/1bfb/md/atlas_state_120903"

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


# Extract mmpbsa_200ps_after_freemd score
OUTFILE="mmpbsa_200ps_after_freemd_all_ligands.dat"
log "Creating $OUTFILE ..."
# Overwrite file
echo "run_id,mmpbsa_200ps_after_freemd_deltag,mmpbsa_200ps_after_freemd_deltag_stddev,mmpbsa_200ps_after_freemd_deltaeel,mmpbsa_200ps_after_freemd_deltaeel_stddev" > $OUTFILE
find ${PREFIX} -wholename "*SMD_PROD_*/free_md/mmpbsa_last100fr_with2ps_interval/FINAL_RESULTS_MMPBSA.dat" | \
while read FILE
do
    RUNID=$(../scripts/run_id_from_path.py $FILE)
    DELTAG=$(cat $FILE | grep "DELTA G binding" | awk '{print $5}')
    DELTAG_STDDEV=$(cat $FILE | grep "DELTA G binding" | awk '{print $7}')
    EEL=$(cat $FILE | tail -n20 | head -n6 | grep EEL | awk '{print $2}')
    EEL_STDDEV=$(cat $FILE | tail -n20 | head -n6 | grep EEL | awk '{print $3}')
    # Append to file.
    echo "${RUNID},${DELTAG},${DELTAG_STDDEV},${EEL},${EEL_STDDEV}" >> $OUTFILE
done







