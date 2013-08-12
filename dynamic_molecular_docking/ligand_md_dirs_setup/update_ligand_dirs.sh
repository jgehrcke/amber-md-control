#!/bin/bash
# Copyright 2011-2013 Jan-Philip Gehrcke
#

err() {
    # Print error message to stderr.
    echo "$@" 1>&2;
    }

source /apps11/bioinfp/Python-2.7.3/setup.sh
# os.path.relpath from Python 2.6 might be broken
relpath() {
    # relpath targetdir startdir returns the relative path start->target
    if [ -d "$1" ]; then
        if [ -d "$2" ]; then
            python -c "import os.path; print os.path.relpath('$1','$2')"
            return 0
        fi
    fi
    err "relpath called without both arguments being a directory."
    return 1
    }

SCRIPTNAME="$(basename "$0")"

OUTDIR_ROOT="$1"
if [ ! -d "$OUTDIR_ROOT" ]; then
    err "OUTDIR_ROOT arg1 '$OUTDIR_ROOT' directory does not exist. Exit."
    exit 1
fi

REQUIRED_FILES_DIR=link_to_each_ligand_dir
if [ ! -d "$REQUIRED_FILES_DIR" ]; then
    err "$REQUIRED_FILES_DIR directory does not exist. Exit."
    exit 1
fi

for PROJECTDIR in $OUTDIR_ROOT/*
do
    if [ ! -d "$PROJECTDIR" ]; then
        continue
    fi
    echo "Working in project directory $PROJECTDIR"
    echo "  Linking the link-to-each-ligand-dir files into the project directory."
    PROJECTDIR_TO_REQFILESDIR_REL=$(relpath "${REQUIRED_FILES_DIR}" "${PROJECTDIR}")
    for F in ${REQUIRED_FILES_DIR}/*
    do
        F_BASENAME=$(basename "${F}")
        LINK_TARGET="${PROJECTDIR_TO_REQFILESDIR_REL}/${F_BASENAME}"
        LINK_NAME="${PROJECTDIR}/${F_BASENAME}"
        if [ -e "${LINK_NAME}" ] ; then 
            # if file exists (tested actual file, not symbolic link)
            continue
        fi
        echo "linking ${LINK_TARGET}"
        ln -s "${LINK_TARGET}" "${LINK_NAME}"
    done
done
