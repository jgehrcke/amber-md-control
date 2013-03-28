#!/bin/bash
#
#   Copyright (C) 2012 Jan-Philip Gehrcke
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
#

err() {
    # Print error message to stderr.
    echo "ERROR >>> $@" 1>&2
    }

log() {
    # Print message to stdout.
    echo "INFO  >>> $@"
    }

# Check number of given arguments:
if [ $# -lt 1 ]; then
    err "Usage: ${SCRIPTNAME} filedir1 filedir2..."
    exit 1
fi


for LIGDIR in ligand_*; do
    if [ -d "$LIGDIR" ]; then
        cd "$LIGDIR"
    else
        continue
    fi
    for TMDDIR in tmd_*; do
        if [ -d "$TMDDIR" ];then
            cd "$TMDDIR"
        else
            continue
        fi
        if [ -d freemd ]; then
            cd freemd
            log "pwd: $(pwd)"
            for FILEDIR in "$@"; do
                if [[ -e "$FILEDIR" || -L "$FILEDIR" ]]; then
                    log "delete: $FILEDIR"
                    rm -rf $FILEDIR
                fi
            done
            cd ..
        fi 
        cd ..;
    done;
    cd ..;
done
