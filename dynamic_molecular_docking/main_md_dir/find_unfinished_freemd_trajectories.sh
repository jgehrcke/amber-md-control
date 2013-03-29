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


if [[ "$1" == "--finished-only" ]];then
    FINISHEDONLY=true
else
    FINISHEDONLY=false
fi

err() {
    # Print error message to stderr.
    echo "ERROR >>> $@" 1>&2
    }

log() {
    if $FINISHEDONLY ; then
        return
    fi
    # Print message to stdout.
    echo "INFO  >>> $@"
    }

PRMTOP="top.prmtop"
FREEMDOUTFILE="production_NVT.out"
TRAJFILE="production_NVT.mdcrd"
FREEMDDIR="freemd"


for LIGDIR in ligand_*; do
    if [ -d "$LIGIDR" ]; then
        cd ${LIGDIR}
    else
        continue
    fi
    for TMDDIR in tmd_*; do
        if [ -d ${TMDDIR} ]; then
            cd ${TMDDIR}
        else
            continue
        fi
        if [ -d "$FREEMDDIR" ]; then
            cd "$FREEMDDIR"
        else
            log "Dir '$FREEMDDIR' not in '${LIGDIR}/${TMDDIR}'"
            continue
        fi
        if [ ! -f "${FREEMDOUTFILE}" ]; then
            log "${PWD}: no ${FREEMDOUTFILE}."
            cd .. ; continue
        fi
        OUTFILE_FINISH=$(tail ${FREEMDOUTFILE} -n 1 | grep "wall time")
        if [ -z "${OUTFILE_FINISH}" ]; then
            log "${PWD}: not finished."
        else
            log "${PWD}: finished."
            if  $FINISHEDONLY ; then
                echo $PWD
            fi
        fi
        if [ ! -f "${TRAJFILE}" ]; then
            log "$PWD: no $TRAJFILE"
            cd .. ; continue
        fi
        FRAMECOUNTACTUAL=$(netcdftraj_framecount -p ${PRMTOP} -n ${TRAJFILE})
        if [ $? != 0 ]; then
            err "$(pwd): netcdftraj_framecount returned with error."
            cd ..; cd ..; exit
        fi
        log "${FRAMECOUNTACTUAL} frames."
        cd ..;
    done;
    cd ..;
done
