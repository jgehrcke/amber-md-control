#!/bin/bash
#
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

err() {
    # Print error message to stderr.
    echo "ERROR >>> $@" 1>&2
    }

log() {
    # Print message to stdout.
    echo "INFO  >>> $@"
    }

# check number of given arguments:
if [ $# != 2 ]; then
    err "wrong usage."
    err "required first argument: the input PDB file."
    err "requires second argument: the output path for the modified PDB file."
    exit 1
fi

INPDBPATH="$1"
OUTPDBPATH="$2"

# check if all required files are available
check_required () {
    if [ ! -f $1 ]; then
       err "file $1 is required and does not exist. exit." >&2
       exit 1
    fi
    }
check_required ${INPDBPATH}
check_required ../06_md/ligand_residues

LIGAND_RESIDUES=$(cat ../06_md/ligand_residues)

INPUT="
load ${INPDBPATH}, complex
select ligand, resi ${LIGAND_RESIDUES} and complex
save ${OUTPDBPATH}, ligand
"

RNDSTRING=$(tr -dc "[:alpha:]" < /dev/urandom | head -c 25)
TMP="/tmp/pymol_script_${RNDSTRING}.pml"
echo "${INPUT}" > $TMP
pymol -c $TMP
rm -f $TMP
