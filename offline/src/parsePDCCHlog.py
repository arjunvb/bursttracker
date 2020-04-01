'''
enbsniffer project, parsePDCCHlog.py, (TODO: summary)
Copyright (c) 2016 Stanford University
Released under the Apache License v2.0. See the LICENSE file for details.
Author: Arjun Balasingam
'''

from sys import argv

file = open(argv[1], 'r')
outfile = open(argv[1] + '.pdcch.csv', 'w');

lines = file.readlines()

lines = lines[6:-1]
# lines = lines[6:55] # for testing

outfile.write('timestamp,frame,subframe,payload str,payload size,dci format,rnti type, agg level, start cce\n');

ptr = 0
while ptr < len(lines):
  if "LTE LL1 PDCCH Decoding Result" not in lines[ptr]:
    ptr += 1
    continue

#  print "**** NEW SF ****"

  # extract timestamp
  timestamp = lines[ptr][0:25]

  # extract frame + subframe
  subframe = int(lines[ptr+2].rsplit('=',1)[1])
  frame = int(lines[ptr+3].rsplit('=',1)[1])

  # extract payload
  ptr += 13
  while "|" in lines[ptr]:
    if "DCI0" in lines[ptr] or "SUCCESS" not in lines[ptr]: 
    #if "SUCCESS" not in lines[ptr]: 
      ptr += 1
      continue
    
    payloadstr = lines[ptr][8:26]
    payloadsize = int(lines[ptr][89:91]) 
    dciformat = lines[ptr][60:62]
    
    # extract RNTI type
    rntipos = lines[ptr].find("RNTI");
    ind = lines[ptr].rfind(" ", 0, rntipos+1);  
    rntitype = lines[ptr][ind+1:rntipos+4]

    # get aggregation level
    aggpos = lines[ptr].find("Agg")
    agg = int(lines[ptr][aggpos+3:aggpos+4])

    # get start CCE
    startcce = int(lines[ptr][78:83])
#    print timestamp
#    print "frame", frame
#    print "subframe", subframe
#    print "payload str", payloadstr
#    print "payload size", payloadsize
#    print "dci format", dciformat
#    print "rnti type", rntitype
  
    outline = timestamp + "," + str(frame) + "," + str(subframe) + "," + payloadstr + "," + str(payloadsize) + "," + dciformat + "," + rntitype + "," + str(agg) + "," + str(startcce) + "\n"
    outfile.write(outline)

    ptr += 1

  ptr += 1

