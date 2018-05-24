import os
import json
import sys
from select import select
import time
from datetime import datetime
from StringIO import StringIO
import BaseHTTPServer
from SimpleHTTPServer import SimpleHTTPRequestHandler
import collections

NUM_PRBS_PER_TTI = 50
NUM_PRBS_START = 0.9*NUM_PRBS_PER_TTI
NUM_PRBS_END = 0.4*NUM_PRBS_PER_TTI

class MyHandler(SimpleHTTPRequestHandler):
  def send_head(self):
    if self.translate_path(self.path).endswith('/bw'):
      body = "%0.3f" % bsegg
      self.send_response(200)
      self.send_header("Content-type", "text/html; charset=utf-8")
      self.send_header("Content-Length", str(len(body)))
      self.send_header("Access-Control-Allow-Origin", "*")
      self.end_headers()
      return StringIO(body)
    else:
      return super(MyHandler, self).send_head()

class PDSCHLog():
  def __init__(self, jsonlog=""):
    self.raw = jsonlog
    try:
      parsed = json.loads(self.raw) 
      self.nRBs = sum([int(x) for x in bin(int(parsed["RB Allocation Slot 0[0]"], 0))[2:]])
      self.fsf = int(parsed["System Frame Number"]) * 10 + int(parsed["Subframe Number"])
      self.tbs0 = int(parsed["TBS 0"])
      self.tbs1 = int(parsed["TBS 1"])
      self.vol_dl = (self.tbs0 + self.tbs1) / 8.0 # bytes
      self.time = (datetime.strptime(parsed["timestamp"], "%Y-%m-%d %H:%M:%S.%f") - datetime(1970, 1, 1)).total_seconds()
    except:
      self.nRBs = 2000
      self.fsf = -1
      self.tbs0 = -1
      self.tbs1 = -1
      self.vol_dl = -1
      self.time = -1

  def print_contents(self):
    print "fsf %d, num PRBs = %d, DL vol = %0.2f Bytes\n" % (self.fsf, self.nRBs, self.vol_dl)

class BurstTracker():
  def __init__(self):
    self.in_burst = False
    self.start_fsf = -1
    self.end_fsf = -1
    self.tdelta = -1
    self.burst_volume = []

  def begin_burst(self, start_fsf):
    self.in_burst = True
    self.start_fsf = start_fsf

  def end_burst(self, end_fsf):
    self.in_burst = False
    self.end_fsf = end_fsf

    # compute burst duration, accounting for SFN roll over
    if self.end_fsf < self.start_fsf:
      self.tdelta = 10249 - self.start_fsf + self.end_fsf # discount last TTI
    else:
      self.tdelta = self.end_fsf - self.start_fsf # discount last TTI
    
    if self.tdelta > 0:
      return sum(self.burst_volume[:-1])/(self.tdelta) * 8e3 # bps
    else:
      return 0
    #return sum(self.burst_volume)/(tdelta) * 8e-3 # Mbps

  def add_volume(self, vol):
    self.burst_volume.append(vol)

  def clear_burst(self):
    self.in_burst = False
    self.start_fsf = -1
    self.end_fsf = -1
    self.burst_volume = []

def setup_http_server():
  HandlerClass = MyHandler
  ServerClass  = BaseHTTPServer.HTTPServer
  Protocol     = "HTTP/1.0"

  port = 8000
  server_address = ('127.0.0.1', port)
  
  HandlerClass.protocol_version = Protocol
  httpd = ServerClass(server_address, HandlerClass)

  httpd.timeout = 0.1
  return httpd

def serve_bandwidth(httpd):
  httpd.handle_request()
  
def main():
  global bsegg
  bsegg = 0
  # state variables
  bt = BurstTracker()
  plog_prev = PDSCHLog()
  burst_hist = collections.deque(maxlen=5)
  dur_hist = collections.deque(maxlen=5)

  # create + open log output file
  f = open(os.environ['LTEMEAS_ROOT'] + '/code/videoplayer/bsegg.csv', 'w')
 
  # Setup HTTP server
  httpd = setup_http_server()

  print "Starting BurstTracker..."
  f.write("time, start_fsf, end_fsf, bsegg\n")
 
  while True:
    ready = select([sys.stdin, httpd], [], [], 0.1)[0]

    for file in ready:
      if file == sys.stdin:
        line = sys.stdin.readline()
        if line and "Subframe" in line: 
    
          ### parse current PDSCH log ###
          plog_curr = PDSCHLog(line[45:]) # trim out "[INFO] [MsgLogger]: " suffix
    
          ### account for SFN roll over ###
          if plog_curr.fsf < plog_prev.fsf:
            tdelta = 10249 - plog_prev.fsf + plog_curr.fsf
          else:
            tdelta = plog_curr.fsf - plog_prev.fsf
    
          ### burst IN/OUT logic ###
          if bt.in_burst and plog_prev.nRBs < NUM_PRBS_END and tdelta > 1: 
            # END burst if: (1) prev TTI is half-full, (2) next TTI is empty
            bthp = bt.end_burst(plog_prev.fsf)
            burst_hist.append(bthp)
            dur_hist.append(bt.tdelta)
            bsegg = sum([dur_hist[i] * burst_hist[i] for i in range(len(burst_hist))]) / sum(dur_hist)
            print "%0.3f BURST from (%d, %d) with throughput %0.3f Mbps (avg %0.3f)" % (plog_prev.time, bt.start_fsf, bt.end_fsf, bthp/1e6, bsegg/1e6)
            f.write("%0.3f, %d, %d, %0.3f\n" % (plog_prev.time, bt.start_fsf, bt.end_fsf, bthp))
            #f.flush()
            bt.clear_burst()
          if not bt.in_burst and plog_curr.nRBs > NUM_PRBS_START 
            # BEGIN burst if: full TTI
            bt.begin_burst(plog_curr.fsf)
          if bt.in_burst:
            # account for volume from every TTI during burst
            bt.add_volume(plog_curr.vol_dl)
    
          ### save previous state ###
          plog_prev = plog_curr
        elif not len(line):
          print "detected EOF"
          exit()
      elif file == httpd:
        httpd.handle_request()

if __name__ == "__main__":
  main()

