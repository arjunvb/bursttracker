'''
enbsniffer project, parsePDSCHlog.py, (TODO: summary)
Copyright (c) 2016 Stanford University
Released under the Apache License v2.0. See the LICENSE file for details.
Author: Arjun Balasingam
'''

from sys import argv

file = open(argv[1], 'r')
outfile = open(argv[1] + '.pdsch.csv', 'w');

lines = file.readlines()

lines = lines[6:-1]

outfile.write('timestamp,frame,subframe,nrb,nlayers,ntbs,harq,rv,ndi,rntitype,tbind,tbsize,mcs,modulation\n');

ptr = 0
while ptr < len(lines):
  if "LTE PDSCH Stat Indication" not in lines[ptr]:
    ptr += 1
    continue

#  print "**** NEW LOG ****"

  # extract timestamp
  timestamp = lines[ptr][0:25]

  ptr += 10
  while "|" in lines[ptr]:
    p = lines[ptr]

    if " C|" not in p:
      ptr += 1
      continue

    if "   |   |" in p:
      payload = p.split("|")
      tbind = int(payload[13])
      tbsize = int(payload[16])
      mcs = int(payload[17])
      modulation = payload[18].strip(' ')
      
      csvline = timestamp + "," + str(frame) + "," + str(subframe) + "," + str(nrb) + "," + str(nlayers) + "," + str(ntbs) + "," + \
        str(harq) + "," + str(rv) + "," + str(ndi) + "," + rntitype + "," + str(tbind) + "," + str(tbsize) + "," + str(mcs) + "," + modulation + "\n"
      outfile.write(csvline)

      ptr += 1      
      continue
     
    payload = p.split("|")

    subframe = int(payload[2])
    frame = int(payload[3])
    nrb = int(payload[4])
    nlayers = int(payload[5])
    ntbs = int(payload[6])
    harq = int(payload[8])
    rv = int(payload[9])
    ndi = int(payload[10])
    rntitype = payload[12].strip(' ')
    tbind = int(payload[13])
    tbsize = int(payload[16])
    mcs = int(payload[17])
    modulation = payload[18].strip(' ')

#    print timestamp
#    print "frame", frame
#    print "subframe", subframe
#    print "nrb", nrb
#    print "nlayers", nlayers
#    print "ntbs", ntbs
#    print "harq", harq
#    print "rv", rv
#    print "ndi", ndi
#    print "rntitype", rntitype
#    print "tbind", tbind
#    print "tbsize", tbsize
#    print "mcs", mcs
#    print "modulation", modulation

    csvline = timestamp + "," + str(frame) + "," + str(subframe) + "," + str(nrb) + "," + str(nlayers) + "," + str(ntbs) + "," + \
              str(harq) + "," + str(rv) + "," + str(ndi) + "," + rntitype + "," + str(tbind) + "," + str(tbsize) + "," + str(mcs) + "," + modulation + "\n"
    outfile.write(csvline)

    ptr += 1

  ptr += 1

