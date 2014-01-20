#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Copyright 2012-2014 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

from __future__ import unicode_literals

import os
import sys
import logging
import argparse
import shutil
import glob

import pandas as pd
import numpy as np


# Extract top solutions by MMPBSA, hbonds, ... bla bla
# Create directory 'top_solutions'
# Create subdirectories by criterion (e.g. "mmpbsa", ...)
# Fill these directories with PDB files from pdbfiledir


logging.basicConfig(
    format='%(asctime)s:%(msecs)05.1f  %(levelname)s: %(message)s',
    datefmt='%H:%M:%S')
log = logging.getLogger()
log.setLevel(logging.DEBUG)


OPTIONS = None


def main():
    global OPTIONS
    parser = argparse.ArgumentParser()
    parser.add_argument("perrundatafile")
    parser.add_argument("pdbfiledir")
    parser.add_argument("--outputdir", default="top_solutions")
    parser.add_argument("--top", type=int, default=5)
    OPTIONS = parser.parse_args()

    if not os.path.isdir(OPTIONS.pdbfiledir):
        sys.exit("Not a directory (pdbfiledir): '%s'" % OPTIONS.pdbfiledir)

    if not os.path.isfile(OPTIONS.perrundatafile):
        sys.exit("Not a file: %s" % OPTIONS.perrundatafile)

    if os.path.isdir(OPTIONS.outputdir):
        if OPTIONS.outputdir.startswith("/"):
            log.error("Output dir '%s' exists and starts with slash, exit.",
                OPTIONS.outputdir)
            sys.exit(1)
        log.warning("Output directory '%s' exists, deleting it.",
            OPTIONS.outputdir)
        shutil.rmtree(OPTIONS.outputdir)
    os.mkdir(OPTIONS.outputdir)

    pdbpaths = glob.glob("%s/*.pdb" % OPTIONS.pdbfiledir)
    log.info("Found %s PDB files in '%s'", len(pdbpaths),
        OPTIONS.pdbfiledir)

    data = pd.read_csv(OPTIONS.perrundatafile, index_col="run_id")

    # Define metric names, metric units, and order (ascending (lower
    # is better) or descending).
    metrics = (
        ('mov_freemd_last250frames_liginternal_stddev', 'Å', 'asc'),
        ('mmpbsa_freemdlast250frames_deltag', 'kcal/mol', 'asc'),
        ('hbonds_freemd_avg_number_last250frames_mean', 1, 'desc'),
        ('lig_rec_avg_distance_after_freemd_min', 'Å', 'asc'),
    )

    for m in metrics:
        metric_name, metric_unit, metric_order = m
        top_runids = top_runids_for_metric(metric_name, metric_order, data)
        copy_pdbfiles_to_topdir(top_runids, metric_name, pdbpaths)


def top_runids_for_metric(metric_name, metric_order, data):
    log.info("Retrieving top run IDs for metric '%s'", metric_name)
    if not metric_name in data:
        log.warning("metric '%s' not contained in dataset. Skip.", metric_name)
        return
    ascending = True if metric_order == "asc" else False
    sorted_data = data.sort(metric_name, ascending=ascending)
    top_data = sorted_data[:OPTIONS.top]
    log.debug("Top data values:\n%s", top_data[metric_name])
    top_runids = top_data.index.values
    log.info("Top run IDs:\n%s", top_runids)
    return top_runids


def copy_pdbfiles_to_topdir(run_ids, metric_name, pdbpaths):
    target_dir = os.path.join(OPTIONS.outputdir, metric_name)
    if not os.path.isdir(target_dir):
        os.mkdir(target_dir)
    top_pdbpaths = []
    for run_id in run_ids:
        top_pdbpaths.extend(
            p for p in pdbpaths if (os.path.basename(p).startswith(run_id)))
    log.debug("Top PDB paths:\n%s", "\n".join(top_pdbpaths))
    for p in top_pdbpaths:
        target_filepath = os.path.join(target_dir, os.path.basename(p))
        log.debug("Copy '%s' to '%s'", p, target_filepath)
        shutil.copy(p, target_filepath)


if __name__ == "__main__":
    main()
