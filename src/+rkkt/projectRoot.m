function root = projectRoot()
%PROJECTROOT Return the canonical repository root.

packageDirectory = string(fileparts(mfilename("fullpath")));
sourceDirectory = string(fileparts(packageDirectory));
root = string(fileparts(sourceDirectory));
end
