#!/bin/bash
# Copyright 2012-2014 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de


MD_DIR="."
# Set up environment (Amber, Python, ...), exit upon error.
if [[ -f "${MD_DIR}/env_setup.sh" ]]; then
    source "${MD_DIR}/env_setup.sh"
else
    echo "file missing: ${MD_DIR}/env_setup.sh"
    exit 1
fi
# Now, DMD_CODE_DIR is defined.
source "${DMD_CODE_DIR}/common_code.sh"


set +u
if [[ "$1" == "--finished-only" ]];then
    FINISHEDONLY=true
else
    FINISHEDONLY=false
fi
set -u


log() {
    if $FINISHEDONLY ; then
        return
    fi
    # Print message to stdout.
    echo "INFO  >>> $@"
    }


PRMTOP="top.prmtop"
TMDOUTFILE="dmd_tmd_NVT.out"
TRAJFILE="dmd_tmd_NVT.mdcrd"


for LIGDIR in ligand_*; do
    if [ -d ${LIGDIR} ]; then
        cd ${LIGDIR};
    else
        continue
    fi
    for TMDDIR in tmd_*; do
        if [ -d ${TMDDIR} ]; then
            cd ${TMDDIR}
        else
            continue
        fi
        if [ ! -f "${TMDOUTFILE}" ]; then
            log "${PWD}: no ${TMDOUTFILE}."
            cd .. ; continue
        fi
        OUTFILE_FINISH=$(tail ${TMDOUTFILE} -n 1 | grep "wall time")
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
            cd ..; cd ..; #exit
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
        cd ..;
    done;
    cd ..;
done
