#!/bin/bash
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

# To be executed in free MD directory.

AMBER_SETUP="/projects/bioinfp_apps/amber12_centos58_intel1213_openmpi16_cuda5/setup.sh"

err() {
    # Print error message to stderr.
    echo "$@" 1>&2;
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

# Check number of given arguments:
if [ $# -le 2 ]; then
    err "Usage: ${SCRIPTNAME} prmtopfile coordfile n_cpus/gpu_id [cpu]"
    err "1st argument: the prmtop file of the system to minimize."
    err "2nd argument: the initial coord file of the system to minimize."
    err "3rd argument: the number of CPUs (required in case of 'cpu') or the GPU ID (optional)."
    err "4th argument: 'cpu' if run should happen on CPU (optional)"
    exit 1
fi

PRMTOP="$1"
INITCRD="$2"
NUMBER="$3"
CPU="$4"

test_number() {
    if ! [[ "${1}" =~ ^[0-9]+$ ]] ; then
        err "Not a number: ${1}. Exit."
        exit 1
    fi
    }

if [ ! -z "$NUMBER" ]; then
    test_number "${NUMBER}"
fi

# ENGINE can bei either GPU or CPU engine. Set default here.



if [ -z "$CPU" ]; then
    # Run on GPU. If GPUID is not set, set it to 'none'.
    # Otherwise, it is a number which will be used for CUDA_VISIBLE_DEVICES.
    ENGINE="pmemd.cuda"
    GPUID="$NUMBER"
    if [ -z "$GPUID" ]; then
        GPUID="none"
    fi
elif [[ "${CPU}" == "cpu" ]]; then
    ENGINE="mpirun -np ${NUMBER} pmemd.MPI"
    GPUID="none"
else
    err "4th argument must be 'cpu' or omitted."
    exit 1
fi

# Useful debug output.
echo "Hostname: $(hostname)"
echo "Current working directory: $(pwd)"
if [ ${PBS_JOBID+x} ]; then
    echo "PBS_JOBID is set ('${PBS_JOBID}')"
fi

if [[ "${GPUID}" != "none" ]]; then
    echo "Setting CUDA_VISIBLE_DEVICES to ${GPUID}."
    export CUDA_VISIBLE_DEVICES="${GPUID}"
else
    if [ ${CUDA_VISIBLE_DEVICES+x} ]
        # http://stackoverflow.com/a/7520543/145400
        then echo "CUDA_VISIBLE_DEVICES is set ('$CUDA_VISIBLE_DEVICES')"
        else echo "CUDA_VISIBLE_DEVICES is not set."
    fi
fi

# Define file names.
MIN1PREFIX="after_freemd_min1"
MIN2PREFIX="after_freemd_min2"
MIN1FILE="${MIN1PREFIX}.in"
MIN2FILE="${MIN2PREFIX}.in"

# Set up environment for Amber.
MODULE_TEST_OUTPUT=$(command -v module) # valid on ZIH
if [ $? -eq 0 ]; then
    echo "Try loading ZIH module amber/12"
    module load amber/12
else
    echo "Sourcing $AMBER_SETUP"
    source "${AMBER_SETUP}"
fi

exit

# MINIMIZATION
# ============================================================================
echo
echo ">>> MINIMIZATION"
# Check if required files are in place.
check_required ${PRMTOP}
check_required ${INITCRD}
# Delete files that will be generated by this script.
check_delete ${MIN1FILE}
check_delete ${MIN2FILE}
echo "Writing minimization input file ${MIN1FILE} ..."
echo "minimization 1
http://ambermd.org/tutorials/basic/tutorial1/section5.htm
Our minimization procedure will consist of a two stage approach.
In the first stage we will keep the SOLUTE fixed and just minimize
the positions of the water and ions. Then in the second stage we
will minimize the entire system.

steepest descent: ncyc, conjugate gradient: maxcyc-ncyc
ntb=1: periodic boundary conditions
ntr=1: restraints

&cntrl
 imin = 1,
 maxcyc = 1500,
 ncyc = 500,
 ntb = 1,
 ntr = 1,
 cut = 8.0
 ig = -1
 restraint_wt = 500.0,
 restraintmask = \"!:WAT\",
/
" > ${MIN1FILE}

echo "Writing minimization input file ${MIN2FILE} ..."
echo "Minimization 2
http://ambermd.org/tutorials/basic/tutorial1/section5.htm
Our minimization procedure will consist of a two stage approach.
In the first stage we will keep the SOLUTE fixed and just minimize
the positions of the water and ions. Then in the second stage we
will minimize the entire system.

Additional Heparin torsional restraints.

&cntrl
 imin = 1,
 maxcyc = 2500,
 ncyc = 1000,
 ntb = 1,
 ntr = 0,
 cut = 8.0,
/
" > ${MIN2FILE}

echo
echo "content of ${MIN1FILE}:"
cat ${MIN1FILE}
echo
echo "content of ${MIN2FILE}:"
cat ${MIN2FILE}


echo "Running first minimization (fixed solute)..."
CMD="time ${ENGINE} -O -i ${MIN1FILE} -o ${MIN1PREFIX}.out -p ${PRMTOP} \
     -c ${INITCRD} -r ${MIN1PREFIX}.rst -ref ${INITCRD}"
print_run_command "${CMD}"
if [ $? != 0 ]; then
    err "Error during first minimization. Exit."
    exit 1
fi
echo "Running second minimization (entire system is flexible)..."
CMD="time ${ENGINE} -O -i ${MIN2FILE} -o ${MIN2PREFIX}.out -p ${PRMTOP} \
     -c ${MIN1PREFIX}.rst -r ${MIN2PREFIX}.rst -ref ${INITCRD}"
print_run_command "${CMD}"
if [ $? != 0 ]; then
    err "Error during second minimization. Exit."
    exit 1
fi
echo "Minimizations done."

echo "Minimization finished."
