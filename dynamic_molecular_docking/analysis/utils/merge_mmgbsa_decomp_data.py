#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Copyright 2012-2013 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

import os
import sys
import cStringIO as StringIO
import logging
from collections import defaultdict
from itertools import izip

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt


logging.basicConfig(
    format='%(asctime)s:%(msecs)05.1f  %(levelname)s: %(message)s',
    datefmt='%H:%M:%S')
log = logging.getLogger()
log.setLevel(logging.DEBUG)


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


def main():
    output_dir = sys.argv[1]
    if os.path.exists(output_dir):
        sys.exit("Already exists: %s" % output_dir)

    os.mkdir(output_dir)
    logfilepath = os.path.join(
        output_dir, "%s.log" % os.path.basename(sys.argv[0]))
    fh = logging.FileHandler(logfilepath, encoding='utf-8')
    fh.setLevel(logging.DEBUG)
    log.addHandler(fh)

    if len(sys.argv) > 2:
        filepaths = sys.argv[2:]
    else:
        filepaths = (l.strip() for l in sys.stdin)

    decomp_data_frames = []
    nbr_processed_data_sets = 0
    for idx, fp in enumerate(filepaths):
        if not os.path.isfile(fp):
            log.error("No such file: '%s'" % fp)
        else:
            log.debug("Processing '%s'" % fp)
            decomp_data_frames.append(process_single_decomp_file(fp))
            nbr_processed_data_sets += 1
            break

    log.info("Processed %s data sets (files)." % nbr_processed_data_sets)
    evaluate_plot_data(decomp_data_frames)


def evaluate_plot_data(decomp_data_frames):
    df = decomp_data_frames[0]
    receptor_filter = df['location'].map(lambda x: x.startswith('R'))
    df_receptor = df[receptor_filter]
    print df_receptor.sort('total_mean').iloc[:5]


if __name__ == "__main__":
    main()