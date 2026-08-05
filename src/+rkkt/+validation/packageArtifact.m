function artifact = packageArtifact(packageName,fileName)
%PACKAGEARTIFACT Return a fixed validation artifact path.

arguments
    packageName (1,1) string
    fileName (1,1) string
end

artifact = fullfile(rkkt.validation.outputDirectory(packageName),fileName);
end
