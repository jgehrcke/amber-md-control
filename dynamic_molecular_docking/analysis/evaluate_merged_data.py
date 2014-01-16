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
from scipy.stats import pearsonr, spearmanr, kendalltau
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
    parser.add_argument("perrundatafile")
    parser.add_argument("--corrpdffile",
        default="metrics_correlations.pdf")
    OPTIONS = parser.parse_args()

    if not os.path.isfile(OPTIONS.perrundatafile):
        sys.exit("Not a file: %s" % OPTIONS.perrundatafile)

    # Read data table (rows: run ids, columns: metrics)
    data = pd.read_csv(OPTIONS.perrundatafile, index_col="run_id")

    corr_metrics = (
        (
            ('hbonds_freemd_avg_number_last250frames_mean', 1),
            ('mmpbsa_freemdlast250frames_deltag', 'kcal/mol'),
        ),
        (
            ('hbonds_freemd_avg_number_last250frames_mean', 1),
            ('mmgbsa_freemdlast250frames_deltag', 'kcal/mol'),
        ),
        (
            ('mov_freemd_last250frames_ligrecrelmov_stddev', 'Å'),
            ('mmpbsa_freemdlast250frames_deltag', 'kcal/mol'),
        ),
        (
            ('mov_freemd_last250frames_liginternal_stddev', 'Å'),
            ('mmpbsa_freemdlast250frames_deltag', 'kcal/mol'),
        ),
        (
            ('lig_rec_avg_distance_after_freemd_min', 'Å'),
            ('mmpbsa_freemdlast250frames_deltag', 'kcal/mol'),
        ),
        (
            ('mov_freemd_last250frames_ligrecrelmov_stddev', 'Å'),
            ('hbonds_freemd_avg_number_last250frames_mean', 1),
        ),
        (
            ('mov_freemd_last250frames_liginternal_stddev', 'Å'),
            ('hbonds_freemd_avg_number_last250frames_mean', 1),
        ),

        #'mov_freemd_last250frames_ligrecrelmov_mean',
        #('mov_freemd_last250frames_ligrecrelmov_stddev', 'Å'),
        #'mov_freemd_entire_ligrecrelmov_mean',
        #'mov_freemd_entire_ligrecrelmov_stddev',
        #'mov_freemd_last250frames_liginternal_mean',
        #('mov_freemd_last250frames_liginternal_stddev', 'Å'),
        #'mov_freemd_entire_liginternal_mean',
        #'mov_freemd_entire_liginternal_stddev',
        #('mmpbsa_freemdlast250frames_deltag', 'kcal/mol'),
        #'mmpbsa_freemdlast250frames_deltag_stddev',
        #('mmpbsa_freemdlast250frames_deltaeel', 'kcal/mol'),
        #'mmpbsa_freemdlast250frames_deltaeel_stddev',
        #('mmgbsa_freemdlast250frames_deltag', 'kcal/mol'),
        #'mmgbsa_freemdlast250frames_deltag_stddev',
        #'mmgbsa_freemdlast250frames_deltaeel',
        #'mmgbsa_freemdlast250frames_deltaeel_stddev',
        #('hbonds_freemd_avg_number_last250frames_mean', 1),
        #'hbonds_freemd_avg_number_last250frames_stddev',
        #('hbonds_freemd_avg_number_entiretraj_mean', 1),
        #'hbonds_freemd_avg_number_entiretraj_stddev',
        #('lig_rec_min_distance_after_freemd_min', 'Å'),
        #('lig_rec_avg_distance_after_freemd_min', 'Å'),
    )

    corrfigures = []
    for metric_a, metric_b in corr_metrics:
        corrfigures.append(create_correlation_graph(data, metric_a, metric_b))
    log.info("Correlations: Creating PDF file '%s' containing %s pages (figures)",
        OPTIONS.corrpdffile, len(corrfigures))
    pdffile = PdfPages(OPTIONS.corrpdffile)
    for fig in corrfigures:
        pdffile.savefig(fig)
    pdffile.close()


def create_correlation_graph(data, metric_a, metric_b):
    metric_a, metric_a_unit = metric_a
    metric_b, metric_b_unit = metric_b
    unitstring_a = "[%s]" % metric_a_unit if metric_a_unit != 1 else ""
    unitstring_b = "[%s]" % metric_b_unit if metric_b_unit != 1 else ""
    log.info("Create correlation graph for metrics '%s','%s'",
        metric_a, metric_b)
    # Correlate data.
    x = data[metric_a]
    y = data[metric_b]
    kendalltau_r, kendalltau_p = kendalltau(x, y)
    spearman_r, spearman_p = spearmanr(x, y)
    pearson_r, pearson_p = pearsonr(x, y)
    log.info("Spearman: r=%s, p=%s" % (spearman_r, spearman_p))
    log.info("Pearson: r=%s, p=%s" % (pearson_r, pearson_p))
    log.info("Kendall's tau: tau=%s, p=%s" % (kendalltau_r, kendalltau_p))
    fig = plt.figure()
    plt.plot(x, y, c="black", ls="None", marker="o")
    plt.xlabel("%s %s" % (metric_a, unitstring_a))
    plt.ylabel("%s %s" % (metric_b, unitstring_b))
    titlelines = []
    titlelines.append("'%s' vs.\n '%s'" % (metric_a, metric_b))
    titlelines.append("Value pairs: %s, Pearson r: %.2f, Spearman r: %.2f" % (
        len(x), pearson_r, spearman_r))
    plt.title("\n".join(titlelines), fontsize=10)
    return fig


if __name__ == "__main__":
    main()
