% reads parsed PDCCH logs (in .csv format) from QXDM
function readPDCCHcsv(file)
  file = strcat(file, '.pdcch.csv');
  fid = fopen(file);
  a = textscan(fid, '%s %d %d %s %d %s %s %d %d', 'Delimiter', ',', 'HeaderLines', 1);
  fclose(fid);

  timestamp = a{1}(1:end);
  frame = a{2}(1:end);
  subframe = a{3}(1:end);
  payloadstr = a{4}(1:end);
  payloadsize = a{5}(1:end);
  dciformat = a{6}(1:end);
  rntitype = a{7}(1:end);
  agglevel = a{8}(1:end);
  startcce = a{9}(1:end);

  save(strcat(file,'.mat'), 'timestamp', 'frame', 'subframe','payloadstr','payloadsize','dciformat','rntitype','agglevel','startcce'); 
end
