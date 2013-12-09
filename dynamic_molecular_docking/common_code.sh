#!/bin/bash
# Copyright 2012-2013 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

# Exit script upon attempt to use an uninitialised variable.
set -o nounset

# Prevent from being trapped by cd search paths:
# http://pubs.opengroup.org/onlinepubs/9699919799/utilities/cd.html
unset CDPATH

err() {
    # Print error message to stderr.
    echo "$@" 1>&2;
    }

log() {
    # Print message to stdout.
    echo "INFO  >>> $@"
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
    eval "${1}"
    }

test_number() {
    if ! [[ "${1}" =~ ^[0-9]+$ ]] ; then
        err "Not a number: '${1}'. Exit."
        exit 1
    fi
    }

check_command () {
    command -v "${1}"
    if [ $? -ne 0 ]; then
        err "Command '${1}' not found. Exit."
        exit 1
    fi
    }

generate_lock_filename_homedir () {
    LOCKFILEDIR="${HOME}/dmd_lockfiles"
    if [ ! -d "$LOCKFILEDIR" ]; then
        mkdir "$LOCKFILEDIR"
    fi
    # Get full path of currently running script.
    local FULLPATHDIR=$(cd $(dirname $0); pwd -P)
    local FULLPATH="${FULLPATHDIR}/${0}"
    # Replace slashes.
    local FULLPATH_CLEANED=$(echo "$FULLPATH" | sed "s|/|-|g")
    echo "${LOCKFILEDIR}/${FULLPATH_CLEANED}"
    }

