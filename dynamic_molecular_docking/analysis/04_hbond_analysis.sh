#!/bin/bash
#
#   Copyright (C) 2012-2013 Jan-Philip Gehrcke
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

set -eu

err() {
    # Print error message to stderr.
    echo "ERROR >>> $@" 1>&2
    }

log() {
    # Print message to stdout.
    echo "INFO  >>> $@"
    }

MD_PREFIX="../06_md"

OUT_DIR_TOP="hbond_analysis"
rm -rf "$OUT_DIR_TOP"
mkdir "$OUT_DIR_TOP"


# Analyze cpptraj's AVGOUT files.
find "$MD_PREFIX" -name "hbonds_rec_lig_average_last_250.dat" | python analyze_hbond_avgout.py "${OUT_DIR_TOP}/freemd_last_250_frames"


# Extract H-bond data (only count H-bonds with receptor being H-bond donor)
OUTFILE="hbonds_freemd_avg_number_last250frames.dat"
log "Creating $OUTFILE ..."
# Overwrite file
echo "run_id,hbonds_freemd_avg_number_last250frames_mean,hbonds_freemd_avg_number_last250frames_stddev" > "$OUTFILE"
find "${MD_PREFIX}" -wholename "*tmd_*/freemd/hbonds_out_last_250.dat" | \
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


OUTFILE="hbonds_freemd_avg_number_entiretraj.dat"
log "Creating $OUTFILE ..."
# Overwrite file
echo "run_id,hbonds_freemd_avg_number_entiretraj_mean,hbonds_freemd_avg_number_entiretraj_stddev" > "$OUTFILE"
find "${MD_PREFIX}" -wholename "*tmd_*/freemd/hbonds_out_last_250.dat" | \
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
