function readPDSCHcsv(file)
  file = strcat(file, '.pdsch.csv');
  fid = fopen(file);
  a = textscan(fid, '%s %d %d %d %d %d %d %d %d %s %d %d %d %s', 'Delimiter', ',');
  fclose(fid);

  timestamp = a{1}(1:end);
  frame = a{2}(1:end);
  subframe = a{3}(1:end);
  nrb = a{4}(1:end);
  nlayers = a{5}(1:end);
  ntbs = a{6}(1:end);
  harq = a{7}(1:end);
  rv = a{8}(1:end);
  ndi = a{9}(1:end);
  rntitype = a{10}(1:end);
  tbind = a{11}(1:end);
  tbsize = a{12}(1:end);
  mcs = a{13}(1:end);
  modulation = a{14}(1:end);

  save(strcat(file,'.mat'), 'timestamp', 'frame', 'subframe','nrb','nlayers','ntbs','harq','rv','ndi','rntitype','tbind','tbsize','mcs','modulation');
end 

