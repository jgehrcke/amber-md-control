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

SCRIPTNAME="$(basename ${0})"

err() {
    # Print error message to stderr.
    echo "ERROR >>> $@" 1>&2
    }

log() {
    # Print message to stdout.
    echo "INFO  >>> $@"
    }

check_delete () {
    # Delete file if existing.
    if [ -f "${1}" ]; then
        log "Deleting ${1} ..."
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
    log "Running command:"
    echo -e "${1}\n"
    ${1}
    echo
    }


# check number of given arguments:
if [ $# != 5 ]; then
    err "Wrong usage."
    err "1st arg: Amber topology file."
    err "2nd arg: NetCDF trajectory file."
    err "3rd arg: cpptraj frame selection, e.g. '2 2' or 'lastframe'."
    err "4th arg: ambmask selecting the atoms to strip before writing PDB file".
    err "5th arg: output PDB filename."
    exit 1
fi

PRMTOP="$1"
TRAJFILE="$2"
FRAMESELECTION="$3"
AMBMASK="$4"
OUTPDB="$5"


if [ -f "${OUTPDB}" ]; then
    err "${MDDIR}/${OUTPDB} already exists. exit."
    exit 1
fi


check_required "${PRMTOP}"
check_required "${TRAJFILE}"

log "which cpptraj: $(which cpptraj)"
log "cpptraj: extract PDB from $(pwd)/${TRAJFILE}, frameselection '${FRAMESELECTION}', strip '${AMBMASK}'"

INPUT="
trajin ${TRAJFILE} ${FRAMESELECTION}
strip ${AMBMASK}
trajout ${OUTPDB} pdb
go
"
SCRIPTNAME_WOEXT="${SCRIPTNAME%.*}"
OUTPDB_WOEXT="${OUTPDB%.*}"
echo "${INPUT}" | cpptraj -p ${PRMTOP} &> ${SCRIPTNAME_WOEXT}_${OUTPDB_WOEXT}.stdouterr

if [ $? -ne 0 ]; then
    err "cpptraj returncode != 0. Exit."
    exit 1
fi

if [ -f "${OUTPDB}" ]; then
    echo "${OUTPDB} written."
else
    err "${OUTPDB} was not written. Exit."
    exit 1
fi

