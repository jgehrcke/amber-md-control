#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Copyright 2012-2013 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

import glob
import logging
import pandas as pd

logging.basicConfig(
    format='%(asctime)s:%(msecs)05.1f  %(levelname)s: %(message)s',
    datefmt='%H:%M:%S')
log = logging.getLogger()
log.setLevel(logging.INFO)


def main():
    datafile_paths = glob.glob("per_run_data/*.dat")
    for datafile_path in datafile_paths:
        log.info("Found file '%s'." % datafile_path)
    dataframes = [pd.read_csv(p, index_col="run_id") for p in datafile_paths]
    merged_dataframe = pd.concat(dataframes, axis=1)

    # Alternative method, for reference: Use DataFrame's join multiple times:
    # merged_dataframe = merged_dataframe.join(
    #        pd.read_csv(datafile_path, index_col="run_id"))

    outfile_path = "per_run_data_merged.dat"
    log.info("Writing output file '%s'." % outfile_path)
    merged_dataframe.to_csv(outfile_path, index_label='run_id')


if __name__ == "__main__":
    main()
