#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Copyright 2012-2013 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

import os
import sys
import logging
from collections import defaultdict
from itertools import izip
import argparse

import pandas as pd
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

logging.basicConfig(
    format='%(asctime)s:%(msecs)05.1f  %(levelname)s: %(message)s',
    datefmt='%H:%M:%S')
log = logging.getLogger()
log.setLevel(logging.INFO)


RECEPTOR_RESIDUE_FRACTIONS = defaultdict(list)
RESIDUE_PAIR_FRACTIONS = defaultdict(list)


MPLFONT = {
    'family': 'serif',
    'serif': 'Liberation Serif'}


matplotlib.rc('font', **MPLFONT)


def main():
    global options
    parser = argparse.ArgumentParser()
    parser.add_argument('--receptor-resnum-offset', type=int, default=0)
    parser.add_argument('outdir')
    options = parser.parse_args()

    output_dir = options.outdir
    if os.path.exists(output_dir):
        sys.exit("Already exists: %s" % output_dir)

    os.mkdir(output_dir)
    logfilepath = os.path.join(
        output_dir, "%s.log" % os.path.basename(sys.argv[0]))
    fh = logging.FileHandler(logfilepath, encoding='utf-8')
    fh.setLevel(logging.DEBUG)
    log.addHandler(fh)

    filepaths = (l.strip() for l in sys.stdin)

    nbr_processed_data_sets = 0
    for idx, fp in enumerate(filepaths):
        if not os.path.isfile(fp):
            log.error("No such file: '%s'" % fp)
        else:
            log.debug("Processing '%s'" % fp)
            process_single_avgout_file(fp)
            nbr_processed_data_sets += 1

    log.info("Processed %s data sets (files)." % nbr_processed_data_sets)
    evaluate_plot_data(nbr_processed_data_sets, output_dir)


# Quick'n'dirty residue name converter (implement numbering offset).
def loc_to_resname(loc):
    name, number = loc.split("_")
    shortname = RESNAMEMAP[name]
    return "%s%s" % (shortname, options.receptor_resnum_offset + int(number))


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
    }


def evaluate_plot_data(nbr_processed_data_sets, output_dir):
    # Fill 'holes' in data sets: A hole is a 0. Example:
    # 50 data sets (from 50 independent trajectories) have been read in.
    # For 30 of these trajectories, ARG_100 might have an H-bond occupancy
    # larger than 0. Then, its `fraction_list` entry contains 30 items. For
    # proper distribution analysis, 20 items with value 0 should be added.

    # For each receptor residue sum up fractions from all trajectories and
    # normalize. Fill 'holes' in this interation, too (see above).
    rec_residue_frac_normsums = dict()
    log.info("Normalizing data...")
    for donor_resname, fraction_list in RECEPTOR_RESIDUE_FRACTIONS.iteritems():
        rec_residue_frac_normsums[donor_resname] = sum(fraction_list) / \
            nbr_processed_data_sets
        nbr_holes = nbr_processed_data_sets - len(fraction_list)
        if nbr_holes:
            fraction_list.extend(nbr_holes*[0])

    #residue_pair_frac_normsums = dict()
    #for donac_string, fraction_list in RESIDUE_PAIR_FRACTIONS.iteritems():
    #    residue_pair_frac_normsums[donac_string] = sum(fraction_list) / \
    #        nbr_processed_data_sets

    # Convert dictionaries to pandas Series type and sort.
    rec_residue_frac_normsums_ser = pd.Series(rec_residue_frac_normsums)
    rec_residue_frac_normsums_ser = rec_residue_frac_normsums_ser.order(ascending=False)

    #residue_pair_fraction_sums = pd.Series(residue_pair_fraction_sums)
    #residue_pair_fraction_sums = residue_pair_fraction_sums.order(ascending=False)

    #print residue_pair_fraction_sums
    #print rec_residue_frac_normsums_ser

    # Extract data about most occupied/populated donor residues in receptor.
    top = 6
    mpop_resnames = rec_residue_frac_normsums_ser.index[:top]
    mpop_fractions_lists = [RECEPTOR_RESIDUE_FRACTIONS[n] for n in mpop_resnames]
    mpop_fractions_normsums = rec_residue_frac_normsums_ser[:top]

    log.info("Creating mean occupancy plot.")

    # Plot data about most occupied/populated donor residues in receptor.
    # First, plot normalized cumulative occupancy of single residues,
    # i.e. the time-average of occupancy over all input data
    # (many trajectories).
    plt.plot(
        mpop_fractions_normsums,
        linestyle='',
        linewidth=1.5,
        color='black',
        marker='o', mfc='black',
        markersize=10)
    plt.xlim([-1, top])
    #plt.title("Normalized H-bond occupancy from %s trajectories" %
    #   nbr_processed_data_sets)
    plt.xticks(
        range(top),
        mpop_resnames,
        #rotation=45,
        fontsize=10)
    plt.ylabel('Normalized H-bond occupancy')
    plt.xlabel('Residue')
    plt.tight_layout()
    p = os.path.join(output_dir, "normalized_occupancy_top.pdf")
    plt.savefig(p)
    p = os.path.join(output_dir, "normalized_occupancy_top.png")
    plt.savefig(p, dpi=200)

    log.info("Creating mean occupancy plot (box plot).")
    # Now plot the same thing, but as boxplot indicating the distribution
    # leading to the mean values used above.
    plt.figure()
    plt.boxplot(mpop_fractions_lists)
    #plt.title("H-bond occupancy distribution from %s trajectories" % nbr_processed_data_sets)
    plt.xticks(
        range(1, top+1),
        mpop_resnames,
        #rotation=45,
        fontsize=10)
    plt.ylabel('H-bond occupancy per trajectory')
    plt.xlabel('Residue')
    plt.tight_layout()
    p = os.path.join(output_dir, "occupancy_boxplots_top.pdf")
    plt.savefig(p)
    p = os.path.join(output_dir, "occupancy_boxplots_top.png")
    plt.savefig(p, dpi=200)

    log.info("Creating single-residue occupancy plots (histograms).")
    # Now plot the exact distributions as histograms for each mean value above.
    figures_resnames = []
    #xlims_lower = []
    #xlims_upper = []
    ylims_lower = []
    ylims_upper = []
    for mpop_resname, mpop_fractions_list in zip(mpop_resnames, mpop_fractions_lists):
        figures_resnames.append((mpop_resname, plt.figure()))
        #plt.title("H-bond occupancy distribution per trajectory for %s" % mpop_resname)
        #plt.hist(mpop_fractions_list, bins=10, label=mpop_resname)
        log.debug("Number of data points for residue %s: %s" % (mpop_resname, len(mpop_fractions_list)))
        plt.hist(
            mpop_fractions_list,
            bins=np.linspace(0, 4, 15),
            label=mpop_resname)
        plt.xlabel('H-bond occupancy among an entire trajectory')
        plt.ylabel('Number of trajectories')
        xmin, xmax, ymin, ymax = plt.axis()
        #xlims_lower.append(xmin)
        #xlims_upper.append(xmax)
        ylims_upper.append(ymax)
        ylims_lower.append(ymin)

    #xmax = max(xlims_upper)
    #xmin = min(xlims_lower)
    ymax = max(ylims_upper)
    ymin = min(ylims_lower)

    for resname, fig in figures_resnames:
        # Set current figure.
        plt.figure(fig.number)
        plt.axis([0, 4, ymin, ymax])
        #plt.axis([xmin, xmax, ymin, ymax])
        plt.legend(loc='upper right', frameon=False)
        #ax = fig.get_axes()
        #ax.set_xlim(xmin, xmax)
        #ax.set_ylim(ymin, ymax)
        plt.tight_layout()
        p = os.path.join(output_dir, "occupancy_histogram_%s.pdf" % resname)
        plt.savefig(p)
        p = os.path.join(output_dir, "occupancy_histogram_%s.png" % resname)
        plt.savefig(p, dpi=200)


def process_single_avgout_file(hbond_cpptraj_avgout_filepath):
    # Read in panda DataFrame:
    df = pd.read_csv(hbond_cpptraj_avgout_filepath, delim_whitespace=True)

    # I am not interested in atomic resolution, just in sidechain resolution.
    # Arginines, for example can donate multiple hyrogen bonds.
    # In order to neglect atomic resolution, sum up fractions for atoms within
    #   - single receptor residues
    #   - ligand/receptor residue pairs
    #
    receptor_residue_fractions_singlefile = defaultdict(list)
    residue_pair_fractions_singlefile = defaultdict(list)
    for acceptor, donor, fraction in izip(df['#Acceptor'], df.Donor, df.Frac):
        # split ARG_107@NH1
        donor_resname = donor.split("@")[0]
        # Implment numbering offset.
        donor_resname = loc_to_resname(donor_resname)
        acceptor_resname = acceptor.split("@")[0]
        donac_string = "%s-%s" % (donor_resname, acceptor_resname)
        receptor_residue_fractions_singlefile[donor_resname].append(fraction)
        residue_pair_fractions_singlefile[donac_string].append(fraction)

    # Sum up fractions (lose atomic resolution), update global dicts.
    for donor_resname, fraction_list in receptor_residue_fractions_singlefile.iteritems():
        RECEPTOR_RESIDUE_FRACTIONS[donor_resname].append(sum(fraction_list))
        #if sum(fraction_list) > 3:
        #    log.info("fraction sum larger 3: %s" % hbond_cpptraj_avgout_filepath)

    for donac_string, fraction_list in residue_pair_fractions_singlefile.iteritems():
        RESIDUE_PAIR_FRACTIONS[donac_string].append(sum(fraction_list))


if __name__ == "__main__":
    main()

