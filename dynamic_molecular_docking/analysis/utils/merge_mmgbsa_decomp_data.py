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
import scipy.stats
import matplotlib.pyplot as plt


logging.basicConfig(
    format='%(asctime)s:%(msecs)05.1f  %(levelname)s: %(message)s',
    datefmt='%H:%M:%S')
log = logging.getLogger()
log.setLevel(logging.DEBUG)


BOUND_FILTER_DELTA_G_HIGHEST = -20
BOUND_FILTER_DELTA_G_TOP_FRACTION = 0.2


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('outdir')
    parser.add_argument('binding_data_file', metavar='binding-data-file', )
    args = parser.parse_args()
    print args

    if os.path.exists(args.outdir):
        sys.exit("Output dir already exists: %s" % args.outdir)

    os.mkdir(args.outdir)
    logfilepath = os.path.join(
        args.outdir, "%s.log" % os.path.basename(sys.argv[0]))
    fh = logging.FileHandler(logfilepath, encoding='utf-8')
    fh.setLevel(logging.DEBUG)
    log.addHandler(fh)

    # Get MMPBSA binding data from external file. This file contains data
    # for all DMD runs, it correlates run ID with binding energy.
    # Store data in pandas DataFrame.
    log.info("Read '%s'." % args.binding_data_file)
    binding_data = pd.read_csv(
        args.binding_data_file,
        index_col='run_id')
    # Isolate delta G column (pandas Series), can later easily be indexed with
    # run ID.
    mmpbsa_deltag = binding_data['mmpbsa_freemdlast250frames_deltag']

    # Read decomp data files (one per DMD run).
    decomp_data_frames = []
    for filepath in sys.stdin:
        filepath = filepath.strip()
        if not os.path.isfile(filepath):
            log.error("No such file: '%s'" % filepath)
        else:
            log.debug("Processing '%s'" % filepath)
            decomp_data_frames.append(process_single_decomp_file(filepath))
            # Modify dataframe object on the fly, note down DMD run id as well
            # as MM-PBSA deltaG.
            rid = run_id_from_path(filepath)
            decomp_data_frames[-1]._dmd_run_id = rid
            decomp_data_frames[-1]._mmpbsa_deltag = mmpbsa_deltag[rid]
    log.info("Read in %s data sets (files)." % len(decomp_data_frames))

    merged_data, nbr_datasets_for_merge = merge_all_runs_if_bound(
        decomp_data_frames, mmpbsa_deltag)
    plot_top_residues(merged_data, nbr_datasets_for_merge)


def plot_top_residues(merged_data, nbr_datasets_for_merge):
    merged_data_sorted = merged_data.sort([('total_mean','mean')])
    print_N = 10
    plot_N = 6
    log.info("Top %s of residues by averaged contribution to binding:\n%s",
        print_N, merged_data_sorted.head(print_N)['total_mean'])
    df_for_plot = merged_data_sorted.head(plot_N)

    plt.errorbar(
        x=range(plot_N),
        y=df_for_plot[('total_mean','mean')].values,
        yerr=df_for_plot[('total_mean','sem')].values,
        linestyle='None',
        linewidth=1.5,
        color='black',
        marker='o', mfc='black',
        markersize=7, capsize=7)
    # Dataframe index contains the location names, build proper strings.
    residue_names = ["_".join(loc.split()[1:]) for loc in df_for_plot.index.values]
    plt.xticks(
        range(plot_N),
        residue_names,
        rotation=45,
        fontsize=12)
    plt.xlim([-1, plot_N])
    plt.xlabel('Residue',  fontsize=16)
    plt.ylabel(u'$\\langle \mathrm{\Delta G} \\rangle$ [kcal/mol]',  fontsize=16)
    plt.title('MM-GBSA SRED, averaged over %s DMD runs' % nbr_datasets_for_merge)
    #pylab.legend(numpoints=1)
    plt.tight_layout()
    #pylab.savefig("clustering_dmd_vs_ad3_plots_pub.pdf")
    #pylab.savefig("clustering_dmd_vs_ad3_plots_pub.png")
    plt.show()


def merge_all_runs_if_bound(decomp_data_frames, mmpbsa_deltag):
    # Merge decomp data of (at least weakly) bound systems.

    log.info(("Filter top fraction (%.2f) of decomp data by MM-PBSA "
        "delta G."), BOUND_FILTER_DELTA_G_TOP_FRACTION)
    top_n = int(round(
        BOUND_FILTER_DELTA_G_TOP_FRACTION * len(decomp_data_frames)))
    log.info("-> extract top %s.", top_n)

    #log.info("Filter runs with MMPBSA delta G smaller than %s kcal/mol." %
    #    BOUND_FILTER_DELTA_G_HIGHEST)
    #dataframes = [df for df in decomp_data_frames if
    #    mmpbsa_deltag[df._dmd_run_id] < BOUND_FILTER_DELTA_G_HIGHEST]

    dframes_sorted_by_mmpbsa_deltag_first_best = sorted(
        decomp_data_frames, key=lambda x: x._mmpbsa_deltag)
    log.info("MM-PBSA delta G of rank 1: %.2f kcal/mol",
        dframes_sorted_by_mmpbsa_deltag_first_best[0]._mmpbsa_deltag)
    log.info("MM-PBSA delta G of rank %s: %.2f kcal/mol", top_n,
        dframes_sorted_by_mmpbsa_deltag_first_best[top_n-1]._mmpbsa_deltag)
    dframes_for_merge = dframes_sorted_by_mmpbsa_deltag_first_best[:top_n]
    nbr_datasets_for_merge = len(dframes_for_merge)
    log.info("Data of %s DMD runs fulfill criterion." % nbr_datasets_for_merge)

    # Remove ligand data from data sets.
    for idx, df in enumerate(dframes_for_merge[:]):
        receptor_filter = df['location'].map(lambda x: x.startswith('R'))
        dframes_for_merge[idx] = df[receptor_filter]

    dframes_for_merge_receptor_only = [
        df[df['location'].map(lambda x: x.startswith('R'))] for df in
            dframes_for_merge]

    merged_data = merge_dataframes_by_location(dframes_for_merge_receptor_only)
    log.info("Shape of merged data: %s.", merged_data.shape)
    log.info("Merged data for %s residues.", len(merged_data.index))
    return merged_data, nbr_datasets_for_merge


def merge_dataframes_by_location(dataframes):
    # http://stackoverflow.com/a/15135546/145400
    # http://pandas.pydata.org/pandas-docs/stable/groupby.html
    # http://stackoverflow.com/questions/14733871/multi-index-sorting-in-pandas
    # https://github.com/pydata/pandas/issues/4370
    return pd.concat(
        dataframes,
        ignore_index=True).groupby(
            "location").agg([np.mean, np.std, scipy.stats.sem])


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
