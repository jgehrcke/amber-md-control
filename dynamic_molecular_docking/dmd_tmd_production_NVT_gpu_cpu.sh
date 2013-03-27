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

# Exit script upon first error.
set -e

AMBER_SETUP="/projects/bioinfp_apps/amber12_centos58_intel1213_openmpi16_cuda5/setup.sh"
CUDAENGINE="pmemd.cuda"
CPUENGINE="mpirun -np ${CPUNUMBER} pmemd.MPI"
EQUI_RESTART_FILE="equilibrate_NPT.rst"
TMD_RESTRAINT_FILE="dmd_tmd.rest"
TOPOLOGYFILE="top.prmtop"
PRODPREFIX="dmd_tmd_NVT"
PRODINFILE="${PRODPREFIX}.in"
TMD_TIME_NS="4"
TMD_TIME_STEPS=$(python -c "print int(${TMD_TIME_NS}*1000000*0.5)")

err() {
    # Print error message to stderr.
    echo "$@" 1>&2;
    }

# Check number of arguments, define help message.
SCRIPTNAME="$(basename "$0")"
# Check number of given arguments:
if [ $# -ne 2 ]; then
    err "Usage: ${SCRIPTNAME} gpu|cpu n_cpus|[gpu_id]"
    err "arg 1: run/output directory (will be created in cwd)."
    err "arg 2: gpu or cpu"
    err "arg 3: the GPU ID to use (optional) or the number of CPUs to use (required)."
    exit 1
fi
OUTDIR="$1"
GPUCPU="$2"
NUMBER="$3"

# Test validity of arguments.
test_number() {
    if ! [[ "${1}" =~ ^[0-9]+$ ]] ; then
        err "Not a number: ${1}. Exit."
        exit 1
    fi
    }

if [ -z "$NUMBER" ]; then
    GPUID="none"
else
    test_number "${NUMBER}"
fi

if [[ "${GPUCPU}" == "gpu" ]]; then
    echo "Setting up MD on GPU ${NUMBER}."
    GPUID="${NUMBER}"
elif [[ "${GPUCPU}" == "cpu" ]]; then
    echo "Setting up MD on ${NUMBER} CPU cores."
    CPUNUMBER="${NUMBER}"
else
    err "Argument must bei either 'gpu' or 'cpu'. Exit."
    exit 1
fi

echo "Hostname: $(hostname)"
echo "Current working directory: $(pwd)"

if [[ "${GPUID}" != "none" ]]; then
    echo "Setting CUDA_VISIBLE_DEVICES to ${GPUID}."
    export CUDA_VISIBLE_DEVICES="${GPUID}"
else
    echo "No GPU ID argument given. CUDA_VISIBLE_DEVICES: ${CUDA_VISIBLE_DEVICES}."
fi

if [[ "${GPUCPU}" == "gpu" ]]; then
    ENGINE=${CUDAENGINE}
elif [[ "${GPUCPU}" == "cpu" ]]; then
    ENGINE=${CPUENGINE}
fi

# Check if all required files are available.
check_required () {
    if [ ! -f $1 ]; then
       err "File $1 is required and does not exist. exit."
       exit 1
    fi
    }

# Check if path is directly in current dir, i.e. does not contain slash
check_in_this_dir () {
    if [[ "${1}" == */* ]]; then
        err "${1} must not contain slashes."
        exit 1
    fi
}

check_required ${TMD_RESTRAINT_FILE}
check_required ${EQUI_RESTART_FILE}
check_required ${TOPOLOGYFILE}
check_in_this_dir ${TMD_RESTRAINT_FILE}
check_in_this_dir ${EQUI_RESTART_FILE}
check_in_this_dir ${TOPOLOGYFILE}
check_in_this_dir ${OUTDIR}

if [ -d ${OUTDIR} ]; then
    echo "Output directory '${OUTDIR}' already exists. Exit."
    exit 1
fi
echo "Creating and entering output directory '${OUTDIR}'."

mkdir ${OUTDIR} && cd ${OUTDIR}

if [ $? != 0 ]; then
    err "Error while creating/entering output directory. Exit."
    exit 1
fi

echo "Linking initcrd and prmtop to current working directory."

# ${TOPOLOGYFILE} etc are guaranteed to be one dir level higher.
ln -s ../${TOPOLOGYFILE} ${TOPOLOGYFILE}
ln -s ../${TMD_RESTRAINT_FILE} ${TMD_RESTRAINT_FILE}
ln -s ../${EQUI_RESTART_FILE} ${EQUI_RESTART_FILE}

echo "tMD time: ${TMD_TIME_NS} ns, time steps: ${TMD_TIME_STEPS}"
echo "Writing input file ${PRODINFILE}."
echo "
NVT production for N ns at 300 K.
This is a restart simulation (irest=1). Coords, velocities and box
information are read from inpcrd file (ntx=5).

ntb=1: constant volume periodic boundary conditions
ntc/ntf=2: SHAKE on hydrogens
temp0 = 300.0, ntt = 1, tautp=10.0: 300K, Berendsen thermostate. Comment by
Ross Walker:
I use a weak coupling (10ps) to approximate NVE. Setting this to
infinite would give you NVE. However, NVE can be tricky to get to work well
when running very long simulations. 2fs with shake is kind of bleeding edge
for NVE, you ideally have to tighten the shake tolerance the PME tolerances
and reduce the time step to get ideal energy conservation (although a good
test to be sure things are working properly). As such while NVT is more
expensive than NVE it is minor and when you add all the extra tolerances
needed for NVE, NVT ends up quicker. In my opinion this is a better option
than using langevin for the entire simulation as all of the issues with
simulation problems, NANs seen on the GPUs etc arise from running long ntt=3
simulations.

t ns simulation time at 2 fs = 0.002 ps time step requires N steps:
N = t * 10**-9 s / (0.002 * 10**-12 s) = 500000 * t

e.g. 16500000 steps -> 33 ns
e.g. 19000000 steps -> 38 ns
e.g.  5000000 steps -> 10 ns

ig: random seed
ioutfm=1: write binary (NetCDF) trajectory

4 ns (2000000 steps) of tMD

&cntrl
 ntx = 1,
 irest = 0,
 ntb = 1,
 cut = 8.0,
 ntc = 2,
 ntf = 2,
 tempi = 300.0,
 temp0 = 300.0,
 ntt = 1,
 tautp = 10.0,
 nstlim = ${TMD_TIME_STEPS},
 dt = 0.002,
 ntpr = 500, ntwx = 500, ntwr = 10000,
 ioutfm = 1,
 ig = -1,
 jar = 1,
/
&wt type='DUMPFREQ', istep1=100, /
&wt type='END', /
DISANG=${TMD_RESTRAINT_FILE}
DUMPAVE=smd.out
LISTIN=POUT
LISTOUT=POUT
/
" > ${PRODINFILE}

echo
echo "content of ${PRODINFILE}:"
cat ${PRODINFILE}

print_run_command () {
    echo "running command:"
    echo "${1}"
    ${1}
    }

echo "Starting tMD production..."
#echo "sourcing  /apps11/bioinfp/amber11_centos5_intel1213_openmpi15/setup.sh"
#source  /apps11/bioinfp/amber11_centos5_intel1213_openmpi15/setup.sh
#module load amber/11
touch PRODUCTION.RUNNING
echo $(hostname) > RUNNING.HOSTNAME
CMD="time ${ENGINE} -O -i ${PRODINFILE} -o ${PRODPREFIX}.out -p ${TOPOLOGYFILE} -c ${EQUI_RESTART_FILE} -r ${PRODPREFIX}.rst -x ${PRODPREFIX}.mdcrd"
print_run_command "${CMD}"

if [ $? != 0 ]; then
    echo "Error during tMD production. exit."
    exit 1
fi

check_delete PRODUCTION.RUNNING
check_delete RUNNING.HOSTNAME

echo "tMD finished."

