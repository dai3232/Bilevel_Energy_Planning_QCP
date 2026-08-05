function [outputFile,tableFiles,figureFiles,index] = outputPaths( ...
        outputDirectory,matName,tableNames,figureName,writeArtifacts)
%OUTPUTPATHS Build fixed validation artifact paths.

if writeArtifacts
    outputFile = fullfile(outputDirectory,string(matName));
    tableFiles = fullfile(outputDirectory,reshape(string(tableNames),[],1));
    index = struct( ...
        "figPath",fullfile(outputDirectory,string(figureName)+".fig"), ...
        "pngPath",fullfile(outputDirectory,string(figureName)+".png"));
    figureFiles = [string(index.figPath);string(index.pngPath)];
else
    outputFile = "";
    tableFiles = strings(0,1);
    figureFiles = strings(0,1);
    index = struct("figPath","","pngPath","");
end
outputFile = string(outputFile);
tableFiles = reshape(string(tableFiles),[],1);
figureFiles = reshape(string(figureFiles),[],1);
end
