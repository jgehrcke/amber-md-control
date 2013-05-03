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

PRMTOP="top.prmtop"
TRAJFILE="production_NVT.mdcrd"
ENTIRE_HBOND_REG_LIG_AVG_DAT_FILE="hbonds_rec_lig_average_entire.dat"
ENTIRE_HBOND_LIG_REG_AVG_DAT_FILE="hbonds_lig_reg_average_entire.dat"
ENTIRE_HBOND_OUT_FILE="hbonds_out_entire.dat"

LAST_N=250 # 1 ns in case of 2500 frames for 10 ns.

LAST_N_HBOND_REG_LIG_AVG_DAT_FILE="hbonds_rec_lig_average_last_${LAST_N}.dat"
LAST_N_HBOND_LIG_REG_AVG_DAT_FILE="hbonds_lig_reg_average_last_${LAST_N}.dat"
LAST_N_HBOND_OUT_FILE="hbonds_out_last_${LAST_N}.dat"



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

ONE_MISSING=false
for FILENAME in \
    $ENTIRE_HBOND_REG_LIG_AVG_DAT_FILE \
    $ENTIRE_HBOND_LIG_REG_AVG_DAT_FILE \
    $ENTIRE_HBOND_OUT_FILE \
    $LAST_N_HBOND_REG_LIG_AVG_DAT_FILE \
    $LAST_N_HBOND_LIG_REG_AVG_DAT_FILE \
    $LAST_N_HBOND_OUT_FILE
do
    if [ ! -f $FILENAME ]; then
        ONE_MISSING=true
    fi
done
if ! $ONE_MISSING ; then
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

# ANALYZE HBONDS FOR ENTIRE TRAJECTORY.
INTERVAL=1
CPPTRAJINPUT="
trajin ${TRAJFILE} 1 last $INTERVAL
hbond REC-LIG donormask :${RECEPTOR_RESIDUES} acceptormask :${LIGAND_RESIDUES}@F*,O*,N* out ${ENTIRE_HBOND_OUT_FILE} avgout ${ENTIRE_HBOND_REG_LIG_AVG_DAT_FILE}
hbond LIG-REC donormask :${LIGAND_RESIDUES} acceptormask :${RECEPTOR_RESIDUES}@F*,O*,N* out ${ENTIRE_HBOND_OUT_FILE} avgout ${ENTIRE_HBOND_LIG_REG_AVG_DAT_FILE}
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

check_required $ENTIRE_HBOND_REG_LIG_AVG_DAT_FILE
check_required $ENTIRE_HBOND_LIG_REG_AVG_DAT_FILE
check_required $ENTIRE_HBOND_OUT_FILE

# MEASURE LIGAND MOVEMENT FOR LAST 100 FRAMES.
STARTFRAMENUMBER=$((TRAJFRAMECOUNT-${LAST_N}+1))
CPPTRAJINPUT="
# If only the first frame is given, then cpptraj from there on processes
# all until the last frame.
trajin ${TRAJFILE} ${STARTFRAMENUMBER}
hbond REC-LIG donormask :${RECEPTOR_RESIDUES} acceptormask :${LIGAND_RESIDUES}@F*,O*,N* out ${LAST_N_HBOND_OUT_FILE} avgout ${LAST_N_HBOND_REG_LIG_AVG_DAT_FILE}
hbond LIG-REC donormask :${LIGAND_RESIDUES} acceptormask :${RECEPTOR_RESIDUES}@F*,O*,N* out ${LAST_N_HBOND_OUT_FILE} avgout ${LAST_N_HBOND_LIG_REG_AVG_DAT_FILE}
"
# Write input file.
INFILE="${SCRIPTNAME_WOEXT}_last_n_frames_cpptraj.in"
INFILE_WOEXT="${INFILE%.*}"
log "Writing input file: ${INFILE}."
echo "${CPPTRAJINPUT}" > ${INFILE}
log "Content of ${INFILE}:"
cat ${INFILE}
echo
# Run cpptraj.
CMD="time cpptraj -p ${PRMTOP} -i ${INFILE}"
print_run_command "${CMD}" 2>&1 | tee ${INFILE_WOEXT}.log


check_required $LAST_N_HBOND_REG_LIG_AVG_DAT_FILE
check_required $LAST_N_HBOND_LIG_REG_AVG_DAT_FILE
check_required $LAST_N_HBOND_OUT_FILE

