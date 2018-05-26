function generateQXDMAll(rootDir)

exps = dir(strcat(rootDir,'/*'));

parfor i=3:length(exps)
  generateQXDMOut(strcat(rootDir,'/',exps(i).name), true)
end

end

