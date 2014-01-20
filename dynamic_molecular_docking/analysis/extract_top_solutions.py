#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Copyright 2012-2014 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

from __future__ import unicode_literals

import os
import sys
import logging
import argparse

import pandas as pd
import numpy as np


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
    parser.add_argument("pdbfiledir")
    parser.add_argument("outputdir",
    OPTIONS = parser.parse_args()

    # Extract top solutions by MMPBSA, hbonds, ... bla bla

    # Create directory 'top_solutions'
    # Create subdirectories by criterion (e.g. "mmpbsa", ...)
    # Fill these directories with PDB files from pdbfiledir


if __name__ == "__main__":
    main()