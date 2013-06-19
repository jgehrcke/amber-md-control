#!/bin/bash
# Copyright 2012-2013 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

# To be executed in free MD dir.
# Requires patched AmberTools13.

# Set up environment (Amber, Python, ...), exit upon error.
if [ -f "../../../env_setup.sh" ]; then
    source "../../../env_setup.sh"
fi
# Now, DMD_CODE_DIR is defined.
source "${DMD_CODE_DIR}/common_code.sh"

LAST_N=250
PROJECT="mmpbsa_last${LAST_N}frames"
TRAJFILE="production_NVT.mdcrd"
TOP_UNSOLVATED_COMPLEX="complex_unsolvated.prmtop"
TOP_SOLVATED_COMPLEX="top.prmtop"
TOP_RECEPTOR="receptor.prmtop"
TOP_LIGAND="ligand.prmtop"
#EXECUTABLE="MMPBSA" # AmberTools 1.5
EXECUTABLE="MMPBSA.py" # AmberTools 12

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
STARTFRAMENUMBER=$((TRAJFRAMECOUNT-${LAST_N}+1))
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
&pb
    # http://archive.ambermd.org/201211/0319.html
    radiopt=0,
    inp=1,
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
