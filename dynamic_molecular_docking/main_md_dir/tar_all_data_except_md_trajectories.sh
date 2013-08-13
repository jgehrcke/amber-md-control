#!/bin/bash

TARNAME="$1"

TIME=$(date +%y%m%d-%H%M%S)
ARCHIVENAME="dmd_md_dir_data_${TARNAME}_${TIME}.tar.gz"

tar cvzf $ARCHIVENAME * \
    --exclude='*.prmtop' \
    --exclude='*.crd' \
    --exclude='*.rst' \
    --exclude='*.tar.gz' \
    --exclude='*.mdcrd*' \
    --exclude='_MMPBSA_*' \
    --exclude='slurm*outerr' | \
    tee ${ARCHIVENAME}.log

