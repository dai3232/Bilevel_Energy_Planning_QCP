function requireOutputDirectory(directory,writeArtifacts)
%REQUIREOUTPUTDIRECTORY Require the selected artifact directory to exist.

arguments
    directory (1,1) string
    writeArtifacts (1,1) logical
end

if writeArtifacts
    assert(isfolder(directory),"rkkt:validation:OutputDirectoryMissing", ...
        "OutputDirectory does not exist: %s",directory);
end
end
