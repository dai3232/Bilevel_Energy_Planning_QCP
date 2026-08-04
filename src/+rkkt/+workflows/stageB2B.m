function result = stageB2B(options)
%STAGEB2B Delegate the formal Stage B-2B workflow to its production entry.

arguments
    options.ProjectRoot (1,1) string = ""
    options.RunId (1,1) string = ""
end

[projectRoot,productionFile] = production_location( ...
    options.ProjectRoot,"main_stage_B_2B.m");
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(projectRoot,"-begin");
resolved = string(which("main_stage_B_2B"));
if ~same_path(resolved,productionFile)
    error("rkkt:workflows:ProductionFunctionShadowed", ...
        "Expected main_stage_B_2B at '%s'; MATLAB resolved '%s'.", ...
        productionFile,resolved);
end

result = main_stage_B_2B( ...
    ProjectRoot=options.ProjectRoot,RunId=options.RunId);
clear pathGuard
end

function [projectRoot,file] = production_location(requestedRoot,fileName)
if strlength(strip(requestedRoot)) == 0
    packageDirectory = string(fileparts(mfilename("fullpath")));
    sourceDirectory = string(fileparts(fileparts(packageDirectory)));
    projectRoot = string(fileparts(sourceDirectory));
else
    projectRoot = string(java.io.File(char(requestedRoot)).getCanonicalPath());
end
file = fullfile(projectRoot,fileName);
if ~isfile(file)
    error("rkkt:workflows:ProductionFileMissing", ...
        "Production workflow file is missing: %s",file);
end
end

function value = same_path(left,right)
left = replace(string(left),"/","\");
right = replace(string(right),"/","\");
if ispc
    value = strcmpi(left,right);
else
    value = strcmp(left,right);
end
end
