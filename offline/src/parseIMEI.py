import sys, os

# input qxdm folder
expFolder = sys.argv[1]

# output file imei.csv
# UEID (from file name), IMEI (from qxdm log)
out = open(expFolder + '/imei.csv', 'w')
out.write('UEID, IMEI\n');

# extract COM, IMEI from single qxdm log
def parse_imei(qxdmtxt, out):
  qxdmlog = open(qxdmtxt, 'r')
  
  ueIdx = int([s for s in qxdmtxt.split('_') if 'COM' in s][0][3:])
  for line in qxdmlog:
    if "IMEI:" not in line:
      continue
    imei = str(int(line.split(':')[1]))
    out.write('%d, %s\n' % (ueIdx, imei))
    break

# dump COM, IMEI for all qxdm logs in experiment folder
for file in os.listdir(expFolder):
  if "qxdm_test" in file and file.endswith('.txt'):
    parse_imei(expFolder + '/' + file, out)

