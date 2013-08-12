#!/bin/bash
#
#   Copyright (C) 2012, 2013 Jan-Philip Gehrcke
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


#set -e

LAST_N=250
SEARCH_IN_FREEMD_DIR="mmgbsa_decomp_last${LAST_N}frames/FINAL_DECOMP_MMPBSA.dat"
FREEMDOUTFILE="production_NVT.out"
FREEMDDIR="freemd"

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
        fi
        cd ../../ ;
    done;
    cd ..;
done

