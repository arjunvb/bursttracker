#!/bin/bash

# Script to make qxdm dirs + generate all qxdm_out files

# example:
# ./qxdm_prepAndParse.sh /data2/enbsniffer/qxdm/test

# input to top-level folder containing QXDM .txt logs
ROOT=$1

# make qxdm/raw
mkdir -p ${ROOT}qxdm
mkdir -p ${ROOT}qxdm/raw
for file in ${ROOT}*.txt
do
  f=$(basename $file)
  RUNSTR=$(echo $f | cut -d'_' -f 4)
  mkdir -p ${ROOT}qxdm/raw/${RUNSTR}
  mv $file ${ROOT}/qxdm/raw/${RUNSTR}/. 
done

for file in ${ROOT}*.isf
do
  f=$(basename $file)
  RUNSTR=$(echo $f | cut -d'_' -f 4)
  mkdir -p ${ROOT}qxdm/raw/${RUNSTR}
  mv $file ${ROOT}/qxdm/raw/${RUNSTR}/. 
done

# generate IMEI csv
for folder in ${ROOT}qxdm/raw/*
do
  python parseIMEI.py $folder
done

cmd="generateQXDMAll('${ROOT}qxdm/raw')"
echo $cmd
/usr/local/bin/matlab -nodesktop -nosplash -r "try; $cmd; catch ME, display(getReport(ME)); end; exit;"

