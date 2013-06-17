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

# To be executed in freemd dir.

LAST_N=250
PRMTOP="top.prmtop"
TRAJFILE="production_NVT.mdcrd"
RMSOUT_RELATIVE_ENTIRE="rmsd_ligand_relative_over_frames_entiretraj.dat"
RMSOUT_INTERNAL_ENTIRE="rmsd_ligand_internal_over_frames_entiretraj.dat"
RMSOUT_RELATIVE_LAST="rmsd_ligand_relative_over_frames_last${LAST_N}frames.dat"
RMSOUT_INTERNAL_LAST="rmsd_ligand_internal_over_frames_last${LAST_N}frames.dat"

err() {
    # Print error message to stderr.
    echo "$@" 1>&2;
    }
log() {
    # Print message to stdout.
    echo "INFO  >>> $@"
    }
check_delete () {
    # Delete file if existing.
    if [ -f "${1}" ]; then
        echo "Deleting ${1} ..."
        rm -f "${1}"
    fi
    }
check_required () {
    # Check if file is available, exit if not.
    if [ ! -f "${1}" ]; then
       err "File ${1} is required and does not exist. Exit."
       exit 1
    fi
    }
print_run_command () {
    echo "Running command:"
    echo "${1}"
    eval "${1}"
    }
SCRIPTNAME="$(basename "$0")"
SCRIPTNAME_WOEXT="${SCRIPTNAME%.*}"


if [ -f "$RMSOUT_RELATIVE_ENTIRE" ] && [ -f "$RMSOUT_INTERNAL_ENTIRE" ] && \
   [ -f "$RMSOUT_RELATIVE_LAST" ] && [ -f "$RMSOUT_INTERNAL_LAST" ]; then
    err "All output files already exist. Exit without error."
    exit 0
fi


CPPTRAJ=$(command -v cpptraj)
if [ -z ${CPPTRAJ} ]; then
    err "cpptraj not in PATH. Exit."
    exit 1
fi
log "cpptraj path: '${CPPTRAJ}'"


# exit upon error
set -e

check_required $PRMTOP
check_required $TRAJFILE
check_required receptor_residues
check_required ligand_residues
RECEPTOR_RESIDUES=$(cat receptor_residues)
LIGAND_RESIDUES=$(cat ligand_residues)

# Determine number of frames in trajectory file. Required later.
TRAJFRAMECOUNT=$(netcdftraj_framecount -p ${PRMTOP} -n ${TRAJFILE})
if [ $? != 0 ]; then
    err "$(pwd): netcdftraj_framecount returned with error."
    exit 1
fi

# MEASURE LIGAND MOVEMENT FOR ENTIRE TRAJECTORY.
CPPTRAJINPUT="
trajin ${TRAJFILE}
# Align receptors in all frames to receptor in first frame.
rmsd :${RECEPTOR_RESIDUES}@CA,N first
# Measure distance ligand to ligand for each frame without aligning anything.
rmsd :${LIGAND_RESIDUES} first nofit out ${RMSOUT_RELATIVE_ENTIRE}
# Measure distance ligand to ligand for each frame, first align ligand to ligand.
rmsd :${LIGAND_RESIDUES} first out ${RMSOUT_INTERNAL_ENTIRE}
"
# Write input file.
INFILE="${SCRIPTNAME_WOEXT}_entiretraj_cpptraj.in"
INFILE_WOEXT="${INFILE%.*}"
log "Writing input file: ${INFILE}."
echo "${CPPTRAJINPUT}" > ${INFILE}
log "Content of ${INFILE}:"
cat ${INFILE}
echo
# Run cpptraj.
CMD="time cpptraj -p ${PRMTOP} -i ${INFILE}"
print_run_command "${CMD}" 2>&1 | tee ${INFILE_WOEXT}.log
check_required ${RMSOUT_RELATIVE_ENTIRE}
check_required ${RMSOUT_INTERNAL_ENTIRE}


# MEASURE LIGAND MOVEMENT FOR LAST N FRAMES.
STARTFRAMENUMBER=$((TRAJFRAMECOUNT-${LAST_N}+1))
CPPTRAJINPUT="
# If only the first frame is given, then cpptraj from there on processes
# all until the last frame.
trajin ${TRAJFILE} ${STARTFRAMENUMBER}
# Align receptors in all frames to receptor in first frame.
rmsd :${RECEPTOR_RESIDUES}@CA,N first
# Measure distance ligand to ligand for each frame without aligning anything.
rmsd :${LIGAND_RESIDUES} first nofit out ${RMSOUT_RELATIVE_LAST}
# Measure distance ligand to ligand for each frame, first align ligand to ligand.
rmsd :${LIGAND_RESIDUES} first out ${RMSOUT_INTERNAL_LAST}
"
# Write input file.
INFILE="${SCRIPTNAME_WOEXT}_last${LAST_N}frames_cpptraj.in"
INFILE_WOEXT="${INFILE%.*}"
log "Writing input file: ${INFILE}."
echo "${CPPTRAJINPUT}" > ${INFILE}
log "Content of ${INFILE}:"
cat ${INFILE}
echo
# Run cpptraj.
CMD="time cpptraj -p ${PRMTOP} -i ${INFILE}"
print_run_command "${CMD}" 2>&1 | tee ${INFILE_WOEXT}.log
check_required ${RMSOUT_RELATIVE_LAST}
check_required ${RMSOUT_INTERNAL_LAST}
