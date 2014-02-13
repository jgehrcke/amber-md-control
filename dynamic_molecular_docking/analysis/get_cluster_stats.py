#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Copyright 2012-2014 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

from __future__ import unicode_literals

import os
import sys
import cStringIO as StringIO
import logging
import argparse

import pandas as pd
import numpy as np
import scipy.stats
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages


logging.basicConfig(
    format='%(asctime)s:%(msecs)05.1f  %(levelname)s: %(message)s',
    datefmt='%H:%M:%S')
log = logging.getLogger()
log.setLevel(logging.DEBUG)

OPTIONS = None


def main():
    global OPTIONS
    parser = argparse.ArgumentParser()
    parser.add_argument("clusterdir")
    parser.add_argument("perrundatafile")
    parser.add_argument("--bins", type=int, default=20)
    parser.add_argument("--histogrampdffile",
        default="cluster_metrics_histograms.pdf")
    OPTIONS = parser.parse_args()

    if not os.path.isdir(OPTIONS.clusterdir):
        sys.exit("Not a directory: %s" % OPTIONS.clusterdir)

    if not os.path.isfile(OPTIONS.perrundatafile):
        sys.exit("Not a file: %s" % OPTIONS.perrundatafile)

    run_ids = get_run_ids_for_cluster_structures(OPTIONS.clusterdir)
    create_histograms(run_ids)


def create_histograms(cluster_run_ids):
    """
    For each quantity in per-run-date file, create a histogram of the
    distribution of values and highlight those values corresponding to the
    cluster members.
    """
    metrics = (
        #'mov_freemd_last250frames_ligrecrelmov_mean',
        ('mov_freemd_last250frames_ligrecrelmov_stddev', 'Å'),
        #'mov_freemd_entire_ligrecrelmov_mean',
        #'mov_freemd_entire_ligrecrelmov_stddev',
        #'mov_freemd_last250frames_liginternal_mean',
        ('mov_freemd_last250frames_liginternal_stddev', 'Å'),
        #'mov_freemd_entire_liginternal_mean',
        #'mov_freemd_entire_liginternal_stddev',
        ('mmpbsa_freemdlast250frames_deltag', 'kcal/mol'),
        #'mmpbsa_freemdlast250frames_deltag_stddev',
        ('mmpbsa_freemdlast250frames_deltaeel', 'kcal/mol'),
        #'mmpbsa_freemdlast250frames_deltaeel_stddev',
        ('mmgbsa_freemdlast250frames_deltag', 'kcal/mol'),
        #'mmgbsa_freemdlast250frames_deltag_stddev',
        #'mmgbsa_freemdlast250frames_deltaeel',
        #'mmgbsa_freemdlast250frames_deltaeel_stddev',
        ('hbonds_freemd_avg_number_last250frames_mean', 1),
        #'hbonds_freemd_avg_number_last250frames_stddev',
        ('hbonds_freemd_avg_number_entiretraj_mean', 1),
        #'hbonds_freemd_avg_number_entiretraj_stddev',
        ('lig_rec_min_distance_after_freemd_min', 'Å'),
        ('lig_rec_avg_distance_after_freemd_min', 'Å'),
    )

    # Read data table (rows: run ids, columns: metrics)
    data = pd.read_csv(OPTIONS.perrundatafile, index_col="run_id")

    histfigures = []
    for metric, unit in metrics:
        if not metric in data:
            log.warning("metric '%s' not contained in dataset. Skip.", metric)
            continue
        histfigures.append(
            create_histogram_for_metric(data, metric, unit, cluster_run_ids))

    # `histfiles` now contains a couple of matplotlib Figure objects.
    # Create a PDF file with these figures, whereas each figure goes to a
    # new page.
    log.info("Creating PDF file '%s' containing %s pages (figures)",
        OPTIONS.histogrampdffile, len(histfigures))
    pdffile = PdfPages(OPTIONS.histogrampdffile)
    for fig in histfigures:
        pdffile.savefig(fig)
    pdffile.close()


def create_histogram_for_metric(data, metric, unit, cluster_run_ids):
    log.info("Creating histogram for metric '%s'", metric)

    # Bin data, yielding
    #   `histvalues`: the number of items per bin (left to right)
    #   `binedges`: the edges of bins (left to right, len(bins)+1 elements)
    N_values = len(data[metric])
    log.debug("N data values: %s", N_values)
    #log.debug("data: %s", data[metric])
    if np.any(pd.isnull(data[metric])):
        log.warning("Data contains invalid value(s) (NaN, None, inf, ...).")
        log.debug("data: %s", data[metric])
        #sys.exit(1)
    log.debug("data[%s] min: %.3f", metric, np.min(data[metric]))
    log.debug("data[%s] max: %.3f", metric, np.max(data[metric]))
    histvalues, binedges = np.histogram(data[metric], bins=OPTIONS.bins)
    log.debug("Histogram (counts): %s", histvalues)
    # Calculate properties for later plotting.
    width = 1.0 * (binedges[1] - binedges[0])
    centers = (binedges[:-1] + binedges[1:]) / 2

    # For the current metric, extract those values corresponding to the
    # cluster (defined by `cluster_run_ids`).
    clusterdatavalues = [data[metric][r] for r in cluster_run_ids]
    # Find bins corresponding to cluster values, using numpy's digitize:
    # >>> my_list = [3,2,56,4,32,4,7,88,4,3,4]
    # >>> bins = [0,20,40,60,80,100]
    # >>> np.digitize(my_list,bins)
    # array([1, 1, 3, 1, 2, 1, 1, 5, 1, 1, 1])

    # https://github.com/numpy/numpy/issues/4217
    binedges[-1] += 10**-5
    bin_indices = np.digitize(clusterdatavalues, binedges)

    # Create a list of colors, same length as histvalues. One color for each
    # histogram bar. Use a default color (blue) and a special color for those
    # bars (bins) that contain at least one data values corresponding to one
    # docking solution in the selected cluster (as given by cluster_run_ids).
    # bin 1 (as in `bin_indices` as returned by `digitize`) is actually the bin
    # with index zero with respect to lists `colors` and `histvalues`.
    # Special values in `bin_indices` (0 and len(bins)) are
    # impossible to happen, since all binned values in the above call to
    # `digitize` were used to create the bins handed to `digitize` -- no value
    # will be out of range, which is what the 0 and len(bins) values would be
    # used for. Hence, correction of indices by -1 is safe, in order to
    # achieve matching between `bin_indices` on the one side and `colors` and
    # `histvalues` on the other side.
    bin_indices = bin_indices - 1
    colors = ["blue" for _ in histvalues]
    for specialbin in bin_indices:
        colors[specialbin] = "red"
    log.debug("Color array: %s", colors)

    fig = plt.figure()
    plt.bar(
        centers,
        histvalues,
        align='center',
        width=width,
        color=colors)
    t = "distribution of X in DMD solution ensemble (bins containing cluster values: red)\n"
    t += "ensemble size: %s, cluster dir: '%s', cluster size: %s" % (
        N_values,
        os.path.basename(os.path.normpath(OPTIONS.clusterdir)),
        len(cluster_run_ids))
    plt.title(t, fontsize=11)
    mean = np.mean(clusterdatavalues)
    std = np.std(clusterdatavalues)
    unitstring = "[%s]" % unit if unit != 1 else ""
    label = "cluster avg +/- std: (%.2f +/- %.2f) %s" % (mean, std, unitstring)
    plt.text(0.5, 0.95, label,
        fontsize=10,
        transform=plt.gca().transAxes,
        horizontalalignment='center')
    plt.xlabel("X (%s) %s" % (metric, unitstring))
    plt.ylabel("count")
    return fig


def get_run_ids_for_cluster_structures(clusterdir):
    return [run_id_from_filename(f) for f in os.listdir(clusterdir)]


def run_id_from_filename(f):
    # Expect filename of the form
    # '0001_26-freemd_finalstate_aftermin_aligned_ligand.pdb'
    run_id= f.split("-")[0]
    # Some validation
    a, b = run_id.split("_")
    for s in (a, b):
        assert is_intstring(s)
    return run_id


def is_intstring(s):
    try:
        int(s)
        return True
    except ValueError:
        return False


if __name__ == "__main__":
    main()
