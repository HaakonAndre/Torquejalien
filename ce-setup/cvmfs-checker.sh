#!/bin/bash
yum install -y environment-modules tcl
if [[ -d /cvmfs/alice.cern.ch/bin ]] 
then {
    bash /start.sh
    exit
}
else {
    #add appropriate symlinks to allow functioning of agent startup script

    #start htcondor
    bash /start.sh
}
fi
