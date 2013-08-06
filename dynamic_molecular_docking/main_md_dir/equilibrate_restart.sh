#!/bin/bash
# Previous run:
#Running equilibration...
#Running command:
#time pmemd.cuda -O -i equilibrate_NPT.in -o equilibrate_NPT.out -p top.prmtop      -c heatup_NVT.rst -r equilibrate_NPT.rst -x equilibrate_NPT.mdcrd
#Nonbond cells need to be recalculated, restart simulation from previous checkpoint
#with a higher value for skinnb.
#
#real    2m12.016s
#user    1m41.240s
#sys     0m29.540s
#Error during equilibration. Exit.



#Restart of equilibration, because box size decreased to fast (density of
#initial system was too low).
#
#http://archive.ambermd.org/201205/0406.html
#
#As Jason said, to output NetCDF restart files specify 'ntxo = 2' in
#the cntrl namelist.
#
#For reading, NetCDF restart files are detected automatically, and only
#respond to 'ntx = 1' (read coordinates only) or 'ntx = 5' (read
#coordinates and velocities). 

# ntx = 5 is already set in original equilibrate_NPT.in

# We don't need to correct nstlim, the restarted equilibrations now just run a
# little longer (overall time: aborted simulation + restarted simulation) than
# the equilibrations that worked right away.


# Run from within ligand/equi directory.


source ../env_setup.sh

mv equilibrate_NPT.rst equilibrate_NPT.rst.1
mv equilibrate_NPT.mdcrd equilibrate_NPT.mdcrd.1
mv equilibrate_NPT.out equilibrate_NPT.out.1

time pmemd.cuda -O -i equilibrate_NPT.in -o equilibrate_NPT.out \
    -p top.prmtop -c equilibrate_NPT.rst.1 \
    -r equilibrate_NPT.rst -x equilibrate_NPT.mdcrd

