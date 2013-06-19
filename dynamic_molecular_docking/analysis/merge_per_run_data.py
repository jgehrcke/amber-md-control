#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Copyright 2012-2013 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

import os
import sys
import logging
import glob

import pandas as pd
import numpy as np

PER_RUN_DATA_DIR = "per_run_data"

logging.basicConfig(
    format='%(asctime)s:%(msecs)05.1f  %(levelname)s: %(message)s',
    datefmt='%H:%M:%S')
log = logging.getLogger()
log.setLevel(logging.INFO)

def main():
    datafile_paths = glob.glob("%s/*.dat" % PER_RUN_DATA_DIR)
    for i, datafile_path in enumerate(datafile_paths):
        log.info("Processeing files '%s'." % datafile_path)
        if not i:
            merged_dataframe = pd.read_csv(datafile_path, index_col="run_id")
            continue
        merged_dataframe = merged_dataframe.join(
            pd.read_csv(datafile_path, index_col="run_id"))

    outfile_path = "per_run_data_merged.dat"
    if os.path.exists(outfile_path):
        log.info("Output file '%s' will be overwritten." % outfile_path)

    merged_dataframe.to_csv(outfile_path)


if __name__ == "__main__":
    main()