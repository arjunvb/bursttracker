function write_mat_to_csv(filename, mat, header)


 

  fid = fopen(filename, 'w');
  for i=1:length(header)
    if i < length(header)
      fprintf(fid, strcat(header{i}, ','));
    else
      fprintf(fid, header{i});
    end
  end
  fprintf(fid, '\n');
  fclose(fid);

  dlmwrite(filename, mat, '-append', 'delimiter', ',', 'precision', '%.0f');
  
end

