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
# Requires patched AmberTools12.

# Set up environment for Amber.
AMBER_SETUP="/projects/bioinfp_apps/amber12_centos58_intel1213_openmpi16_cuda5/setup.sh"
PYTHON_SETUP="/projects/bioinfp_apps/Python-2.7.3/setup.sh"
MODULE_TEST_OUTPUT=$(command -v module) # valid on ZIH
if [ $? -eq 0 ]; then
    echo "Try loading ZIH module amber/12"
    module load amber/12
else
    echo "Sourcing $AMBER_SETUP"
    source "${AMBER_SETUP}"
    echo "Sourcing $PYTHON_SETUP"
    source "${PYTHON_SETUP}"
fi

PROJECT="mmgbsa_decomp_last100frames"
TRAJFILE="production_NVT.mdcrd"
TOP_UNSOLVATED_COMPLEX="complex_unsolvated.prmtop"
TOP_SOLVATED_COMPLEX="top.prmtop"
TOP_RECEPTOR="receptor.prmtop"
TOP_LIGAND="ligand.prmtop"
#EXECUTABLE="MMPBSA" # AmberTools 1.5
EXECUTABLE="MMPBSA.py" # AmberTools 12


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

if [ $# != 1 ]; then
    err "Usage: ${SCRIPTNAME} #_CPUs"
    err "1st argument required: number of CPUs to use."
    exit 1
fi

CPUNUMBER="$1"
if ! [[ "${CPUNUMBER}" =~ ^[0-9]+$ ]] ; then
   err "Not a number: ${CPUNUMBER}. Exit."
   exit 1
fi
log "Setting up MMPBSA on ${CPUNUMBER} CPU core(s)."
# Define engine (distinguish serial/parallel).
if (( "${CPUNUMBER}" > "1" )); then
    EXECUTABLE="${EXECUTABLE}.MPI"
    ENGINE="mpirun -np ${CPUNUMBER} ${EXECUTABLE}"
else
    ENGINE="${EXECUTABLE}"
fi

MMPBSAEXE=$(command -v ${EXECUTABLE})
if [ -z ${MMPBSAEXE} ]; then
    err "$EXECUTABLE not in PATH. Exit."
    exit 1
fi
log "$EXECUTABLE path: '${MMPBSAEXE}'"

# Exit upon error.
set -e

check_required $TRAJFILE
check_required $TOP_UNSOLVATED_COMPLEX
check_required $TOP_SOLVATED_COMPLEX
check_required $TOP_RECEPTOR
check_required $TOP_LIGAND

# Determine number of frames in trajectory file. Required later.
TRAJFRAMECOUNT=$(netcdftraj_framecount -p ${TOP_SOLVATED_COMPLEX} -n ${TRAJFILE})
if [ $? != 0 ]; then
    err "$(pwd): netcdftraj_framecount returned with error."
    exit 1
fi
STARTFRAMENUMBER=$((TRAJFRAMECOUNT-100+1))
ENDFRAMENUMBER=$TRAJFRAMECOUNT

# MMPBSA input file.
MMPBSAINPUT="
&general
    startframe = ${STARTFRAMENUMBER},
    endframe = ${ENDFRAMENUMBER},
    interval = 1,
    verbose = 2,
    keep_files = 2,
    use_sander = 1
/
&gb
/
&decomp
    idecomp = 2,
/
"

RUNDIR="${PROJECT}"
INFILE="${PROJECT}.in"
INFILE_WOEXT="${INFILE%.*}"
if [ -d ${RUNDIR} ]; then
    err "Directory ${RUNDIR} already exists. Exit."
    exit 0
fi
log "Creating and entering directory ${RUNDIR}."
mkdir ${RUNDIR}
cd ${RUNDIR}
log "Writing input file: ${INFILE}."
echo "${MMPBSAINPUT}" > ${INFILE}
log "Content of ${INFILE}:"
cat ${INFILE}
echo
echo


CMD="time ${ENGINE} -O -i ${INFILE} \
    -cp ../${TOP_UNSOLVATED_COMPLEX} \
    -sp ../${TOP_SOLVATED_COMPLEX} \
    -rp ../${TOP_RECEPTOR} \
    -lp ../${TOP_LIGAND} \
    -y ../${TRAJFILE}"
print_run_command "${CMD}" 2>&1 | tee ${INFILE_WOEXT}.log
