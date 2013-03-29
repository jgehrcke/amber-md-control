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

set -e

FREEMDDIR="freemd"
FREEMD_REQUIRED_FILES_DIR="freemd_required_files"

source /projects/bioinfp_apps/amber12_centos58_intel1213_openmpi16_cuda5/setup.sh

err() {
    # Print error message to stderr.
    echo "ERROR >>> $@" 1>&2
    }

log() {
    # Print message to stdout.
    echo "INFO  >>> $@"
    }


if [ ! -d "${FREEMD_REQUIRED_FILES_DIR}" ]; then
    err "${FREEMD_REQUIRED_FILES_DIR} does not exist. Exit."
fi

MAINDIR=${PWD}

./find_unfinished_tMD_trajectories.sh --finished-only | while read TMDDIR
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
    ./build_new_final_system_state_topology.sh
    cd ${MAINDIR}
done
