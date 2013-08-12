#!/bin/bash
# Copyright 2012-2013 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

# To be executed in freemd dir.

# Set up environment (Amber, Python, ...), exit upon error.
if [ -f "../../../env_setup.sh" ]; then
    source "../../../env_setup.sh"
fi
# Now, DMD_CODE_DIR is defined.
source "${DMD_CODE_DIR}/common_code.sh"

LAST_N=250
PRMTOP="top.prmtop"
TRAJFILE="production_NVT.mdcrd"

CPPTRAJ_DIHEDRAL_COMMANDS_INFILE="../../../cpptraj_dihedral_commands"

DIHEDRALOUT_ENTIRE="dihedrals_over_frames_entiretraj.dat"
DIHEDRALOUT_LAST="dihedrals_over_frames_last${LAST_N}frames.dat"

SCRIPTNAME="$(basename "$0")"
SCRIPTNAME_WOEXT="${SCRIPTNAME%.*}"

if [ -f "$DIHEDRALOUT_ENTIRE" ] && [ -f "$DIHEDRALOUT_LAST" ] ; then
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
check_required $CPPTRAJ_DIHEDRAL_COMMANDS_INFILE


# Determine number of frames in trajectory file. Required later.
TRAJFRAMECOUNT=$(netcdftraj_framecount -p ${PRMTOP} -n ${TRAJFILE})
if [ $? != 0 ]; then
    err "$(pwd): netcdftraj_framecount returned with error."
    exit 1
fi

# Check for occurrence of 'dihedrals.dat' in each non-empty line of
# $CPPTRAJ_DIHEDRAL_COMMANDS_INFILE
log "Validate ${CPPTRAJ_DIHEDRAL_COMMANDS_INFILE}"
python - <<EOF
import sys
with open('$CPPTRAJ_DIHEDRAL_COMMANDS_INFILE') as f:
    for l in (_ for _ in f if _.strip()):
        if not 'dihedrals.dat' in l:
            sys.exit("Each non-empty line must contain 'dihedrals.dat'. Exit.")
EOF
EXITCODE=$?
if [[ ${EXITCODE} != 0 ]]; then
    err "$CPPTRAJ_DIHEDRAL_COMMANDS_INFILE validation failed."
    exit 1
fi



# Read cpptraj dihedral commands as specified for this project,
# replace output data set name with current name.
CPPTRAJ_DIHEDRAL_COMMANDS=$(cat $CPPTRAJ_DIHEDRAL_COMMANDS_INFILE | \
    sed "s/dihedrals.dat/${DIHEDRALOUT_ENTIRE}/g")

# Measure dihedrals for entire trajectory.
CPPTRAJINPUT="
# Read entire trajectory.
trajin ${TRAJFILE}

# Content from ${CPPTRAJ_DIHEDRAL_COMMANDS_INFILE}:
${CPPTRAJ_DIHEDRAL_COMMANDS}

# Increase column width so that long column headings are not cut.
precision ${DIHEDRALOUT_ENTIRE} 25 4

# Do not print frames column.
datafile ${DIHEDRALOUT_ENTIRE} noxcol
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
check_required ${DIHEDRALOUT_ENTIRE}


# Read cpptraj dihedral commands as specified for this project,
# replace output data set name with current name.
CPPTRAJ_DIHEDRAL_COMMANDS=$(cat $CPPTRAJ_DIHEDRAL_COMMANDS_INFILE | \
    sed "s/dihedrals.dat/${DIHEDRALOUT_LAST}/g")


# The same for last N frames.
STARTFRAMENUMBER=$((TRAJFRAMECOUNT-${LAST_N}+1))
CPPTRAJINPUT="
# Read last 250 frames of trajectory.
trajin ${TRAJFILE} ${STARTFRAMENUMBER}

# Content from ${CPPTRAJ_DIHEDRAL_COMMANDS_INFILE}:
${CPPTRAJ_DIHEDRAL_COMMANDS}

# Increase column width so that long column headings are not cut.
precision ${DIHEDRALOUT_LAST} 25 4

# Do not print frames column.
datafile ${DIHEDRALOUT_LAST} noxcol
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
check_required ${DIHEDRALOUT_LAST}
