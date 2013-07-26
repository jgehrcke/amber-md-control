#!/bin/bash
#
#   Copyright 2012-2013 Jan-Philip Gehrcke
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

FREEMDDIR="freemd"
FREEMD_REQUIRED_FILES_DIR="freemd_required_files"

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
set -e

if [ ! -d "${FREEMD_REQUIRED_FILES_DIR}" ]; then
    err "${FREEMD_REQUIRED_FILES_DIR} does not exist. Exit."
fi

MAINDIR=${PWD}

./find_unfinished_tmd_trajectories.sh --finished-only | while read TMDDIR
do
    log "Finished tMD in dir: $TMDDIR"
    TARGETDIR="${TMDDIR}/${FREEMDDIR}"
    if [ -d "${TARGETDIR}" ]; then
        if [ -f "${TARGETDIR}/top.prmtop" ]; then
            log "Directory '${FREEMDDIR}' with top.prmtop exists. Skip."
            continue
        else
            log "${FREEMDDIR} without top.prmtop exists. Remove and proceed."
            rm -rf "${TARGETDIR}"
        fi
    fi
    log "Creating ${TARGETDIR}."
    mkdir "${TARGETDIR}"
    log "Linking required files into the freemd directory."

    for F in ${FREEMD_REQUIRED_FILES_DIR}/*
    do
        F_BASENAME=$(basename "${F}")
        # One up is tMD dir. Two up is equi MD dir. Three up is main MD dir.
        LINK_TARGET="../../../${FREEMD_REQUIRED_FILES_DIR}/${F_BASENAME}"
        LINK_NAME="${TARGETDIR}/${F_BASENAME}"
        ln -s "${LINK_TARGET}" "${LINK_NAME}"
    done
    cd ${TARGETDIR}
    ./build_new_final_system_state_topology.sh < /dev/null
    cd ${MAINDIR}
done
