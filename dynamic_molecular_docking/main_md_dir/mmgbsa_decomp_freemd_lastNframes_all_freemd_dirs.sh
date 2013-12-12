#!/bin/bash
# Copyright 2012-2013 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

STARTDIR="$PWD"
SCRIPT_TO_EXECUTE="./mmgbsa_decomp_freemd_lastNframes.sh"
ABSPATH_TO_SCRIPT=$(readlink -f ${SCRIPT_TO_EXECUTE})

BATCH_SYSTEM""
DRYRUN=false

for i in "$@"
do
case $i in
    --nbr-cpus=*)
    NBR_CPUS=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
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

# Set up environment (Amber, Python, ...).
if [ -f "./env_setup.sh" ]; then
    source "./env_setup.sh"
fi

if [ -z "$NBR_CPUS" ]; then
    echo "--nbr-cpus=N argument required."
    exit 1
fi

echo "execute script in each free MD dir: ${ABSPATH_TO_SCRIPT}"

./find_freemd_dirs_without_mmgbsa_decomp_result.sh | while read FREEMDDIR
do
    cd "$FREEMDDIR"
    echo "Working in $FREEMDDIR (swallowing stdout)..."
    # Some MMPBSA-related process reads from STDIN and therefore swallows
    # the output of find_unfinished... provided to `while read...` above.
    # Give MMPBSA some STDIN to read from in order to keep the loop intact.

    if ${DRYRUN}; then
        echo "Would run here."
        continue
    fi

    if [[ $BATCH_SYSTEM != "" ]]; then
        if [[ "$BATCH_SYSTEM" == "sge" ]]; then
            qsub -pe smp $NBR_CPUS -cwd -V -q bioinfp.q -b yes \
                -o mmgbsa_decomp_sge.log -j y "/bin/bash ${ABSPATH_TO_SCRIPT} $NBR_CPUS" < /dev/null
        elif [[ "$BATCH_SYSTEM" == "lsf" ]]; then
            echo "Not implemented for LSF. Exit."
            exit 1
        elif [[ "$BATCH_SYSTEM" == "slurm" ]]; then
            #echo "Not implemented for Slurm. Exit."
            sbatch  --ntasks ${NBR_CPUS} --nodes 1 --cpus-per-task 1 --partition sandy \
                --mem-per-cpu 2000 \
                --time 1:00:00 \
                --output 'slurm_mmgbsa_mpi_%j.outerr' \
                --error 'slurm_mmgbsa_mpi_%j.outerr' \
                ${ABSPATH_TO_SCRIPT} ${NBR_CPUS}            
        else
            echo "Batch system $BATCH_SYSTEM not known. Exit."
            exit 1
        fi
    else
        ${ABSPATH_TO_SCRIPT} "$NBR_CPUS" 1> /dev/null < /dev/null
    fi
    if [ $? -ne 0 ]; then
        echo "Error observed. Abort free MD dir iteration."
        cd "$STARTDIR"
        exit 1
    fi
    cd "$STARTDIR"
done
