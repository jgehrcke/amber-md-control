#!/bin/bash
# Copyright 2013 Jan-Philip Gehrcke

# Exit script upon first error.
set -e

# To be executed in ligand directory.
# Set up environment (Amber, Python, ...).
if [ -f "../env_setup.sh" ]; then
    source "../env_setup.sh"
fi

CORE_ATOM_ID=$(cat core_atom_id)
LIGAND_CENTER_ATOM_ID=$(cat ligand_center_atom_id)
CORE_CENTER_TARGET_DISTANCE=$(cat core_center_target_distance)
DMDPRODRESTFILENAME="dmd_tmd.rest"
COMMONRESTFILENAME="dmd_tmd_common.rest"
DISTANCE_DATA_FILENAME="ligandcenter_protcore_distance.dat"
EQUITRAJ_FILENAME="equilibrate_NPT.mdcrd"
CPPTRAJ_INPUT_FILENAME="get_ligandcenter_protcore_distance.ptrajin"
DISTANCE_VALUE_FILENAME="ligandcenter_protcore_distance"

echo "Plan: create DMD tMD restraints file ${DMDPRODRESTFILENAME}."

CPPTRAJ_INPUT="
trajin ${EQUITRAJ_FILENAME} lastframe
distance datasetname @${CORE_ATOM_ID} @${LIGAND_CENTER_ATOM_ID} out ${DISTANCE_DATA_FILENAME} geom noimage
go
"

echo "${CPPTRAJ_INPUT}" > ${CPPTRAJ_INPUT_FILENAME}
echo " >> Wrote ${CPPTRAJ_INPUT_FILENAME}: "
echo "$(cat ${CPPTRAJ_INPUT_FILENAME})"
echo

echo " >> Extract protein_core_atom - ligand_center_atom distance from last equi MD frame."
echo " >> Running cpptraj."
cpptraj -p top.prmtop -i ${CPPTRAJ_INPUT_FILENAME} &> ${CPPTRAJ_INPUT_FILENAME}.stdouterr

if [ ! -f ${DISTANCE_DATA_FILENAME} ]; then
    echo "${DISTANCE_DATA_FILENAME} was not written. Exit."
    exit 1
fi

echo " >> Wrote ${DISTANCE_DATA_FILENAME}: "
echo "$(cat ${DISTANCE_DATA_FILENAME})"
echo

cat ${DISTANCE_DATA_FILENAME} | tail -n 1 | gawk '{print $2}' > ${DISTANCE_VALUE_FILENAME}

echo " >> Remove ${DISTANCE_DATA_FILENAME}"
rm -f ${DISTANCE_DATA_FILENAME}

echo " >> Wrote ${DISTANCE_VALUE_FILENAME}: "
echo "$(cat ${DISTANCE_VALUE_FILENAME})"
echo

INITIAL_DISTANCE=$(cat ${DISTANCE_VALUE_FILENAME})
DMDPRODRESTFILE_CONTENT="
# tMD time-dependent distance restraint (SMD / jar=1 implementation)
&rst
    iat=${CORE_ATOM_ID}, ${LIGAND_CENTER_ATOM_ID},
    ifvari=1,
    nstep1=0,
    nstep2=%TMD_TIME_STEPS%,
    r1=$(python -c "print ${INITIAL_DISTANCE}-5"), r2=${INITIAL_DISTANCE}, r3=${INITIAL_DISTANCE}, r4=$(python -c "print ${INITIAL_DISTANCE}+5"),
    r1a=$(python -c "print ${CORE_CENTER_TARGET_DISTANCE}-5"), r2a=${CORE_CENTER_TARGET_DISTANCE}, r3a=${CORE_CENTER_TARGET_DISTANCE}, r4a=$(python -c "print ${CORE_CENTER_TARGET_DISTANCE}+5"),
    rk2=100,
    rk2a=100,
    rk3=100,
    rk3a=100,
&end
"
echo "${DMDPRODRESTFILE_CONTENT}" > ${DMDPRODRESTFILENAME}

if [ -f "$COMMONRESTFILENAME" ]; then
    echo " >> Incorporating $COMMONRESTFILENAME"
    cat "$COMMONRESTFILENAME" >> "$DMDPRODRESTFILENAME"
fi
echo " >> Wrote ${DMDPRODRESTFILENAME}: "
cat "${DMDPRODRESTFILENAME}"
echo
