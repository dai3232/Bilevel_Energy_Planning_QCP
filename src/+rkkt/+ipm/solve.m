function result = solve(data,index,config,runContext,options)
%SOLVE Delegate the formal checkpointed A4 full-IPM entry.

arguments
    data (1,1) struct
    index (1,1) struct
    config (1,1) struct
    runContext (1,1) struct
    options.Resume (1,1) logical = false
end

[productionDirectory,productionFile] = production_location( ...
    "solver","run_stage_a4_full_ipm.m");
originalPath = path;
pathGuard = onCleanup(@() path(originalPath));
addpath(productionDirectory,"-begin");
resolved = string(which("run_stage_a4_full_ipm"));
if ~same_path(resolved,productionFile)
    error("rkkt:ipm:ProductionFunctionShadowed", ...
        ["Expected run_stage_a4_full_ipm at '%s'; " ...
        "MATLAB resolved '%s'."],productionFile,resolved);
end
result = run_stage_a4_full_ipm( ...
    data,index,config,runContext,Resume=options.Resume);
clear pathGuard
end

function [directory,file] = production_location(folder,fileName)
packageDirectory = string(fileparts(mfilename("fullpath")));
sourceDirectory = string(fileparts(fileparts(packageDirectory)));
directory = fullfile(sourceDirectory,string(folder));
file = fullfile(directory,string(fileName));
if ~isfile(file)
    error("rkkt:ipm:ProductionFileMissing", ...
        "Production IPM file is missing: %s",file);
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
