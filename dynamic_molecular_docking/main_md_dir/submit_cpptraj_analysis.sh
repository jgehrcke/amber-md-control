#!/bin/bash
# Copyright 2012-2014 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

STARTDIR="$PWD"
BATCH_SYSTEM""

for i in "$@"
do
case $i in
    --batch-system=*)
    BATCH_SYSTEM=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
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

if [ -z "$BATCH_SYSTEM" ]; then
    echo "--batch-system=* argument required."
    exit 1
fi

RUNSCRIPT='
#!/bin/bash
./analyze_freemd_cpptraj_dihedrals_all_freemd_dirs.sh >dihedrals.out  2>dihedrals.err &
./analyze_freemd_cpptraj_movement_all_freemd_dirs.sh >movement.out 2>movement.err &
./analyze_freemd_cpptraj_hbonds_all_freemd_dirs.sh >hbonds.out 2>hbonds.err
wait
'
echo "$RUNSCRIPT" > analyze_cpptraj_jobscript.sh

if [[ "$BATCH_SYSTEM" == "sge" ]]; then
    qsub -pe smp 2 -cwd -V -q bioinfp.q -b yes \
        -o analyze_cpptraj_jobscript.log -j y \
        "/bin/bash analyze_cpptraj_jobscript.sh"
elif [[ "$BATCH_SYSTEM" == "slurm" ]]; then
    sbatch  --ntasks 2 --nodes 1 --cpus-per-task 1 --partition sandy \
        --mem-per-cpu 4000 \
        --time 3:00:00 \
        --output 'analyze_cpptraj_jobscript_%j.outerr' \
        --error 'analyze_cpptraj_jobscript_%j.outerr' \
        analyze_cpptraj_jobscript.sh
else
    echo "Batch system $BATCH_SYSTEM not supported. Exit."
    exit 1
fi