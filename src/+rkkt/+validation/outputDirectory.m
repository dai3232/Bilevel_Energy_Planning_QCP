function directory = outputDirectory(packageName)
%OUTPUTDIRECTORY Return a package's fixed validation directory.

arguments
    packageName (1,1) string
end

directory = fullfile(rkkt.projectRoot(),"src","+rkkt", ...
    "+"+packageName,"+validation");
end
