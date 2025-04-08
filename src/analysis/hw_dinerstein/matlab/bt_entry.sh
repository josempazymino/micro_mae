##################################################
#Copy this file to your home directory and run it with qsub
#"qsub matlab.sh" will start the job
#This script is intended to reserve 12 processors for Matlab worker processes
#In your batch script you can run "parpool('local',12)" to start 12 workers on a node
###################################################

#!/bin/bash
#PBS -N matlabpool
#PBS -l nodes=1:ppn=12,mem=2gb
#PBS -V
#PBS -j oe
#PBS -t 1-1000

cd $PBS_O_WORKDIR

#Matlab can clobber it's temporary files if multiple instances are run at once
#Create a job specific temp directory to avoid this
mkdir -p ~/matlabtmp/$PBS_JOBID
export MATLABWORKDIR=~/matlabtmp/$PBS_JOBID


# execute program
# this will start 10 matlab jobs each requesting 12 cores
# loading files matlab_input1.m, matlab_input2.m, matlab_input3.m, ... matlab_input10.m
matlab -nodesktop -nosplash  -r B5_entry>> B5_entry.log

#Delete the temporary directory
#rm -rf $MATLABWORKDIR
