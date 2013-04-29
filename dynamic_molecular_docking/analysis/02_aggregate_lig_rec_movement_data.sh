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

err() {
    # Print error message to stderr.
    echo "ERROR >>> $@" 1>&2
    }

log() {
    # Print message to stdout.
    echo "INFO  >>> $@"
    }


PREFIX="/home/bioinfp/jang/project/md/smd/docking/1bfb/md/atlas_state_120903"


# Run the functions below asynchronously

mov_freemd_last200ps_ligrecrelmov() {
    PROJECT="mov_freemd_last200ps_ligrecrelmov"
    OUTFILE="${PROJECT}.dat"
    log "Processing ${PROJECT} ..."
    # Overwrite file
    echo "run_id,${PROJECT}_mean,${PROJECT}_stddev" > $OUTFILE
    find ${PREFIX} -wholename "*SMD_PROD_*/free_md/rmsd_ligand_relative_over_frames_last200ps.dat" | \
    while read FILE
    do
        RUNID=$(../scripts/run_id_from_path.py $FILE &)
        MEAN=$(cat $FILE | tail -n+2 | awk '{print $2}' | mean_stddev --mean &)
        STDDEV=$(cat $FILE | tail -n+2 | awk '{print $2}' | mean_stddev --stddev &)
        wait
        # Append to file.
        echo "${RUNID},${MEAN},${STDDEV}" >> $OUTFILE
    done
    log "${PROJECT} done."
    }
mov_freemd_last200ps_ligrecrelmov &


mov_freemd_entire_ligrecrelmov() {
    PROJECT="mov_freemd_entire_ligrecrelmov"
    OUTFILE="${PROJECT}.dat"
    log "Processing ${PROJECT} ..."
    # Overwrite file
    echo "run_id,${PROJECT}_mean,${PROJECT}_stddev" > $OUTFILE
    find ${PREFIX} -wholename "*SMD_PROD_*/free_md/rmsd_ligand_relative_over_frames_entiretraj.dat" | \
    while read FILE
    do
        RUNID=$(../scripts/run_id_from_path.py $FILE)
        MEAN=$(cat $FILE | tail -n+2 | awk '{print $2}' | mean_stddev --mean)
        STDDEV=$(cat $FILE | tail -n+2 | awk '{print $2}' | mean_stddev --stddev)
        # Append to file.
        echo "${RUNID},${MEAN},${STDDEV}" >> $OUTFILE
    done
    log "${PROJECT} done."
    }
mov_freemd_entire_ligrecrelmov &


mov_freemd_last200ps_liginternal() {
    PROJECT="mov_freemd_last200ps_liginternal"
    OUTFILE="${PROJECT}.dat"
    log "Processing ${PROJECT} ..."
    # Overwrite file
    echo "run_id,${PROJECT}_mean,${PROJECT}_stddev" > $OUTFILE
    find ${PREFIX} -wholename "*SMD_PROD_*/free_md/rmsd_ligand_internal_over_frames_last200ps.dat" | \
    while read FILE
    do
        RUNID=$(../scripts/run_id_from_path.py $FILE)
        MEAN=$(cat $FILE | tail -n+2 | awk '{print $2}' | mean_stddev --mean)
        STDDEV=$(cat $FILE | tail -n+2 | awk '{print $2}' | mean_stddev --stddev)
        # Append to file.
        echo "${RUNID},${MEAN},${STDDEV}" >> $OUTFILE
    done
    log "${PROJECT} done."
    }
mov_freemd_last200ps_liginternal &


mov_freemd_entire_liginternal() {
    PROJECT="mov_freemd_entire_liginternal"
    OUTFILE="${PROJECT}.dat"
    log "Processing ${PROJECT} ..."
    # Overwrite file
    echo "run_id,${PROJECT}_mean,${PROJECT}_stddev" > $OUTFILE
    find ${PREFIX} -wholename "*SMD_PROD_*/free_md/rmsd_ligand_internal_over_frames_entiretraj.dat" | \
    while read FILE
    do
        RUNID=$(../scripts/run_id_from_path.py $FILE)
        MEAN=$(cat $FILE | tail -n+2 | awk '{print $2}' | mean_stddev --mean)
        STDDEV=$(cat $FILE | tail -n+2 | awk '{print $2}' | mean_stddev --stddev)
        # Append to file.
        echo "${RUNID},${MEAN},${STDDEV}" >> $OUTFILE
    done
    log "${PROJECT} done."
    }
mov_freemd_entire_liginternal &


mov_smd_entire_ligrecrelmov() {
    PROJECT="mov_smd_entire_ligrecrelmov"
    OUTFILE="${PROJECT}.dat"
    log "Processing ${PROJECT} ..."
    # Overwrite file
    echo "run_id,${PROJECT}_mean,${PROJECT}_stddev" > $OUTFILE
    find ${PREFIX} -regextype posix-extended -regex ".*SMD_PROD_.*[[:digit:]]\/rmsd_ligand_relative_over_frames_entiretraj.dat" | \
    while read FILE
    do
        RUNID=$(../scripts/run_id_from_path.py $FILE)
        MEAN=$(cat $FILE | tail -n+2 | awk '{print $2}' | mean_stddev --mean)
        STDDEV=$(cat $FILE | tail -n+2 | awk '{print $2}' | mean_stddev --stddev)
        # Append to file.
        echo "${RUNID},${MEAN},${STDDEV}" >> $OUTFILE
    done
    log "${PROJECT} done."
    }
mov_smd_entire_ligrecrelmov &


mov_smd_entire_liginternal() {
    PROJECT="mov_smd_entire_liginternal"
    OUTFILE="${PROJECT}.dat"
    log "Processing ${PROJECT} ..."
    # Overwrite file
    echo "run_id,${PROJECT}_mean,${PROJECT}_stddev" > $OUTFILE
    find ${PREFIX} -regextype posix-extended -regex ".*SMD_PROD_.*[[:digit:]]\/rmsd_ligand_internal_over_frames_entiretraj.dat" | \
    while read FILE
    do
        RUNID=$(../scripts/run_id_from_path.py $FILE)
        MEAN=$(cat $FILE | tail -n+2 | awk '{print $2}' | mean_stddev --mean)
        STDDEV=$(cat $FILE | tail -n+2 | awk '{print $2}' | mean_stddev --stddev)
        # Append to file.
        echo "${RUNID},${MEAN},${STDDEV}" >> $OUTFILE
    done
    log "${PROJECT} done."
    }
mov_smd_entire_liginternal &

# Wait for background processes to finish.
wait
