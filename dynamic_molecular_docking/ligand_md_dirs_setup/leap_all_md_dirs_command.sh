#!/bin/bash

STARTDIR="$PWD"

AMBER_SETUP="/projects/bioinfp_apps/amber12_at13_centos58_intel1213_ompi164_cuda5/setup.sh"
PYTHON_SETUP="/projects/bioinfp_apps/Python-2.7.3/setup.sh"
MODULE_TEST_OUTPUT=$(command -v module) # valid on ZIH
if [ $? -eq 0 ]; then
    echo "Try loading ZIH module amber/12"
    module load amber/12
else
    echo "Sourcing $AMBER_SETUP"
    source "${AMBER_SETUP}"
    echo "Sourcing $PYTHON_SETUP"
    source "${PYTHON_SETUP}"
fi


# 'tleap' might be an alias defined in amber setup script, the alias should be used here.
shopt -s expand_aliases


cd ../06_md || exit 1

for LIGDIR in *
do
    if [ ! -d "$LIGDIR" ]; then
        continue
    fi
    cd "$LIGDIR"
    echo "Run leap in $LIGDIR"
    tleap -f leap.in
    cd ..
done

echo "cding back to $STARTDIR."
cd "$STARTDIR"
    
