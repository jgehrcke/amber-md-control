#!/bin/bash
# Copyright 2013 Jan-Philip Gehrcke

# http://stackoverflow.com/a/246128/145400
THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "environment setup from directory ${THIS_SCRIPT_DIR}."
export DMD_CODE_DIR="${THIS_SCRIPT_DIR}/../amber-md-control/dynamic_molecular_docking"

# Template for the environment setup file. Adjust accordingly for
# the HPC environment.

AMBER_SETUP="/projects/bioinfp_apps/amber12_at13_centos58_intel1213_ompi164_cuda5/setup.sh"
PYTHON_SETUP="/projects/bioinfp_apps/Python-2.7.3/setup.sh"
echo "Sourcing $AMBER_SETUP"
source "${AMBER_SETUP}"
echo "Sourcing $PYTHON_SETUP"
source "${PYTHON_SETUP}"

