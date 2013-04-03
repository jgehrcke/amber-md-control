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

# Define MD timings. Boundary condition: MD time step of 2 fs.
HEATUP_TIME_NS="0.02"
EQUI_TIME_NS="0.5"
PROD_TIME_NS="10"

HEATUP_TIME_STEPS=$(python -c "print int(${HEATUP_TIME_NS}*1000000*0.5)")
EQUI_TIME_STEPS=$(python -c "print int(${EQUI_TIME_NS}*1000000*0.5)")
PROD_TIME_STEPS=$(python -c "print int(${PROD_TIME_NS}*1000000*0.5)")

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
    ${1}
    }

SCRIPTNAME="$(basename "$0")"

# Check number of given arguments:
if [ $# -le 2 ]; then
    err "Usage: ${SCRIPTNAME} prmtopfile coordfile n_cpus [gpu_id]"
    err "1st argument: the prmtop file of the system to minimize."
    err "2nd argument: the initial coord file of the system to minimize."
    err "3rd argument: the number of CPUs to use (for minimization in case of GPU)."
    err "4th argument: GPU ID (optional in case of GPU) or 'cpu' (runs all steps on CPU)"
    exit 1
fi

PRMTOP="$1"
INITCRD="$2"
NCPUS="$3"
GPUID="$4"

test_number() {
    if ! [[ "${1}" =~ ^[0-9]+$ ]] ; then
        err "Not a number: ${1}. Exit."
        exit 1
    fi
    }

# The third argument must in any case be a number.
test_number "${NCPUS}"

# ENGINE can bei either GPU or CPU engine. Set default here.
ENGINE="pmemd.cuda"
CPUENGINE="mpirun -np ${NCPUS} pmemd.MPI"

# GPUID is either not set (default GPU), a number (use *that* GPU) or 'cpu'.
if [ -z "$GPUID" ]; then
    GPUID="none"
else
    if [[ "${GPUID}" == "cpu" ]]; then
        # Use CPU engine as default engine, mark GPUID as being useless.
        ENGINE="${CPUENGINE}"
        GPUID="none"
    else
        test_number "${GPUID}"
    fi
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
MIN1PREFIX="min1"
MIN2PREFIX="min2"
MIN1FILE="${MIN1PREFIX}.in"
MIN2FILE="${MIN2PREFIX}.in"
HEATPREFIX="heatup_NVT"
HEATINFILE="${HEATPREFIX}.in"
EQUIPREFIX="equilibrate_NPT"
EQUIINFILE="${EQUIPREFIX}.in"
PRODPREFIX="production_NVT"
PRODINFILE="${PRODPREFIX}.in"

echo "Sourcing $AMBER_SETUP"
source "${AMBER_SETUP}"

echo "heatup duration: ${HEATUP_TIME_NS} ns, time steps: ${HEATUP_TIME_STEPS}"
echo "equi duration: ${EQUI_TIME_NS} ns, time steps: ${EQUI_TIME_STEPS}"
echo "prod duration: ${PROD_TIME_NS} ns, time steps: ${PROD_TIME_STEPS}"


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
CMD="time ${CPUENGINE} -O -i ${MIN1FILE} -o ${MIN1PREFIX}.out -p ${PRMTOP} \
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
echo "Converting final coordinates to PDB file format..."
ambpdb -p ${PRMTOP} < ${MIN2PREFIX}.rst > aftermin.pdb
if [ -f aftermin.pdb ]; then
    echo "aftermin.pdb written."
else
    err "aftermin.pdb not created."
fi
echo "Minimization finished."


# HEATUP
# ============================================================================
echo
echo ">>> HEATUP"
check_required ${MIN2PREFIX}.rst
check_delete ${HEATINFILE}
echo "Writing input file ${HEATINFILE} ..."
echo "
Heating up the system to about 300 K in NVT ensemble during 20 ps.
As the density (especially of water) presumably is not the natural density,
this process must be kept very short in order to *not* create vacuum bubbles
in the water (Jason Swails & Ross Walker).

Starting from 0 temperature is not a good idea for this short amount of time.
200 K as starting temp is still very cold and therefore fine (C. Simmerling)

ntx=1: restart file and no initial velocities.
ntb=1: periodic boundary conditions constant volume
ntc/ntf=2: SHAKE on hydrogens
cutoff of 8 Angstrom
ntr=1: keep solute fixed (moderate positional restraint)
ntt=3: Langevin thermostate; gamma_ln: collision frequency

N=10000 -> 20 ps

&cntrl
 ntx = 1,
 ntb = 1,
 cut = 8.0,
 ntr = 1,
 ntc = 2,
 ntf = 2,
 tempi = 200,
 temp0 = 300,
 ntt = 3,
 gamma_ln = 1.0,
 nstlim = ${HEATUP_TIME_STEPS}, dt = 0.002,
 ntpr = 500, ntwx = 500, ntwr = 10000,
 ioutfm = 1,
 ig = -1,
 ntr = 1,
 restraint_wt = 10.0,
 restraintmask = \"!:WAT\",
/
" > ${HEATINFILE}
echo
echo "content of ${HEATINFILE}:"
cat ${HEATINFILE}
echo "Running heatup..."
CMD="time ${ENGINE} -O -i ${HEATINFILE} -o ${HEATPREFIX}.out -p ${PRMTOP} \
     -c ${MIN2PREFIX}.rst -r ${HEATPREFIX}.rst -x ${HEATPREFIX}.mdcrd \
     -ref ${MIN2PREFIX}.rst"
print_run_command "${CMD}"
if [ $? != 0 ]; then
    err "Error during heatup. Exit."
    exit 1
fi
echo "Heatup finished."


# EQUILIBRATION
# ============================================================================
echo
echo ">>> EQUILIBRATION"
check_required ${HEATPREFIX}.rst
check_delete ${EQUIINFILE}
echo "Writing input file ${EQUIINFILE} ..."
echo "
NPT equilibration for 0.5 ns at 300 K in order to relax the system to its
natural density and normal pressure. This is a restart simulation (irest=1)
and coords, velocities and box information are read from inpcrd file (ntx=5).

ntb=2: constant pressure periodic boundary conditions (p default 1.0)
ntp=1: isotropic pressure scaling (must be 1 or 2 for const. pressure dyn.)
taup=2: pressure relaxation time (ps), slightly slower than default (1 ps)
ntc/ntf=2: SHAKE on hydrogens
temp0 = 300.0, ntt = 3, gamma_ln = 1.0: 300K Langevin, collision freq: 1/ps

2 ns simulation time at 2 fs = 0.002 ps time step requires N steps:
N = 2 * 10**-9 s / (0.002 * 10**-12 s) = 1000000

1 ns: 500000
500 ps: 250000

ioutfm=1: write binary (NetCDF) trajectory

Additional Heparin torsional restraints

ntpr: mdinfo and mdout file
ntwx: coordinates to trajectory file
ntwr: restart file

&cntrl
 irest = 1, ntx = 5,
 ntb = 2, ntp = 1,
 taup = 2.0,
 cut = 8.0,
 ntc = 2, ntf = 2,
 temp0 = 300.0, ntt = 3, gamma_ln = 1.0,
 nstlim = ${EQUI_TIME_STEPS}, dt = 0.002,
 ntpr = 2000,
 ntwx = 2000,
 ntwr = 100000,
 ioutfm = 1,
/
" > ${EQUIINFILE}
echo
echo "content of ${EQUIINFILE}:"
cat ${EQUIINFILE}

echo "Running equilibration..."
CMD="time ${ENGINE} -O -i ${EQUIINFILE} -o ${EQUIPREFIX}.out -p ${PRMTOP} \
     -c ${HEATPREFIX}.rst -r ${EQUIPREFIX}.rst -x ${EQUIPREFIX}.mdcrd"
# deleted -ref initcoords.crd"
print_run_command "${CMD}"
if [ $? != 0 ]; then
    err "Error during equilibration. Exit."
    exit 1
fi
echo "Equilibration finished."


# PRODUCTION
# ============================================================================
echo
echo ">>> PRODUCTION"
check_required ${EQUIPREFIX}.rst
check_delete ${PRODINFILE}
echo "Writing input file ${PRODINFILE} ..."
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
e.g. 10000000 steps -> 20 ns

ioutfm=1: write binary (NetCDF) trajectory

Additional Heparin torsional restraints

ntpr: mdinfo and mdout file
ntwx: coordinates to trajectory file
ntwr: restart file

&cntrl
 irest = 1, ntx = 5,
 ntb = 1,
 cut = 8.0,
 ntc = 2, ntf = 2,
 temp0 = 300.0, ntt = 1, tautp = 10.0,
 nstlim = ${PROD_TIME_STEPS}, dt = 0.002,
 ntpr = 2000,
 ntwx = 2000,
 ntwr = 100000,
 ioutfm = 1,
/
" > ${PRODINFILE}
echo
echo "content of ${PRODINFILE}:"
cat ${PRODINFILE}
echo "Running production..."
CMD="time ${ENGINE} -O -i ${PRODINFILE} -o ${PRODPREFIX}.out -p ${PRMTOP} \
     -c ${EQUIPREFIX}.rst -r ${PRODPREFIX}.rst -x ${PRODPREFIX}.mdcrd"
print_run_command "${CMD}"
if [ $? != 0 ]; then
    err "Error during production. Exit."
    exit 1
fi
echo "Production finished."

