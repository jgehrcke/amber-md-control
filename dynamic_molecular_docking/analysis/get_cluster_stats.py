#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Copyright 2012-2013 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

import os
import glob
import logging
import pandas as pd
import argparse


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('clusterdirectory', action="store",
        help="Path to directory containing cluster PDB files.")
    parser.add_argument('datafile', action="store",
        help="Path to file containing data per run ID.")
    options = parser.parse_args()

    pdb_paths = glob.glob("%s/*.pdb" % options.clusterdirectory)
    if not pdb_paths:
        sys.exit("No *.pdb files found.")
    
    pdb_filenames = [os.path.basename(p) for p in pdb_paths]
    run_ids = [run_id_from_filename(fn) for fn in pdb_filenames]

    df = pd.read_csv(options.datafile, index_col="run_id")
    subset = df.loc[run_ids]
    print subset.mean()
    print subset.std()




def run_id_from_filename(fn):
    return fn.split("-")[0]


if __name__ == "__main__":
    main()
