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


# check number of given arguments:
if [ $# != 3 ]; then
    echo "wrong usage."
    echo "required first argument: the reference pdb file (CA atoms are ref)."
    echo "required second argument: the pdb file to be aligned (CA atoms will be aligned)."
    echo "requires third argument: the output path of the aligned pdb file."
    exit 1
fi


REFPDBPATH="$1"
ALIGNPDBPATH="$2"
OUTPDB="$3"

# check if all required files are available
check_required () {
    if [ ! -f $1 ]; then
       echo "file $1 is required and does not exist. exit." >&2
       exit 1
    fi
    }
check_required ${REFPDBPATH}
check_required ${ALIGNPDBPATH}



INPUT="
load ${REFPDBPATH}, reference
select reference_ca, reference and name CA
load ${ALIGNPDBPATH}, alignthis
select alignthis_ca, alignthis and name CA
super alignthis_ca, reference_ca
save ${OUTPDB}, alignthis
quit
"

RNDSTRING=$(tr -dc "[:alpha:]" < /dev/urandom | head -c 25)
TMP="/tmp/pymol_script_${RNDSTRING}.pml"
echo "${INPUT}" > $TMP
pymol -c $TMP
rm -f $TMP






