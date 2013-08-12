#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Copyright 2012-2013 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

import os
import sys
import cStringIO as StringIO
import logging
import argparse

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt


logging.basicConfig(
    format='%(asctime)s:%(msecs)05.1f  %(levelname)s: %(message)s',
    datefmt='%H:%M:%S')
log = logging.getLogger()
log.setLevel(logging.DEBUG)


BOUND_FILTER_DELTA_G_HIGHEST = -10



def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--outdir', required=True)
    parser.add_argument('--binding-data-file', required=True)
    args = parser.parse_args()

    if os.path.exists(args.outdir):
        sys.exit("Already exists: %s" % args.outdir)

    os.mkdir(args.outdir)
    logfilepath = os.path.join(
        args.outdir, "%s.log" % os.path.basename(sys.argv[0]))
    fh = logging.FileHandler(logfilepath, encoding='utf-8')
    fh.setLevel(logging.DEBUG)
    log.addHandler(fh)

    # Get MMPBSA binding data from external file. This file contains data
    # for all DMD runs.  Store data in pandas DataFrame.
    log.info("Read '%s'." % args.binding_data_file)
    binding_data = pd.read_csv(
        args.binding_data_file,
        index_col='run_id')
    # Isolate delta G column (pandas Series), can be indexed with run ID.
    mmpbsa_deltag = binding_data['mmpbsa_freemdlast250frames_deltag']

    # Read decomp data files (one per DMD run).
    decomp_data_frames = []
    nbr_processed_data_sets = 0
    for idx, filepath in enumerate(sys.stdin):
        filepath = filepath.strip()
        if not os.path.isfile(filepath):
            log.error("No such file: '%s'" % filepath)
        else:
            log.debug("Processing '%s'" % filepath)
            decomp_data_frames.append(process_single_decomp_file(filepath))
            # Modify dataframe object on the fly, note down DMD run id.
            decomp_data_frames[-1]._dmd_run_id = run_id_from_path(filepath)
            nbr_processed_data_sets += 1

    log.info("Read in %s data sets (files)." % nbr_processed_data_sets)

    merge_all_runs_if_bound(decomp_data_frames, mmpbsa_deltag)


def merge_all_runs_if_bound(decomp_data_frames, mmpbsa_deltag):
    # Merge decomp data of (at least weakly) bound systems.
    log.info("Filter runs with MMPBSA delta G smaller than %s kcal/mol." %
        BOUND_FILTER_DELTA_G_HIGHEST)
    dataframes = [df for df in decomp_data_frames if
        mmpbsa_deltag[df._dmd_run_id] < BOUND_FILTER_DELTA_G_HIGHEST]
    log.info("%s systems left." % len(dataframes))

    # Remove ligand data from data sets.
    for idx, df in enumerate(dataframes[:]):
        receptor_filter = df['location'].map(lambda x: x.startswith('R'))
        dataframes[idx] = df[receptor_filter]

    # http://stackoverflow.com/a/15135546/145400
    # http://pandas.pydata.org/pandas-docs/stable/groupby.html
    # http://stackoverflow.com/questions/14733871/multi-index-sorting-in-pandas
    # https://github.com/pydata/pandas/issues/4370

    merged_data = pd.concat(
        dataframes,
        ignore_index=True).groupby(
            "location").agg([np.mean, np.std])

    print merged_data.head()
    #sys.exit()
    print "averaged top 5"
    print merged_data.sort([('total_mean','mean')]).head()


    sys.exit()

    head1 = dataframes[0].head()

    head2 = dataframes[1].head()

    print "h1"
    print head1['estatic_mean']
    print "h2"
    print head2['estatic_mean']

    combination = pd.concat([head1, head2], ignore_index=True)
    #print combination



    print "GROPUPBY"
    print combination.groupby("location")

    avg = combination.groupby("location").agg([np.mean, np.std])
    print "average:"
    print avg['estatic_mean']




def evaluate_plot_data(decomp_data_frames):
    df = decomp_data_frames[0]
    receptor_filter = df['location'].map(lambda x: x.startswith('R'))
    df_receptor = df[receptor_filter]
    print df_receptor.sort('total_mean').iloc[:5]


def process_single_decomp_file(filepath):
    with open(filepath) as f:
        lines = f.readlines()
    # Get rid of the first 8 lines (comments, invalid header) and the last line
    # (empty) before parsing content with pandas.
    csv_buffer = StringIO.StringIO()
    csv_buffer.writelines(lines[8:-1])
    csv_buffer.seek(0)
    header_names = [
        "residue",
        "location",
        "internal_mean",
        "internal_stddev",
        "internal_stderr",
        "vdw_mean",
        "vdw_stddev",
        "vdw_stderr",
        "estatic_mean",
        "estatic_stddev",
        "estatic_stderr",
        "psolv_mean",
        "psolv_stddev",
        "psolv_stderr",
        "npsolv_mean",
        "npsolv_stddev",
        "npsolv_stderr",
        "total_mean",
        "total_stddev",
        "total_stderr"]
    df = pd.read_csv(csv_buffer, names=header_names, index_col='residue')
    return df


def run_id_from_path(p):
    integertokens = []
    for pathelement in p.split('/'):
        for token in pathelement.split('_'):
            if len(token) > 5:
                continue
            try:
                int(token)
                integertokens.append(token)
            except ValueError:
                pass
    if not len(integertokens) >= 2:
        sys.exit("At least two int tokens required in '%s'" % p)
    # Return run_id, e.g. '00001_05'
    return "_".join(integertokens[-2:])


if __name__ == "__main__":
    main()
