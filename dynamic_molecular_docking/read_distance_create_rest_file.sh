#!/bin/bash

CORE_ATOM_ID=$(cat core_atom_id)
LIGAND_CENTER_ATOM_ID=$(cat ligand_center_atom_id)
CORE_CENTER_TARGET_DISTANCE=$(cat core_center_target_distance)

AMBER_SETUP="/apps11/bioinfp/amber12_centos58_intel1213_openmpi16_cuda5/setup.sh"

DMDPRODRESTFILENAME="dmd_production.rest"

echo "Create DMD tMD restraints file ${DMDPRODRESTFILENAME}."
echo " >> Sourcing ${AMBER_SETUP}"
source ${AMBER_SETUP}

DISTANCE_DATA_FILENAME="ligandcenter_protcore_distance.dat"

CPPTRAJ_INPUT="
trajin equilibrate_NPT.mdcrd lastframe
distance datasetname @${CORE_ATOM_ID} @${LIGAND_CENTER_ATOM_ID} out ${DISTANCE_DATA_FILENAME} geom noimage
go
"

CPPTRAJ_INPUT_FILENAME="get_ligandcenter_protcore_distance.ptrajin"
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

DISTANCE_VALUE_FILENAME="ligandcenter_protcore_distance"
cat ${DISTANCE_DATA_FILENAME} | tail -n 1 | gawk '{print $2}' > ${DISTANCE_VALUE_FILENAME}

echo " >> Remove ${DISTANCE_DATA_FILENAME}"
rm -f ${DISTANCE_DATA_FILENAME}

echo " >> Wrote ${DISTANCE_VALUE_FILENAME}: "
echo "$(cat ${DISTANCE_VALUE_FILENAME})"
echo

INITIAL_DISTANCE=$(cat ${DISTANCE_VALUE_FILENAME})

DMDPRODRESTFILE_CONTENT="
&rst
    iat=${CORE_ATOM_ID}, ${LIGAND_CENTER_ATOM_ID},
    r2=${INITIAL_DISTANCE},
    r2a=${CORE_CENTER_TARGET_DISTANCE},
    rk2=100,
&end
"

echo "${DMDPRODRESTFILE_CONTENT}" > ${DMDPRODRESTFILENAME}

echo "wrote ${DMDPRODRESTFILENAME}: "
echo "$(cat ${DMDPRODRESTFILENAME})"
echo 

