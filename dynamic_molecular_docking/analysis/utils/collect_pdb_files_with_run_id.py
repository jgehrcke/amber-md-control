#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
#   Copyright 2012-2013 Jan-Philip Gehrcke
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#

import sys
import os
import shutil

"""
Usage:

input | thiscript outputdir finalstate.pdb

Input is collected from stdin. Example:

find . -name "FINAL_SYSTEM_STATE_WITHOUT_WATER.pdb"
./heptetra_rndrot_0001/SMD_PROD_001/FINAL_SYSTEM_STATE_WITHOUT_WATER.pdb
./heptetra_rndrot_0001/SMD_PROD_002/FINAL_SYSTEM_STATE_WITHOUT_WATER.pdb
./heptetra_rndrot_0001/SMD_PROD_003/FINAL_SYSTEM_STATE_WITHOUT_WATER.pdb
./heptetra_rndrot_0001/SMD_PROD_004/FINAL_SYSTEM_STATE_WITHOUT_WATER.pdb

In this example, the following output files are created:

outputdir/0001_001-finalstate.pdb
outputdir/0001_002-finalstate.pdb
outputdir/0001_003-finalstate.pdb
outputdir/0001_004-finalstate.pdb

The run_ids are generated from the path by looking for the two right-most
integer elements that are
    - separated from the rest of the path via underscores.
    - at maximum 5 digits long (excludes date strings)

The output files have the run_id as filename prefix, separated from the
rest of the file name via '-'.
"""

#OUTFILESUFFIX = "finalstate.pdb"

def main():
    usage = """Usage:
Either:  %s output directory outfile_suffix
or    :  %s --print-run-ids
""" % (sys.argv[0], sys.argv[0])
    print_ids_only = False
    if len(sys.argv) == 2:
        if not sys.argv[1] == "--print-run-ids":
            sys.exit(usage)
        print_ids_only = True
    elif len(sys.argv) < 3:
        sys.exit(usage)

    if not print_ids_only:
        outdir = sys.argv[1]
        outfilesuffix = sys.argv[2]
        if not os.path.isdir(outdir):
            sys.exit("Not a directory: '%s'" % outdir)

    for filepath in sys.stdin:
        filepath = filepath.strip()
        if not os.path.isfile(filepath):
            errlog("Not a file: %s:" % filepath)
            continue

        run_id = run_id_from_path(filepath)
        if run_id is None:
            errlog("No integer token in %s" % path)
            continue
        if print_ids_only:
            print run_id
            continue

        outfileprefix = run_id
        outfilename = "%s-%s" % (outfileprefix, outfilesuffix)
        outfilepath = os.path.join(outdir, outfilename)
        shutil.copy(filepath, outfilepath)
        print "created %s" % outfilepath


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
    if not integertokens:
        errlog("No integer token in %s" % p)
        return None
    # Return run_id, e.g. '00001_05'
    return "_".join(integertokens[-2:])


def errlog(s):
    sys.stderr.write("%s\n" % s)
    sys.stderr.flush()


if __name__ == "__main__":
    main()

