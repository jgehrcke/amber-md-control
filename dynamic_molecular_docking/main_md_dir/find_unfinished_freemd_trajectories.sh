#!/bin/bash
# Copyright 2012-2014 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de


# If DMD environment has been set up before, don't repeat.
if [[ -z ${DMD_CODE_DIR} ]]; then
    MD_DIR="."
    # Set up environment (Amber, Python, ...), exit upon error.
    if [[ -f "${MD_DIR}/env_setup.sh" ]]; then
        source "${MD_DIR}/env_setup.sh"
    else
        echo "file missing: ${MD_DIR}/env_setup.sh"
        exit 1
    fi
    # Now, DMD_CODE_DIR is defined.
fi
source "${DMD_CODE_DIR}/common_code.sh"


FINISHEDONLY=false
STARTEDONLY=false
CHECKMINFRAMES=false
set +u
if [[ "$1" == "--finished-only" ]]; then
    FINISHEDONLY=true
elif [[ "$1" == "--started-only" ]]; then
    STARTEDONLY=true
elif [[ "$1" == "--minframes" ]]; then
    CHECKMINFRAMES=true
    MINFRAMES="$2"
    test_number "${MINFRAMES}"
fi
set -u


log() {
    if $FINISHEDONLY || $STARTEDONLY || $CHECKMINFRAMES; then
        return
    fi
    # Print message to stdout.
    echo "INFO  >>> $@"
    }

PRMTOP="top.prmtop"
FREEMDOUTFILE="production_NVT.out"
TRAJFILE="production_NVT.mdcrd"
FREEMDDIR="freemd"
REC_LIC_DIST_AFTER_TMD_FILE="receptor_ligand_min_distance_after_tmd"

for LIGDIR in ligand_*; do
    if [ -d "$LIGDIR" ]; then
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
            cd ..; continue
        fi
        if [ ! -f "${FREEMDOUTFILE}" ]; then
            if [ -f "${REC_LIC_DIST_AFTER_TMD_FILE}" ]; then
                DISTANCE="rec-lig-distance: $(cat ${REC_LIC_DIST_AFTER_TMD_FILE})"
            else
                DISTANCE=""
            fi
            log "${PWD}: no ${FREEMDOUTFILE}. ${DISTANCE}"
            cd ../../ ; continue
        fi
        if $STARTEDONLY ; then
            echo $PWD
            cd ../../ ; continue
        fi
        OUTFILE_FINISH=$(tail ${FREEMDOUTFILE} -n 1 | grep "wall time")
        if [ -z "${OUTFILE_FINISH}" ]; then
            log "${PWD}: not finished."
            if  $FINISHEDONLY ; then
                cd ../../ ; continue
            fi
        else
            log "${PWD}: finished."
            if  $FINISHEDONLY ; then
                echo $PWD
                cd ../../ ; continue
            fi
        fi
        if [ ! -f "${TRAJFILE}" ]; then
            log "$PWD: no $TRAJFILE"
            cd ../../ ; continue
        fi
        FRAMECOUNTACTUAL=$(netcdftraj_framecount -p ${PRMTOP} -n ${TRAJFILE})
        if [ $? != 0 ]; then
            err "$(pwd): netcdftraj_framecount returned with error."
            cd ../../ ; exit
        fi
        if $CHECKMINFRAMES; then
            if [ "$FRAMECOUNTACTUAL" -ge "$MINFRAMES" ] ; then
                echo $PWD
                cd ../../ ; continue
            fi
        fi
        LOCKFILENAME="$(generate_lock_filename_homedir)"
        # http://mywiki.wooledge.org/BashFAQ/045
        exec 87>"$LOCKFILENAME"
        if ! flock --nonblock --exclusive 87; then
            LOCKSTATE="LOCKED (running)"
        else
            LOCKSTATE="not locked (not running)"
            rm -rf "$LOCKFILENAME"
        fi
        log "${FRAMECOUNTACTUAL} frames, ${LOCKSTATE}"
        cd ../../ ;
    done;
    cd ..;
done
