#!/bin/bash

STARTDIR="$PWD"
SCRIPT_TO_EXECUTE="./minimize_freemd_finalsystemstate.sh"
ABSPATH_TO_SCRIPT=$(readlink -f ${SCRIPT_TO_EXECUTE})

if [[ ! -x "$SCRIPT_TO_EXECUTE" ]]; then
    echo "Does not exist or not executable: $SCRIPT_TO_EXECUTE"
    exit 1
fi

# Set up environment (Amber, Python, ...).
if [ -f "./env_setup.sh" ]; then
    source "./env_setup.sh"
fi

BATCH_SYSTEM=""
DRYRUN=false

for i in "$@"
do
case $i in
    --nbr-cpus=*)
    NBR_CPUS=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    # GPU otherwise.
    ;;
    --batch-system=*)
    BATCH_SYSTEM=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    --dry)
    DRYRUN=true
    ;;
    *)
            # unknown option
    ;;
esac
done


test_number() {
    if ! [[ "${1}" =~ ^[0-9]+$ ]] ; then
        err "Not a number: ${1}. Exit."
        exit 1
    fi
    }

echo "execute script in each free MD dir: ${ABSPATH_TO_SCRIPT}"

./find_unfinished_freemd_trajectories.sh --finished-only | while read FREEMDDIR
do
    cd "$FREEMDDIR"
    echo "Working in $FREEMDDIR..."
    if ${DRYRUN}; then
        echo "Would run here."
        continue
    fi
    # Hardcode topology and coordinate file, forward args to this script to
    # gpu/cpu args of minimization script.
    if [[ $BATCH_SYSTEM != "" ]]; then
        if [[ "$BATCH_SYSTEM" == "sge" ]]; then
            echo "Not implemented. Exit."
            exit 1
        elif [[ "$BATCH_SYSTEM" == "lsf" ]]; then
            echo "Not implemented for LSF. Exit."
            exit 1
        elif [[ "$BATCH_SYSTEM" == "slurm" ]]; then
            if [ -z "$NBR_CPUS" ]; then
                echo "Submit for GPU."
                sbatch  --ntasks 8 --ntasks-per-node 8 --partition gpu --gres:gpu:1 \
                    --time 0:10:00 \
                    --output 'slurm_final_state_minimization_gpu_%j.outerr' \
                    --error 'slurm_final_state_minimization_gpu_%j.outerr' \
                    ${ABSPATH_TO_SCRIPT} top.prmtop production_NVT.rst
            else
                test_number "$NBR_CPUS"
                echo "Submit for $NBR_CPUS CPUs."
                sbatch  --ntasks "${NBR_CPUS}" --ntasks-per-node "${NBR_CPUS}" --partition mpi2 \
                    --mem-per-cpu 2000 \
                    --time 0:30:00 \
                    --output 'slurm_final_state_minimization_cpu_%j.outerr' \
                    --error 'slurm_final_state_minimization_cpu_%j.outerr' \
                    ${ABSPATH_TO_SCRIPT} top.prmtop production_NVT.rst ${NBR_CPUS} cpu
            fi
        else
            echo "Batch system $BATCH_SYSTEM not known. Exit."
            exit 1
        fi
    else
        if [ -z "$NBR_CPUS" ]; then
            ${ABSPATH_TO_SCRIPT} top.prmtop production_NVT.rst &> final_state_minimization_gpu.log < /dev/null
        else
            test_number "$NBR_CPUS"
            ${ABSPATH_TO_SCRIPT} top.prmtop production_NVT.rst "${NBR_CPUS}" cpu &> final_state_minimization_cpu.log < /dev/null
        fi
    fi
    if [ $? -ne 0 ]; then
        echo "Error observed. Abort free MD dir iteration."
        exit 1
    fi
    cd "$STARTDIR"
done
