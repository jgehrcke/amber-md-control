#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Copyright 2012-2014 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

import os
import sys
import cStringIO as StringIO
import logging
import argparse

import pandas as pd
import numpy as np
import scipy.stats

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

logging.basicConfig(
    format='%(asctime)s:%(msecs)05.1f  %(levelname)s: %(message)s',
    datefmt='%H:%M:%S')
log = logging.getLogger()
log.setLevel(logging.DEBUG)


MPLFONT = {
    'family': 'serif',
    'serif': 'Liberation Serif',
    'size': 10,
    }


matplotlib.rc('font', **MPLFONT)

RESNAMEMAP = {
    "ARG": "R",
    "LYS": "K",
    "ASN": "N",
    "THR": "T",
    "GLN": "Q",
    "HIS": "H",
    "GLY": "G",
    "VAL": "V",
    "ARG": "R",
    "SER": "S",
    "ASP": "D",
    "HIE": "H",
    "HIS": "H",
    "TYR": "Y",
    "HIS": "H",
    "TRP": "W",
    "PHE": "F",
    "CYX": "C",
    "CYS": "C",
    "GLU": "E",
    "ILE": "I",
    "MET": "M",
    "LEU": "L",
    "PRO": "P",
    "ALA": "A",
    }


#BOUND_FILTER_DELTA_G_HIGHEST = -20
BOUND_FILTER_DELTA_G_TOP_FRACTION = 0.4
options = None

def main():
    global options
    parser = argparse.ArgumentParser()
    parser.add_argument('--receptor-resnum-offset', default=0)
    parser.add_argument('outdir')
    parser.add_argument('binding_data_file', metavar='binding-data-file', )
    options = parser.parse_args()

    options.receptor_resnum_reset = None
    options.receptor_resnum_reset_offset = None
    if options.receptor_resnum_offset:
        tokens = options.receptor_resnum_offset.split("/")
        if len(tokens) == 1:
            options.receptor_resnum_offset = int(tokens[0])
        elif len(tokens) != 3:
            sys.exit("receptor-resnum-offset must be 1 or 3 tokens.")
        else:
            # Let normal offset be offset "A".
            # From and including residue number `reset`, apply offset B.
            options.receptor_resnum_offset = int(tokens[0])
            options.receptor_resnum_reset = int(tokens[1])
            options.receptor_resnum_reset_offset = int(tokens[2])

    log.info("Resnum offset/reset/reset-offset: %s, %s, %s",
        options.receptor_resnum_offset,
        options.receptor_resnum_reset,
        options.receptor_resnum_reset_offset)

    if os.path.exists(options.outdir):
        sys.exit("Output dir already exists: %s" % options.outdir)

    os.mkdir(options.outdir)
    logfilepath = os.path.join(
        options.outdir, "%s.log" % os.path.basename(sys.argv[0]))
    fh = logging.FileHandler(logfilepath, encoding='utf-8')
    fh.setLevel(logging.DEBUG)
    log.addHandler(fh)

    # Get MMPBSA binding data from external file. This file contains data
    # for all DMD runs, it correlates run ID with binding energy.
    # Store data in pandas DataFrame.
    log.info("Read '%s'." % options.binding_data_file)
    binding_data = pd.read_csv(
        options.binding_data_file,
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
            try:
                decomp_data_frames[-1]._mmpbsa_deltag = mmpbsa_deltag[rid]
            except KeyError:
                log.error("Cannot retrieve dG for %s. Skip SRED data.", rid)
                decomp_data_frames.pop()
    log.info("Proccessed %s input data files." % len(decomp_data_frames))

    log.info("Filter and merge data for receptor residues.")
    merged_data_receptor, nbr_datasets_for_merge = merge_all_runs_if_bound(
        decomp_data_frames,
        locationfilter=lambda x: x.startswith('R'))
    log.info("Filter and merge data for ligand residues.")
    merged_data_ligand, nbr_datasets_for_merge = merge_all_runs_if_bound(
        decomp_data_frames,
        locationfilter=lambda x: x.startswith('L'))
    plot_top_residues(
        merged_data_receptor,
        nbr_datasets_for_merge,
        reclig='receptor')
    plot_top_residues(
        merged_data_ligand,
        nbr_datasets_for_merge,
        reclig='ligand')


def plot_top_residues(
        merged_data,
        nbr_datasets_for_merge,
        reclig):
    merged_data_sorted = merged_data.sort([('total_mean','mean')])
    print_N = 10
    plot_N = 6
    if plot_N > len(merged_data_sorted):
        # There might be less residues in the receptor/ligand than defined
        # above. In this case deviate from the default.
        plot_N = len(merged_data_sorted)
    log.info("Top %s of %s residues by averaged contribution to binding:\n%s",
        print_N, reclig, merged_data_sorted.head(print_N)['total_mean'])
    df_for_plot = merged_data_sorted.head(plot_N)

    log.info("Creating new figure.")
    fig = plt.figure()
    
    # Adjust to text width of LaTeX document.
    fig.set_size_inches(4.67, 4.67*3.0/4)
        
    plt.errorbar(
        x=range(plot_N),
        y=df_for_plot[('total_mean','mean')].values,
        yerr=df_for_plot[('total_mean','sem')].values,
        linestyle='None',
        linewidth=1.1,
        color='black',
        marker='o', mfc='black',
        markersize=5, capsize=5)


    # Dataframe index contains the location names, build proper strings.
    def loc_to_resname(loc):
        r_or_l, name, number = loc.split()
        if r_or_l == "L":
            return "%s %s" % (name, number)

        oldnumber = int(number)

        # Apply suffix only if reset has been specified.
        suffix = ""
        if options.receptor_resnum_reset:
            if oldnumber < options.receptor_resnum_reset:
                newnumber = oldnumber + options.receptor_resnum_offset
                suffix = "a"
            else:
                newnumber = oldnumber + options.receptor_resnum_reset_offset
                suffix = "b"
        else:
            newnumber = oldnumber + options.receptor_resnum_offset

        shortname = RESNAMEMAP[name]
        return "%s%s%s" % (shortname, newnumber, suffix)


    residue_names = [loc_to_resname(loc) for loc in df_for_plot.index.values]
    plt.xticks(
        range(plot_N),
        residue_names,
        #rotation=45
        )
    plt.xlim([-1, plot_N])
    if residue_names[0][1].isdigit():
        # Define y limit (mainly for thesis plots, remove afterwards...).
        # Do only for receptor (via isdigit hack, cause ligand resnames are 3 letters).
        print "JA KLAR IST DAS DABEI"
        plt.ylim([-16, 0])
    plt.xlabel('%s residue' % reclig)
    plt.ylabel(
        u'$\\langle \mathrm{\Delta G} \\rangle$ [kcal/mol]')
    frac_percent = int(100 * BOUND_FILTER_DELTA_G_TOP_FRACTION)
    #plt.title(("MM-GBSA SRED (%s), averaged over %s DMD runs\n"
    #    "(top %s %% of decomp data by MM-PBSA delta G)") % (
    #    reclig, nbr_datasets_for_merge, frac_percent))
    plt.tight_layout()
    outfile_name_prefix = "%s_top%s_residues_of_top_%spercent_dmd_runs" % (
        reclig, plot_N, frac_percent)
    outfile_path_prefix = os.path.join(options.outdir, outfile_name_prefix)
    pdfp = "%s.pdf" % outfile_path_prefix
    pngp = "%s.png" % outfile_path_prefix
    svgp = "%s.svg" % outfile_path_prefix
    log.info("(Over)writing %s", pdfp)
    plt.savefig(pdfp)
    log.info("(Over)writing %s", svgp)
    plt.savefig(svgp)
    log.info("(Over)writing %s", pngp)
    plt.savefig(pngp, dpi=250)
    plt.close(fig)
    #plt.show()


def merge_all_runs_if_bound(decomp_data_frames, locationfilter):
    # Merge decomp data of (at least weakly) bound systems.

    log.info(("Filter top fraction (%.2f) of decomp data by MM-PBSA "
        "delta G."), BOUND_FILTER_DELTA_G_TOP_FRACTION)
    top_n = int(round(
        BOUND_FILTER_DELTA_G_TOP_FRACTION * len(decomp_data_frames)))
    log.info("-> extract top %s.", top_n)

    dframes_sorted_by_mmpbsa_deltag_first_best = sorted(
        decomp_data_frames, key=lambda x: x._mmpbsa_deltag)
    log.info("MM-PBSA delta G of rank 1: %.2f kcal/mol",
        dframes_sorted_by_mmpbsa_deltag_first_best[0]._mmpbsa_deltag)
    log.info("MM-PBSA delta G of rank %s: %.2f kcal/mol", top_n,
        dframes_sorted_by_mmpbsa_deltag_first_best[top_n-1]._mmpbsa_deltag)
    dframes_for_merge = dframes_sorted_by_mmpbsa_deltag_first_best[:top_n]
    nbr_datasets_for_merge = len(dframes_for_merge)

    # Filter single data 'rows' by location using `locationfilter`.
    dframes_for_merge_locfiltered = [
        df[df['location'].map(locationfilter)] for df in
            dframes_for_merge]

    merged_data = merge_dataframes_by_location(dframes_for_merge_locfiltered)
    log.info("Shape of merged and location-filtered data: %s.",
        merged_data.shape)
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
