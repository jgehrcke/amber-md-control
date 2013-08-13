#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Copyright 2012-2013 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

import os
import sys
import logging
import pandas as pd
import StringIO


logging.basicConfig(
    format='%(asctime)s:%(msecs)05.1f  %(levelname)s: %(message)s',
    datefmt='%H:%M:%S')
log = logging.getLogger()
log.setLevel(logging.INFO)


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

    single_dataframes = []
    for idx, fp in enumerate(filepaths):
        if not os.path.isfile(fp):
            log.error("No such file: '%s'" % fp)
        else:
            log.info("Processing '%s'" % fp)
            single_dataframes.append(single_dihedral_datafile_to_dataframe(fp))

    log.info("Processed %s data sets (files)." % len(single_dataframes))
    log.info("Merging data...")
    merged_df = pd.concat(single_dataframes)
    output_csv_filepath = os.path.join(output_dir, 'dihedral_data_merged.dat')
    log.info("Writing merged data to '%s" % output_csv_filepath)
    merged_df.to_csv(output_csv_filepath, index=False)



def cpptraj_diheddata_to_csv_130812(cpptraj_dihedraldata_filepath):
    """
    Create file-like object from cpptraj dihedral data file containing CSV
    data according to CSV 'standard', i.e. first line containing headings,
    all other lines containing data.

    This code works for cpptraj output as of 2013-08-12.
    """
    with open(cpptraj_dihedraldata_filepath) as f:
        lines = f.readlines()
    # Remove leading '#' in first line, strip leading and trailing white spaces
    # and replace whitespace delimiters with commas.
    firstline = ','.join(lines[0].strip().strip('#').split())
    otherlines_gen = (','.join(l.strip().split()) for l in lines[1:])
    csv_buffer = StringIO.StringIO()
    csv_buffer.write("%s\n" % firstline)
    csv_buffer.write("\n".join(otherlines_gen))
    csv_buffer.seek(0)
    return csv_buffer


def single_dihedral_datafile_to_dataframe(cpptraj_dihedraldata_filepath):
    # Read in panda DataFrame:
    csv_buffer = cpptraj_diheddata_to_csv_130812(cpptraj_dihedraldata_filepath)
    df = pd.read_csv(csv_buffer)
    #log.debug("Columns read:\n%s", "\n".join(c for c in df.columns))
    #log.debug("Dataframe head:\n%s", df.head())
    log.info("Built pandas DataFrame with %s columns and %s rows.",
        len(df.columns), len(df))
    for c in df.columns:
        #log.info("Column '%s' data type: %s", c, df[c].dtype)
        # Str comp. rather than numpy namespace lookup.
        if str(df[c].dtype) != "float64":
            log.warning("Error: all columns must be of dtype float.")
    return df


if __name__ == "__main__":
    main()
