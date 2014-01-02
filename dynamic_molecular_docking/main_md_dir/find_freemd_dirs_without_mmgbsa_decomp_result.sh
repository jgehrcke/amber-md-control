#!/bin/bash
# Copyright 2012-2014 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

#set -e

LAST_N=250
SEARCH_IN_FREEMD_DIR="mmgbsa_decomp_last${LAST_N}frames/FINAL_DECOMP_MMPBSA.dat"
DELETEDIRPATH="mmgbsa_decomp_last${LAST_N}frames"

FREEMDOUTFILE="production_NVT.out"
FREEMDDIR="freemd"

REMOVEDIR=false
for i in "$@"
do
case $i in
    --deletedir)
    REMOVEDIR=true
    ;;
    *)
            # unknown option
    ;;
esac
done

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
            cd ..; continue
        fi
        if [ ! -f "${FREEMDOUTFILE}" ]; then
            cd ../../ ; continue
        fi
        OUTFILE_FINISH=$(tail ${FREEMDOUTFILE} -n 1 | grep "wall time")
        if [ -z "${OUTFILE_FINISH}" ]; then
            # free MD not finished
            cd ../../ ; continue
        else
            if [ -f ${SEARCH_IN_FREEMD_DIR} ]; then
                cd ../../ ; continue
            fi
            # free MD finished, but MMPBSA result file not in place.
            echo $PWD
            if ${REMOVEDIR}; then
                if [ -d "$DELETEDIRPATH" ]; then
                    echo "Removing directory $DELETEDIRPATH"
                    rm -rf "$DELETEDIRPATH"
                else
                    echo "Removing directory $DELETEDIRPATH: dir does not exist."
                fi
            fi
        fi
        cd ../../ ;
    done;
    cd ..;
done

